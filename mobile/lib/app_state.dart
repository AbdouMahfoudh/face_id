import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'models/person.dart';
import 'services/database.dart';
import 'services/face_service.dart';
import 'services/matcher.dart';
import 'services/remote_api.dart';

class EnrolledFace {
  final Float32List embedding;
  final Uint8List thumbnailJpg;

  const EnrolledFace(this.embedding, this.thumbnailJpg);
}

enum ServerStatus { notConfigured, unknown, online, offline }

class AppState extends ChangeNotifier {
  AppState(this.db, this.faces, this.deviceId);

  final AppDatabase db;
  final FaceService faces;
  final String deviceId;
  static const _uuid = Uuid();

  List<Person> _people = [];
  List<Person> get people => _people;

  String _serverUrl = '';
  String _apiKey = '';
  String get serverUrl => _serverUrl;
  String get apiKey => _apiKey;
  bool get serverConfigured => _serverUrl.isNotEmpty && _apiKey.isNotEmpty;

  ServerStatus _status = ServerStatus.notConfigured;
  ServerStatus get serverStatus => _status;
  String? _lastError;
  String? get lastSyncError => _lastError;
  bool _syncing = false;
  bool _syncAgain = false;
  bool get syncing => _syncing;
  int _pendingDeletes = 0;
  int get pendingCount =>
      _people.where((p) => !p.synced).length + _pendingDeletes;

  Timer? _retry;

  static Future<AppState> load() async {
    final db = await AppDatabase.open();
    var deviceId = await db.getSetting('device_id');
    if (deviceId == null) {
      deviceId = _uuid.v4();
      await db.setSetting('device_id', deviceId);
    }
    final state = AppState(db, await FaceService.create(), deviceId);
    state._serverUrl = await db.getSetting('server_url') ?? '';
    state._apiKey = await db.getSetting('api_key') ?? '';
    state._status = state.serverConfigured
        ? ServerStatus.unknown
        : ServerStatus.notConfigured;
    await state.refresh();
    unawaited(state.sync());
    // Retry pending uploads regularly while the app is open.
    state._retry = Timer.periodic(const Duration(minutes: 1), (_) {
      if (state.pendingCount > 0) state.sync();
    });
    return state;
  }

  RemoteApi? get _api => serverConfigured
      ? RemoteApi(baseUrl: _serverUrl, apiKey: _apiKey, deviceId: deviceId)
      : null;

  Future<void> refresh() async {
    _people = await db.loadPeople();
    _pendingDeletes = (await db.pendingDeletes()).length;
    notifyListeners();
  }

  Future<void> saveServerSettings(String url, String key) async {
    _serverUrl = url.trim();
    _apiKey = key.trim();
    await db.setSetting('server_url', _serverUrl);
    await db.setSetting('api_key', _apiKey);
    _status = serverConfigured
        ? ServerStatus.unknown
        : ServerStatus.notConfigured;
    _lastError = null;
    notifyListeners();
  }

  /// Checks the connection; returns the number of persons stored online.
  Future<int> testServer() async {
    final api = _api;
    if (api == null) {
      throw const RemoteException('Adresse ou code d’accès manquant.');
    }
    try {
      final count = await api.ping();
      _setStatus(ServerStatus.online, null);
      return count;
    } on RemoteException catch (e) {
      _setStatus(ServerStatus.offline, e.message);
      rethrow;
    }
  }

  void _setStatus(ServerStatus status, String? error) {
    _status = status;
    _lastError = error;
    notifyListeners();
  }

  /// Uploads local changes (new/edited persons, deletions) to the server.
  Future<void> sync() async {
    final api = _api;
    if (api == null) return;
    if (_syncing) {
      _syncAgain = true;
      return;
    }
    _syncing = true;
    _syncAgain = false;
    notifyListeners();
    try {
      final deletes = await db.pendingDeletes();
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
      _status = ServerStatus.offline;
      _lastError = e.message;
    } finally {
      _syncing = false;
      await refresh();
    }
    if (_syncAgain && _status == ServerStatus.online) await sync();
  }

  MatchResult identify(Float32List embedding, {String? excludePersonId}) =>
      FaceMatcher.match(
        embedding,
        _people,
        excludePersonId: excludePersonId,
        model: FaceService.modelName,
      );

  /// Compares with the whole online database. Returns null when no server is
  /// configured; throws [RemoteException] when it cannot be reached.
  Future<MatchResult?> identifyOnline(Float32List embedding) async {
    final api = _api;
    if (api == null) return null;
    try {
      final m = await api.identify(embedding, FaceService.modelName);
      if (_status != ServerStatus.online) _setStatus(ServerStatus.online, null);
      if (m == null) return const MatchResult(MatchStatus.unknown, null, 0);
      final status = FaceMatcher.statusFor(m.score);
      return MatchResult(
        status,
        status == MatchStatus.unknown ? null : m.person,
        m.score,
        remote: true,
        remotePhoto: m.photo,
      );
    } on RemoteException catch (e) {
      _setStatus(ServerStatus.offline, e.message);
      rethrow;
    }
  }

  Future<void> savePerson({
    Person? existing,
    required String name,
    required String role,
    required String description,
    required List<FaceSample> keep,
    required List<EnrolledFace> added,
  }) async {
    final now = DateTime.now();
    final id = existing?.id ?? _uuid.v4();
    final person = Person(
      id: id,
      name: name,
      role: role,
      description: description,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
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
    _retry?.cancel();
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
