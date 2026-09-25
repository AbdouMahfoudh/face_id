import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/person.dart';

class AppDatabase {
  AppDatabase._(this._db, this.photosDir);

  final Database _db;
  final Directory photosDir;

  static Future<AppDatabase> open() async {
    final dbPath = p.join(await getDatabasesPath(), 'face_id.db');
    final db = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE persons (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT '',
            description TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE face_samples (
            id TEXT PRIMARY KEY,
            person_id TEXT NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
            embedding BLOB NOT NULL,
            photo_path TEXT NOT NULL,
            model TEXT NOT NULL
          )''');
        await db.execute(
            'CREATE INDEX idx_samples_person ON face_samples(person_id)');
      },
    );
    final docs = await getApplicationDocumentsDirectory();
    final photos = Directory(p.join(docs.path, 'photos'));
    await photos.create(recursive: true);
    return AppDatabase._(db, photos);
  }

  Future<List<Person>> loadPeople() async {
    final sampleRows = await _db.query('face_samples');
    final byPerson = <String, List<FaceSample>>{};
    for (final row in sampleRows) {
      final s = FaceSample.fromRow(row);
      byPerson.putIfAbsent(s.personId, () => []).add(s);
    }
    final rows = await _db.query('persons', orderBy: 'name COLLATE NOCASE');
    return [for (final r in rows) Person.fromRow(r, byPerson[r['id']] ?? [])];
  }

  Future<void> savePerson(Person person,
      {required List<FaceSample> keep, required List<FaceSample> added}) async {
    final keepIds = keep.map((s) => s.id).toSet();
    final existing = await _db.query('face_samples',
        where: 'person_id = ?', whereArgs: [person.id]);
    final removed = existing
        .map(FaceSample.fromRow)
        .where((s) => !keepIds.contains(s.id))
        .toList();

    await _db.transaction((txn) async {
      // No REPLACE: it would delete the row and cascade to its samples.
      final updated = await txn.update('persons', person.toRow(),
          where: 'id = ?', whereArgs: [person.id]);
      if (updated == 0) await txn.insert('persons', person.toRow());
      for (final s in removed) {
        await txn.delete('face_samples', where: 'id = ?', whereArgs: [s.id]);
      }
      for (final s in added) {
        await txn.insert('face_samples', s.toRow());
      }
    });
    for (final s in removed) {
      await _deleteFile(s.photoPath);
    }
  }

  Future<void> deletePerson(Person person) async {
    await _db.delete('persons', where: 'id = ?', whereArgs: [person.id]);
    for (final s in person.samples) {
      await _deleteFile(s.photoPath);
    }
  }

  Future<void> _deleteFile(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
