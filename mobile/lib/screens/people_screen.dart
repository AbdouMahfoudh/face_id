import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/person.dart';
import 'person_detail_screen.dart';
import 'person_form_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final people = AppScope.of(context)
        .people
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.role.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Personnes enregistrées')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PersonFormScreen())),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Rechercher par nom ou fonction',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: people.isEmpty
                ? Center(
                    child: Text(q.isEmpty
                        ? 'Aucune personne enregistrée.'
                        : 'Aucun résultat pour « $_query ».'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: people.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _PersonTile(person: people[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 26,
        backgroundImage: person.coverPhoto == null
            ? null
            : FileImage(File(person.coverPhoto!)),
        child: person.coverPhoto == null ? const Icon(Icons.person) : null,
      ),
      title: Text(person.name),
      subtitle: person.role.isEmpty ? null : Text(person.role),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PersonDetailScreen(personId: person.id)),
      ),
    );
  }
}
