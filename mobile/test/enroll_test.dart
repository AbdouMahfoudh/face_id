import 'package:face_id_ecole/screens/enroll_screen.dart';
import 'package:face_id_ecole/services/matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('head rotation maps to enrollment poses', () {
    expect(Pose.of(0, 0), Pose.front);
    expect(Pose.of(5, -8), Pose.front);
    expect(Pose.of(30, 0), Pose.left);
    expect(Pose.of(-30, 5), Pose.right);
    expect(Pose.of(0, 20), Pose.up);
    expect(Pose.of(3, -15), Pose.down);
    // In between poses: nothing is captured.
    expect(Pose.of(15, 0), isNull);
    expect(Pose.of(30, 30), isNull);
  });

  test('score thresholds', () {
    expect(FaceMatcher.statusFor(0.9), MatchStatus.recognized);
    expect(FaceMatcher.statusFor(0.5), MatchStatus.uncertain);
    expect(FaceMatcher.statusFor(0.2), MatchStatus.unknown);
  });
}
