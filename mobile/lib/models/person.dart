import 'dart:typed_data';

const personTypes = [
  'eleve',
  'enseignant',
  'personnel',
  'surveillant',
  'autre',
];
const personStatuses = ['actif', 'parti', 'suspendu'];

class Person {
  final String id;
  final int schoolId;
  final String type;
  final String matricule;
  final String firstName;
  final String lastName;

  /// 'M', 'F' or ''.
  final String sex;

  /// Dates as 'YYYY-MM-DD', or '' when unknown.
  final String birthDate;
  final String status;
  final String classLevel;
  final String schoolYear;
  final String enrollmentDate;
  final String jobTitle;
  final String parentName;
  final String parentPhone;
  final String address;
  final String medical;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<FaceSample> samples;

  /// True once this version of the person has been uploaded to the server.
  final bool synced;

  const Person({
    required this.id,
    required this.schoolId,
    this.type = 'eleve',
    this.matricule = '',
    this.firstName = '',
    this.lastName = '',
    this.sex = '',
    this.birthDate = '',
    this.status = 'actif',
    this.classLevel = '',
    this.schoolYear = '',
    this.enrollmentDate = '',
    this.jobTitle = '',
    this.parentName = '',
    this.parentPhone = '',
    this.address = '',
    this.medical = '',
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.samples = const [],
    this.synced = false,
  });

  String get name => '$firstName $lastName'.trim();
  bool get isStudent => type == 'eleve';
  String? get coverPhoto => samples.isEmpty ? null : samples.first.photoPath;

  /// Class for students, job title for staff.
  String get subtitle => isStudent ? classLevel : jobTitle;

  /// Editable fields, as exchanged with the server.
  Map<String, String> fields() => {
    'type': type,
    'matricule': matricule,
    'first_name': firstName,
    'last_name': lastName,
    'sex': sex,
    'birth_date': birthDate,
    'status': status,
    'class_level': classLevel,
    'school_year': schoolYear,
    'enrollment_date': enrollmentDate,
    'job_title': jobTitle,
    'parent_name': parentName,
    'parent_phone': parentPhone,
    'address': address,
    'medical': medical,
    'notes': notes,
  };

  Map<String, Object?> toRow() => {
    'id': id,
    'school_id': schoolId,
    ...fields(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'synced': synced ? 1 : 0,
  };

  factory Person.fromMap(
    Map<String, Object?> m, {
    required int schoolId,
    List<FaceSample> samples = const [],
    bool synced = false,
  }) {
    String s(String k) => (m[k] as String?) ?? '';
    DateTime d(String k) =>
        DateTime.tryParse(s(k).replaceFirst(' ', 'T')) ?? DateTime.now();
    return Person(
      id: m['id'] as String,
      schoolId: schoolId,
      type: personTypes.contains(s('type')) ? s('type') : 'autre',
      matricule: s('matricule'),
      firstName: s('first_name'),
      lastName: s('last_name'),
      sex: s('sex'),
      birthDate: s('birth_date'),
      status: s('status').isEmpty ? 'actif' : s('status'),
      classLevel: s('class_level'),
      schoolYear: s('school_year'),
      enrollmentDate: s('enrollment_date'),
      jobTitle: s('job_title'),
      parentName: s('parent_name'),
      parentPhone: s('parent_phone'),
      address: s('address'),
      medical: s('medical'),
      notes: s('notes'),
      createdAt: d('created_at'),
      updatedAt: d('updated_at'),
      samples: samples,
      synced: synced,
    );
  }

  factory Person.fromRow(Map<String, Object?> row, List<FaceSample> samples) =>
      Person.fromMap(
        row,
        schoolId: row['school_id'] as int,
        samples: samples,
        synced: (row['synced'] as int? ?? 0) == 1,
      );
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
