import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'l10n.dart';
import 'models/person.dart';
import 'models/session.dart';
import 'services/database.dart';
import 'services/face_service.dart';
import 'services/matcher.dart';
import 'services/remote_api.dart';

class EnrolledFace {
  final Float32List embedding;
  final Uint8List thumbnailJpg;

  const EnrolledFace(this.embedding, this.thumbnailJpg);
}

enum ServerStatus { unknown, online, offline }

const defaultServerUrl = 'http://102.214.210.18:81/dolibarr/faceid_api';

class AppState extends ChangeNotifier {
  AppState(this.db, this.faces, this.deviceId);

  final AppDatabase db;
  final FaceService faces;
  final String deviceId;
  static const _uuid = Uuid();

  AppLang _lang = AppLang.fr;
  AppLang get lang => _lang;
  L10n get l10n => L10n(_lang);

  String _serverUrl = defaultServerUrl;
  String get serverUrl => _serverUrl;

  UserSession? _session;
  UserSession? get session => _session;

  /// Why the user was logged out automatically (blocked, expired…).
  String? sessionEndedMessage;

  List<Person> _people = [];
  List<Person> get people => _people;

  ServerStatus _status = ServerStatus.unknown;
  ServerStatus get serverStatus => _status;
  String? _lastError;
  String? get lastSyncError => _lastError;
  bool _syncing = false;
  bool _syncAgain = false;
  bool get syncing => _syncing;
  int _pendingDeletes = 0;
  int get pendingCount =>
      _people.where((p) => !p.synced).length + _pendingDeletes;

  bool get canScan => _session?.canScan ?? false;
  bool get canEdit => _session?.canEdit ?? false;
  bool get canDelete => _session?.canDelete ?? false;
  bool get canSeeSensitive => _session?.canSeeSensitive ?? false;

  Timer? _timer;

  static Future<AppState> load() async {
    final db = await AppDatabase.open();
    var deviceId = await db.getSetting('device_id');
    if (deviceId == null) {
      deviceId = _uuid.v4();
      await db.setSetting('device_id', deviceId);
    }
    final state = AppState(db, await FaceService.create(), deviceId);
    state._lang = (await db.getSetting('lang')) == 'ar'
        ? AppLang.ar
        : AppLang.fr;
    state._serverUrl = await db.getSetting('server_url') ?? defaultServerUrl;
    final saved = await db.getSetting('session');
    if (saved != null) {
      try {
        state._session = UserSession.fromJson(
          jsonDecode(saved) as Map<String, dynamic>,
        );
      } catch (_) {
        await db.setSetting('session', null);
      }
    }
    await state.refresh();
    if (state._session != null) unawaited(state.checkAccount());
    state._timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (state._session == null) return;
      if (state.pendingCount > 0) {
        state.sync();
      } else {
        state.checkAccount();
      }
    });
    return state;
  }

  RemoteApi get _api => RemoteApi(
    baseUrl: _serverUrl,
    deviceId: deviceId,
    token: _session?.token,
  );

  Future<void> refresh() async {
    final s = _session;
    if (s == null) {
      _people = [];
      _pendingDeletes = 0;
    } else {
      _people = await db.loadPeople(s.schoolId);
      _pendingDeletes = (await db.pendingDeletes(s.schoolId)).length;
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLang lang) async {
    _lang = lang;
    await db.setSetting('lang', lang.name);
    notifyListeners();
  }

  Future<void> setServerUrl(String url) async {
    _serverUrl = url.trim().isEmpty ? defaultServerUrl : url.trim();
    await db.setSetting('server_url', _serverUrl);
    _status = ServerStatus.unknown;
    notifyListeners();
  }

  Future<void> testServer() async {
    try {
      await _api.ping();
      _setStatus(ServerStatus.online, null);
    } on RemoteException catch (e) {
      _setStatus(ServerStatus.offline, e.message);
      rethrow;
    }
  }

  Future<List<School>> schools() => _api.schools();

  Future<void> register({
    required int schoolId,
    required String fullName,
    required String phone,
    required String username,
    required String password,
  }) => _api.register(
    schoolId: schoolId,
    fullName: fullName,
    phone: phone,
    username: username,
    password: password,
  );

  Future<void> login(String username, String password) async {
    final session = await _api.login(username.trim(), password);
    await _setSession(session);
    _status = ServerStatus.online;
    sessionEndedMessage = null;
    await refresh();
    unawaited(sync());
  }

  Future<void> logout() async {
    final api = _api;
    await _setSession(null);
    await refresh();
    try {
      await api.logout();
    } on RemoteException {
      // Offline: the token simply stays unused on the server.
    }
  }

  Future<void> _setSession(UserSession? s) async {
    _session = s;
    await db.setSetting('session', s == null ? null : jsonEncode(s.toJson()));
  }

  /// Refreshes the account's rights; logs out if it was blocked or removed.
  Future<void> checkAccount() async {
    if (_session == null) return;
    try {
      final fresh = await _api.me();
      await _setSession(fresh);
      _setStatus(ServerStatus.online, null);
      await refresh();
    } on RemoteException catch (e) {
      await _handle(e);
    }
  }

  Future<void> _handle(RemoteException e) async {
    if (e.endsSession) {
      sessionEndedMessage = e.message;
      await _setSession(null);
      await refresh();
    } else if (e.reason == 'permission') {
      _setStatus(ServerStatus.online, e.message);
    } else {
      _setStatus(ServerStatus.offline, e.message);
    }
  }

  void _setStatus(ServerStatus status, String? error) {
    _status = status;
    _lastError = error;
    notifyListeners();
  }

  /// Uploads local changes (new/edited persons, deletions) to the server.
  Future<void> sync() async {
    final s = _session;
    if (s == null) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    _syncAgain = false;
    notifyListeners();
    final api = _api;
    try {
      final deletes = await db.pendingDeletes(s.schoolId);
      if (deletes.isNotEmpty) {
        await api.deletePersons(deletes);
        await db.clearPendingDeletes(deletes);
      }
      for (final person in _people.where((p) => !p.synced).toList()) {
        final cover = person.coverPhoto;
        Uint8List? photo;
        if (cover != null && await File(cover).exists()) {
          photo = await File(cover).readAsBytes();
        }
        await api.upsertPerson(person, photo);
        await db.markSynced(person);
      }
      _status = ServerStatus.online;
      _lastError = null;
    } on RemoteException catch (e) {
      await _handle(e);
    } finally {
      _syncing = false;
      await refresh();
    }
    if (_syncAgain && _status == ServerStatus.online) await sync();
  }

  bool get managementEnabled => _session?.managementEnabled ?? false;

  /// Looks a matricule up in the school's management system.
  Future<StudentLookup> lookupStudent(String matricule) async {
    try {
      return await _api.lookupStudent(matricule.trim());
    } on RemoteException catch (e) {
      if (e.endsSession) await _handle(e);
      rethrow;
    }
  }

  /// Link to [person]'s record in the school's management system, if any.
  Uri? recordUrl(Person person) {
    final tpl = _session?.recordUrlTemplate ?? '';
    if (tpl.isEmpty || person.matricule.isEmpty) return null;
    final uri = Uri.tryParse(
      tpl.replaceAll('{matricule}', Uri.encodeComponent(person.matricule)),
    );
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https')
        ? uri
        : null;
  }

  MatchResult identify(Float32List embedding, {String? excludePersonId}) =>
      FaceMatcher.match(
        embedding,
        _people,
        excludePersonId: excludePersonId,
        model: FaceService.modelName,
      );

  /// Compares with the school's online database. Throws [RemoteException]
  /// when the server cannot be reached.
  Future<MatchResult> identifyOnline(Float32List embedding) async {
    final s = _session!;
    try {
      final m = await _api.identify(
        embedding,
        FaceService.modelName,
        s.schoolId,
      );
      if (_status != ServerStatus.online) _setStatus(ServerStatus.online, null);
      final status = m.person == null
          ? MatchStatus.unknown
          : FaceMatcher.statusFor(m.score);
      return MatchResult(
        status,
        status == MatchStatus.unknown ? null : m.person,
        m.score,
        remote: true,
        remotePhoto: m.photo,
      );
    } on RemoteException catch (e) {
      await _handle(e);
      rethrow;
    }
  }

  /// Saves [draft] (fields only) with its face samples.
  Future<void> savePerson({
    required Person draft,
    required List<FaceSample> keep,
    required List<EnrolledFace> added,
  }) async {
    final now = DateTime.now();
    final existing = _people.where((p) => p.id == draft.id).firstOrNull;
    final id = draft.id.isEmpty ? _uuid.v4() : draft.id;
    final newSamples = <FaceSample>[];
    for (final face in added) {
      final sampleId = _uuid.v4();
      final path = p.join(db.photosDir.path, '$sampleId.jpg');
      await File(path).writeAsBytes(face.thumbnailJpg);
      newSamples.add(
        FaceSample(
          id: sampleId,
          personId: id,
          embedding: face.embedding,
          photoPath: path,
          model: FaceService.modelName,
        ),
      );
    }
    final person = Person.fromMap({
      ...draft.fields(),
      'id': id,
      'created_at': (existing?.createdAt ?? now).toIso8601String(),
      'updated_at': now.toIso8601String(),
    }, schoolId: _session!.schoolId);
    await db.savePerson(person, keep: keep, added: newSamples);
    await refresh();
    unawaited(sync());
  }

  Future<void> deletePerson(Person person) async {
    await db.deletePerson(person);
    await refresh();
    unawaited(sync());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension L10nContext on BuildContext {
  /// Translated text for [key] in the app language.
  String tr(String key, [Map<String, Object> args = const {}]) =>
      AppScope.of(this).l10n.t(key, args);
}
