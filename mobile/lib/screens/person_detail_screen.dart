import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/person_widgets.dart';
import 'person_form_screen.dart';

class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final person = state.people.where((p) => p.id == personId).firstOrNull;
    if (person == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.tr('person_deleted'))),
      );
    }

    Future<void> confirmDelete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(c.tr('delete_person_title', {'name': person.name})),
          content: Text(c.tr('delete_person_info')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(c.tr('cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(c, true),
              child: Text(c.tr('delete')),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      await state.deletePerson(person);
      if (context.mounted) Navigator.pop(context);
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    const BackButton(color: Colors.white),
                    const Spacer(),
                    if (state.canEdit)
                      IconButton(
                        tooltip: context.tr('edit'),
                        color: Colors.white,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PersonFormScreen(existing: person),
                          ),
                        ),
                      ),
                    if (state.canDelete)
                      IconButton(
                        tooltip: context.tr('delete'),
                        color: Colors.white,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: confirmDelete,
                      ),
                  ],
                ),
                Hero(
                  tag: 'avatar-${person.id}',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: PersonAvatar(person: person, radius: 56),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  person.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    Pill(
                      context.tr('type_${person.type}'),
                      color: Colors.white,
                    ),
                    if (person.subtitle.isNotEmpty)
                      Pill(person.subtitle, color: Colors.white),
                    Pill(
                      context.tr('status_${person.status}'),
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (person.samples.length > 1) ...[
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: person.samples.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          File(person.samples[i].photoPath),
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                PersonInfoSections(
                  person: person,
                  showSensitive: state.canSeeSensitive,
                ),
                Row(
                  children: [
                    Icon(
                      person.synced
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_upload_outlined,
                      size: 16,
                      color: person.synced
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${context.tr(person.synced ? 'synced' : 'not_synced')} · '
                        '${context.tr('updated_on')} ${formatDate(person.updatedAt.toIso8601String().substring(0, 10))}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
