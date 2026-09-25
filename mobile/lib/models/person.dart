import 'dart:typed_data';

class Person {
  final String id;
  final String name;
  final String role;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<FaceSample> samples;

  const Person({
    required this.id,
    required this.name,
    required this.role,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.samples = const [],
  });

  String? get coverPhoto => samples.isEmpty ? null : samples.first.photoPath;

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'role': role,
        'description': description,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Person.fromRow(Map<String, Object?> row, List<FaceSample> samples) {
    return Person(
      id: row['id'] as String,
      name: row['name'] as String,
      role: (row['role'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      samples: samples,
    );
  }
}

class FaceSample {
  final String id;
  final String personId;
  final Float32List embedding;
  final String photoPath;
  final String model;

  const FaceSample({
    required this.id,
    required this.personId,
    required this.embedding,
    required this.photoPath,
    required this.model,
  });

  Map<String, Object?> toRow() => {
        'id': id,
        'person_id': personId,
        'embedding': embeddingToBytes(embedding),
        'photo_path': photoPath,
        'model': model,
      };

  factory FaceSample.fromRow(Map<String, Object?> row) {
    return FaceSample(
      id: row['id'] as String,
      personId: row['person_id'] as String,
      embedding: embeddingFromBytes(row['embedding'] as Uint8List),
      photoPath: row['photo_path'] as String,
      model: row['model'] as String,
    );
  }
}

Uint8List embeddingToBytes(Float32List v) =>
    Uint8List.fromList(v.buffer.asUint8List(v.offsetInBytes, v.lengthInBytes));

Float32List embeddingFromBytes(Uint8List bytes) =>
    Float32List.view(Uint8List.fromList(bytes).buffer);
