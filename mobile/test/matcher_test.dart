import 'dart:typed_data';

import 'package:face_id_ecole/models/person.dart';
import 'package:face_id_ecole/services/matcher.dart';
import 'package:flutter_test/flutter_test.dart';

Float32List vec(List<double> v) => Float32List.fromList(v);

Person person(String id, List<Float32List> embeddings, {String model = 'm'}) {
  final now = DateTime(2026);
  return Person(
    id: id,
    name: id,
    role: '',
    description: '',
    createdAt: now,
    updatedAt: now,
    samples: [
      for (var i = 0; i < embeddings.length; i++)
        FaceSample(
            id: '$id$i',
            personId: id,
            embedding: embeddings[i],
            photoPath: '',
            model: model),
    ],
  );
}

void main() {
  test('cosine similarity', () {
    expect(FaceMatcher.cosine(vec([1, 0]), vec([1, 0])), closeTo(1, 1e-6));
    expect(FaceMatcher.cosine(vec([1, 0]), vec([0, 1])), closeTo(0, 1e-6));
    expect(FaceMatcher.cosine(vec([0, 0]), vec([0, 1])), 0);
  });

  test('recognizes the closest person above threshold', () {
    final people = [
      person('alice', [vec([1, 0, 0]), vec([0.9, 0.1, 0])]),
      person('bob', [vec([0, 1, 0])]),
    ];
    final r = FaceMatcher.match(vec([0.95, 0.05, 0]), people, model: 'm');
    expect(r.status, MatchStatus.recognized);
    expect(r.person!.id, 'alice');
  });

  test('uncertain between thresholds, unknown below', () {
    final people = [person('alice', [vec([1, 0])])];
    // cos = 0.55
    final mid = vec([0.55, 0.8352245]);
    expect(FaceMatcher.match(mid, people, model: 'm').status,
        MatchStatus.uncertain);
    final far = vec([0.1, 0.99]);
    final r = FaceMatcher.match(far, people, model: 'm');
    expect(r.status, MatchStatus.unknown);
    expect(r.person, isNull);
  });

  test('empty base, excluded person and other models give unknown', () {
    expect(FaceMatcher.match(vec([1, 0]), [], model: 'm').status,
        MatchStatus.unknown);
    final people = [person('alice', [vec([1, 0])])];
    expect(
        FaceMatcher.match(vec([1, 0]), people,
                excludePersonId: 'alice', model: 'm')
            .status,
        MatchStatus.unknown);
    expect(FaceMatcher.match(vec([1, 0]), people, model: 'other').status,
        MatchStatus.unknown);
  });

  test('embedding bytes round-trip', () {
    final v = vec([0.25, -1.5, 3]);
    expect(embeddingFromBytes(embeddingToBytes(v)), v);
  });
}
