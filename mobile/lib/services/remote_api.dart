import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/person.dart';

class RemoteException implements Exception {
  final String message;
  const RemoteException(this.message);
  @override
  String toString() => message;
}

/// Best match found in the online database.
class RemoteMatch {
  final Person person;
  final Uint8List? photo;
  final double score;

  const RemoteMatch(this.person, this.photo, this.score);
}

/// Client for server/faceid_api/api.php.
class RemoteApi {
  RemoteApi({
    required String baseUrl,
    required this.apiKey,
    required this.deviceId,
  }) : endpoint = _endpoint(baseUrl);

  final Uri endpoint;
  final String apiKey;
  final String deviceId;

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

  /// Returns the number of persons stored online.
  Future<int> ping() async {
    final r = await _post({'action': 'ping'});
    return (r['persons'] as num?)?.toInt() ?? 0;
  }

  Future<void> upsertPerson(Person person, Uint8List? photo) async {
    await _post({
      'action': 'upsert_person',
      'person': {
        'id': person.id,
        'name': person.name,
        'role': person.role,
        'description': person.description,
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

  Future<RemoteMatch?> identify(Float32List embedding, String model) async {
    final r = await _post({
      'action': 'identify',
      'model': model,
      'embedding': base64Encode(embeddingToBytes(embedding)),
    }, timeout: const Duration(seconds: 8));
    final m = r['match'];
    if (m is! Map<String, dynamic>) return null;
    DateTime date(Object? v) =>
        DateTime.tryParse('${v ?? ''}'.replaceFirst(' ', 'T')) ??
        DateTime.now();
    final person = Person(
      id: m['id'] as String,
      name: m['name'] as String,
      role: (m['role'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      createdAt: date(m['created_at']),
      updatedAt: date(m['updated_at']),
      synced: true,
    );
    final photo = m['photo'];
    return RemoteMatch(
      person,
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
      req.add(
        utf8.encode(
          jsonEncode({...body, 'api_key': apiKey, 'device_id': deviceId}),
        ),
      );
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
          'Réponse invalide du serveur (HTTP ${res.statusCode}). Vérifiez l’adresse.',
        );
      }
      if (decoded['ok'] != true) {
        throw RemoteException(
          (decoded['error'] as String?) ??
              'Erreur serveur (HTTP ${res.statusCode}).',
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
}
