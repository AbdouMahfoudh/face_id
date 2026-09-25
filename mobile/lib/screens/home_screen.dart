import 'package:flutter/material.dart';

import '../app_state.dart';
import 'people_screen.dart';
import 'person_form_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final count = AppScope.of(context).people.length;
    final scheme = Theme.of(context).colorScheme;

    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.face, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FaceID École',
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text('$count personne${count > 1 ? 's' : ''} enregistrée${count > 1 ? 's' : ''}',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            _BigAction(
              color: scheme.primary,
              onColor: scheme.onPrimary,
              icon: Icons.center_focus_strong,
              title: 'Scanner un visage',
              subtitle: 'Identifier une personne en un instant',
              onTap: () => open(const ScanScreen()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SmallAction(
                    icon: Icons.people_alt_outlined,
                    title: 'Personnes',
                    onTap: () => open(const PeopleScreen()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SmallAction(
                    icon: Icons.person_add_alt_1_outlined,
                    title: 'Ajouter',
                    onTap: () => open(const PersonFormScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Toutes les données restent sur ce téléphone. '
                  'Pour de meilleurs résultats, enregistrez 3 photos de face, bien éclairées.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.color,
    required this.onColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color color, onColor;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, size: 56, color: onColor),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: onColor, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: onColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction(
      {required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Icon(icon, size: 36, color: scheme.onSecondaryContainer),
              const SizedBox(height: 8),
              Text(title,
                  style: TextStyle(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
