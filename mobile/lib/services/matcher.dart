import 'dart:math';
import 'dart:typed_data';

import '../models/person.dart';

enum MatchStatus { recognized, uncertain, unknown }

class MatchResult {
  final MatchStatus status;
  final Person? person;
  final double score;

  /// Set when the match comes from the online database (read-only).
  final bool remote;
  final Uint8List? remotePhoto;

  const MatchResult(
    this.status,
    this.person,
    this.score, {
    this.remote = false,
    this.remotePhoto,
  });
}

class FaceMatcher {
  // Calibrated on MobileFaceNet: same person scored >= 0.78, different people <= 0.19.
  static const double recognizedThreshold = 0.60;
  static const double uncertainThreshold = 0.48;

  static double cosine(Float32List a, Float32List b) {
    double dot = 0, na = 0, nb = 0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na == 0 || nb == 0) return 0;
    return dot / (sqrt(na) * sqrt(nb));
  }

  static MatchResult match(
    Float32List probe,
    Iterable<Person> people, {
    String? excludePersonId,
    String? model,
  }) {
    Person? best;
    double bestScore = -1;
    for (final person in people) {
      if (person.id == excludePersonId) continue;
      for (final sample in person.samples) {
        if (model != null && sample.model != model) continue;
        final s = cosine(probe, sample.embedding);
        if (s > bestScore) {
          bestScore = s;
          best = person;
        }
      }
    }
    if (best == null) return const MatchResult(MatchStatus.unknown, null, 0);
    final status = statusFor(bestScore);
    return MatchResult(
      status,
      status == MatchStatus.unknown ? null : best,
      bestScore,
    );
  }

  static MatchStatus statusFor(double score) {
    if (score >= recognizedThreshold) return MatchStatus.recognized;
    if (score >= uncertainThreshold) return MatchStatus.uncertain;
    return MatchStatus.unknown;
  }
}
