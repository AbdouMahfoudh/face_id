import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/person.dart';
import '../theme.dart';

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, this.person, this.photo, this.radius = 26});

  final Person? person;

  /// Remote photo; otherwise the person's local cover photo is used.
  final Uint8List? photo;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cover = person?.coverPhoto;
    final ImageProvider? image = photo != null
        ? MemoryImage(photo!)
        : cover != null
        ? FileImage(File(cover))
        : null;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.teal.withValues(alpha: 0.15),
      backgroundImage: image,
      child: image == null
          ? Icon(Icons.person, size: radius, color: AppColors.teal)
          : null,
    );
  }
}

Color statusColor(String status) => switch (status) {
  'parti' => Colors.grey,
  'suspendu' => AppColors.warning,
  _ => AppColors.success,
};

/// "12/03/2012" from "2012-03-12".
String formatDate(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

/// Detail sections of a person; sensitive ones only with the permission.
class PersonInfoSections extends StatelessWidget {
  const PersonInfoSections({
    super.key,
    required this.person,
    required this.showSensitive,
  });

  final Person person;
  final bool showSensitive;

  @override
  Widget build(BuildContext context) {
    final p = person;
    String sex(String s) => s == 'M'
        ? context.tr('sex_m')
        : s == 'F'
        ? context.tr('sex_f')
        : '';
    final sections = <(IconData, String, List<(String, String)>)>[
      (
        Icons.badge_outlined,
        'section_identity',
        [
          ('matricule', p.matricule),
          ('sex', sex(p.sex)),
          if (showSensitive) ('birth_date', formatDate(p.birthDate)),
          ('status', context.tr('status_${p.status}')),
        ],
      ),
      if (p.isStudent)
        (
          Icons.school_outlined,
          'section_school',
          [
            ('class_level', p.classLevel),
            ('school_year', p.schoolYear),
            ('enrollment_date', formatDate(p.enrollmentDate)),
          ],
        )
      else
        (Icons.work_outline, 'section_job', [('job_title', p.jobTitle)]),
      if (showSensitive)
        (
          Icons.family_restroom,
          p.isStudent ? 'section_parents' : 'section_contact',
          [
            if (p.isStudent) ('parent_name', p.parentName),
            if (p.isStudent) ('parent_phone', p.parentPhone),
            ('address', p.address),
          ],
        ),
      if (showSensitive)
        (
          Icons.medical_information_outlined,
          'section_health',
          [('medical', p.medical)],
        ),
      (Icons.notes, 'notes', [('notes', p.notes)]),
    ];

    final children = <Widget>[];
    for (final (icon, title, rows) in sections) {
      final filled = rows.where((r) => r.$2.trim().isNotEmpty).toList();
      if (filled.isEmpty) continue;
      children.add(
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.teal, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.tr(title),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final (label, value) in filled)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                            context.tr(label),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Expanded(child: SelectableText(value)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (!showSensitive) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr('sensitive_hidden'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
