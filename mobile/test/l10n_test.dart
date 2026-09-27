import 'dart:io';

import 'package:face_id_ecole/l10n.dart';
import 'package:face_id_ecole/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every translation key used in the code exists', () {
    final keys = <String>{
      for (final t in personTypes) 'type_$t',
      for (final s in personStatuses) 'status_$s',
    };
    // tr('key') calls, plus keys stored in variables before being translated.
    final patterns = [
      RegExp(r"tr\(\s*'([a-z_0-9]+)'"),
      RegExp(r"'((?:section|pose|hint|camera|perm)_[a-z_]+)'"),
      RegExp(r"note = '([a-z_]+)'"),
    ];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final re in patterns) {
        keys.addAll(re.allMatches(src).map((m) => m.group(1)!));
      }
    }
    // Labels passed through helpers (field(), info rows).
    keys.addAll(['matricule', 'sex', 'job_title', 'notes', 'done']);
    expect(keys.where((k) => !L10n.strings.containsKey(k)).toList(), isEmpty);
  });

  test('both languages are filled and placeholders match', () {
    final placeholder = RegExp(r'\{[a-z]+\}');
    L10n.strings.forEach((key, v) {
      expect(v.$1.trim(), isNotEmpty, reason: key);
      expect(v.$2.trim(), isNotEmpty, reason: key);
      expect(
        placeholder.allMatches(v.$2).map((m) => m[0]).toSet(),
        placeholder.allMatches(v.$1).map((m) => m[0]).toSet(),
        reason: key,
      );
    });
  });

  test('arguments are substituted', () {
    expect(
      const L10n(AppLang.fr).t('max_photos', {'n': 10}),
      'Maximum 10 photos.',
    );
    expect(
      const L10n(AppLang.ar).t('max_photos', {'n': 10}),
      'الحد الأقصى 10 صور.',
    );
    expect(const L10n(AppLang.fr).t('no_such_key'), 'no_such_key');
  });
}
