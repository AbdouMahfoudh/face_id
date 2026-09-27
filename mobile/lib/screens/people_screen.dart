import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/person.dart';
import '../theme.dart';
import '../widgets/person_widgets.dart';
import 'person_detail_screen.dart';
import 'person_form_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  String _query = '';
  String? _type;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final q = _query.trim().toLowerCase();
    final people = state.people
        .where((p) => _type == null || p.type == _type)
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.matricule.toLowerCase().contains(q) ||
              p.subtitle.toLowerCase().contains(q),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('people'))),
      floatingActionButton: state.canEdit
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PersonFormScreen()),
              ),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(context.tr('add')),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              hintText: context.tr('search_hint'),
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final t in [null, ...personTypes])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(context.tr(t == null ? 'all' : 'type_$t')),
                      selected: _type == t,
                      onSelected: (_) => setState(() => _type = t),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: people.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        q.isEmpty && _type == null
                            ? context.tr('nobody_yet')
                            : context.tr('no_results'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: people.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
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
    final sub = [
      context.tr('type_${person.type}'),
      if (person.subtitle.isNotEmpty) person.subtitle,
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Hero(
          tag: 'avatar-${person.id}',
          child: PersonAvatar(person: person),
        ),
        title: Text(
          person.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(sub),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (person.status != 'actif')
              Pill(
                context.tr('status_${person.status}'),
                color: statusColor(person.status),
              ),
            if (!person.synced)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 18,
                  color: AppColors.warning,
                ),
              ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PersonDetailScreen(personId: person.id),
          ),
        ),
      ),
    );
  }
}
