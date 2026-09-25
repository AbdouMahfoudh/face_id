import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import 'person_form_screen.dart';

class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final matches = state.people.where((p) => p.id == personId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Cette personne a été supprimée.')),
      );
    }
    final person = matches.first;
    final text = Theme.of(context).textTheme;

    Future<void> confirmDelete() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Supprimer ${person.name} ?'),
          content: const Text(
              'Sa fiche et ses photos seront effacées définitivement.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Supprimer')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      await state.deletePerson(person);
      if (context.mounted) Navigator.pop(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PersonFormScreen(existing: person)),
            ),
          ),
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline),
            onPressed: confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: person.samples.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(File(person.samples[i].photoPath),
                    width: 140, height: 140, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(person.name, style: text.headlineSmall),
          if (person.role.isNotEmpty)
            Text(person.role, style: text.titleMedium),
          const SizedBox(height: 16),
          if (person.description.isNotEmpty) ...[
            Text('Description', style: text.labelLarge),
            const SizedBox(height: 4),
            Text(person.description),
            const SizedBox(height: 16),
          ],
          Text(
            'Ajouté le ${_date(person.createdAt)} · modifié le ${_date(person.updatedAt)}',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
