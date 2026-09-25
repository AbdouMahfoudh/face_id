import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'models/person.dart';
import 'services/database.dart';
import 'services/face_service.dart';
import 'services/matcher.dart';

class EnrolledFace {
  final Float32List embedding;
  final Uint8List thumbnailJpg;

  const EnrolledFace(this.embedding, this.thumbnailJpg);
}

class AppState extends ChangeNotifier {
  AppState(this.db, this.faces);

  final AppDatabase db;
  final FaceService faces;
  static const _uuid = Uuid();

  List<Person> _people = [];
  List<Person> get people => _people;

  static Future<AppState> load() async {
    final state = AppState(await AppDatabase.open(), await FaceService.create());
    await state.refresh();
    return state;
  }

  Future<void> refresh() async {
    _people = await db.loadPeople();
    notifyListeners();
  }

  MatchResult identify(Float32List embedding, {String? excludePersonId}) =>
      FaceMatcher.match(embedding, _people,
          excludePersonId: excludePersonId, model: FaceService.modelName);

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
      newSamples.add(FaceSample(
        id: sampleId,
        personId: id,
        embedding: face.embedding,
        photoPath: path,
        model: FaceService.modelName,
      ));
    }
    await db.savePerson(person, keep: keep, added: newSamples);
    await refresh();
  }

  Future<void> deletePerson(Person person) async {
    await db.deletePerson(person);
    await refresh();
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
