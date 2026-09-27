import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/person.dart';
import '../models/session.dart';

class RemoteException implements Exception {
  final String message;

  /// Server hint: 'session', 'pending', 'blocked', 'permission' or ''.
  final String reason;

  const RemoteException(this.message, [this.reason = '']);

  /// The account can no longer be used: the user must log in again.
  bool get endsSession =>
      reason == 'session' || reason == 'blocked' || reason == 'pending';

  @override
  String toString() => message;
}

class School {
  final int id;
  final String name;
  final String city;

  const School(this.id, this.name, this.city);
}

/// Result of a matricule lookup in the school's management system.
class StudentLookup {
  final bool found;

  /// Person fields (same keys as [Person.fields]) the system knows.
  final Map<String, String> fields;
  final String recordUrl;

  const StudentLookup(this.found, this.fields, this.recordUrl);
}

/// Best match found in the online database.
class RemoteMatch {
  final Person? person;
  final Uint8List? photo;
  final double score;

  const RemoteMatch(this.person, this.photo, this.score);
}

/// Client for server/faceid_api/api.php.
class RemoteApi {
  RemoteApi({required String baseUrl, required this.deviceId, this.token})
    : endpoint = _endpoint(baseUrl);

  final Uri endpoint;
  final String deviceId;
  final String? token;

  static Uri _endpoint(String baseUrl) {
    var url = baseUrl.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (!url.endsWith('.php')) {
      url = url.endsWith('/') ? '${url}api.php' : '$url/api.php';
    }
    return Uri.parse(url);
  }

  Future<void> ping() => _post({'action': 'ping'});

  Future<List<School>> schools() async {
    final r = await _post({'action': 'schools'});
    return [
      for (final s in (r['schools'] as List).cast<Map<String, dynamic>>())
        School(
          (s['id'] as num).toInt(),
          s['name'] as String,
          (s['city'] as String?) ?? '',
        ),
    ];
  }

  Future<void> register({
    required int schoolId,
    required String fullName,
    required String phone,
    required String username,
    required String password,
  }) => _post({
    'action': 'register',
    'school_id': schoolId,
    'full_name': fullName,
    'phone': phone,
    'username': username,
    'password': password,
  });

  Future<UserSession> login(String username, String password) async {
    final r = await _post({
      'action': 'login',
      'username': username,
      'password': password,
      'device_id': deviceId,
    });
    return UserSession.fromUser(
      r['token'] as String,
      r['user'] as Map<String, dynamic>,
    );
  }

  Future<void> logout() => _post({'action': 'logout'});

  /// Current rights of the logged-in account.
  Future<UserSession> me() async {
    final r = await _post({'action': 'me'});
    return UserSession.fromUser(token!, r['user'] as Map<String, dynamic>);
  }

  Future<void> upsertPerson(Person person, Uint8List? photo) async {
    await _post({
      'action': 'upsert_person',
      'person': {
        'id': person.id,
        ...person.fields(),
        'created_at': person.createdAt.toIso8601String(),
        'updated_at': person.updatedAt.toIso8601String(),
        'photo': photo == null ? null : base64Encode(photo),
      },
      'samples': [
        for (final s in person.samples)
          {
            'id': s.id,
            'model': s.model,
            'embedding': base64Encode(embeddingToBytes(s.embedding)),
          },
      ],
    }, timeout: const Duration(seconds: 30));
  }

  Future<void> deletePersons(List<String> ids) =>
      _post({'action': 'delete_persons', 'ids': ids});

  Future<StudentLookup> lookupStudent(String matricule) async {
    final r = await _post({
      'action': 'lookup_student',
      'matricule': matricule,
    }, timeout: const Duration(seconds: 15));
    final raw = r['fields'];
    return StudentLookup(r['found'] == true, {
      if (raw is Map)
        for (final e in raw.entries)
          if (e.value is String) '${e.key}': e.value as String,
    }, (r['record_url'] as String?) ?? '');
  }

  Future<RemoteMatch> identify(
    Float32List embedding,
    String model,
    int schoolId,
  ) async {
    final r = await _post({
      'action': 'identify',
      'model': model,
      'embedding': base64Encode(embeddingToBytes(embedding)),
    }, timeout: const Duration(seconds: 8));
    final m = r['match'];
    if (m is! Map<String, dynamic>) {
      return RemoteMatch(null, null, (r['score'] as num?)?.toDouble() ?? 0);
    }
    final photo = m['photo'];
    return RemoteMatch(
      Person.fromMap(m, schoolId: schoolId, synced: true),
      photo is String ? base64Decode(photo) : null,
      (m['score'] as num).toDouble(),
    );
  }

  Future<Map<String, dynamic>> _post(
    Map<String, Object?> body, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.postUrl(endpoint);
      req.headers.contentType = ContentType.json;
      // Some web firewalls reject requests that do not look like a browser.
      req.headers.set(HttpHeaders.acceptHeader, 'application/json, */*');
      req.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Linux; Android) FaceIDEcole/2.0',
      );
      req.add(utf8.encode(jsonEncode({...body, 'token': ?token})));
      final res = await req.close().timeout(timeout);
      final text = await res.transform(utf8.decoder).join().timeout(timeout);
      Object? decoded;
      try {
        decoded = jsonDecode(text);
      } on FormatException {
        decoded = null;
      }
      if (decoded is! Map<String, dynamic>) {
        throw RemoteException(
          'Réponse invalide du serveur (HTTP ${res.statusCode}). '
          'Vérifiez l’adresse.${_snippet(text)}',
        );
      }
      if (decoded['ok'] != true) {
        throw RemoteException(
          (decoded['error'] as String?) ??
              'Erreur serveur (HTTP ${res.statusCode}).',
          (decoded['reason'] as String?) ?? '',
        );
      }
      return decoded;
    } on SocketException {
      throw const RemoteException('Serveur injoignable (pas d’Internet ?).');
    } on HttpException {
      throw const RemoteException('Connexion au serveur interrompue.');
    } on TimeoutException {
      throw const RemoteException('Le serveur ne répond pas.');
    } on HandshakeException {
      throw const RemoteException('Erreur de connexion sécurisée (HTTPS).');
    } finally {
      client.close(force: true);
    }
  }

  /// First words of a non-JSON (usually HTML) server reply, for diagnosis.
  static String _snippet(String body) {
    final plain = body
        .replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plain.isEmpty) return '';
    return '\nServeur : « ${plain.length > 160 ? '${plain.substring(0, 160)}…' : plain} »';
  }
}
