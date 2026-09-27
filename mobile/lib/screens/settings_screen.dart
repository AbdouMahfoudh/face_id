import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/remote_api.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppState _state = AppScope.read(context);
  late final _url = TextEditingController(text: _state.serverUrl);
  late final _key = TextEditingController(text: _state.apiKey);
  bool _hideKey = true;
  bool _testing = false;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _saveAndTest() async {
    FocusScope.of(context).unfocus();
    await _state.saveServerSettings(_url.text, _key.text);
    if (!_state.serverConfigured) {
      _message('Réglages enregistrés : mode hors ligne uniquement.');
      return;
    }
    setState(() => _testing = true);
    try {
      final count = await _state.testServer();
      _message('Connexion réussie : $count personne(s) dans la base en ligne.');
      await _state.sync();
    } on RemoteException catch (e) {
      _message('Échec : ${e.message}');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final (
      IconData icon,
      Color color,
      String label,
    ) = switch (state.serverStatus) {
      ServerStatus.notConfigured => (
        Icons.cloud_off_outlined,
        Colors.grey,
        'Serveur non configuré',
      ),
      ServerStatus.unknown => (
        Icons.cloud_queue,
        Colors.grey,
        'Connexion non vérifiée',
      ),
      ServerStatus.online => (Icons.cloud_done, Colors.green, 'Connecté'),
      ServerStatus.offline => (Icons.cloud_off, Colors.orange, 'Hors ligne'),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Serveur en ligne', style: text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Sans serveur, l’application fonctionne uniquement avec les '
            'personnes enregistrées sur ce téléphone.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Adresse du serveur',
              hintText: 'http://102.214.210.18/faceid_api',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _key,
            obscureText: _hideKey,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Code d’accès (API_KEY)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_hideKey ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _hideKey = !_hideKey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _testing ? null : _saveAndTest,
            icon: _testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Enregistrer et tester'),
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 8),
                      Text(label, style: text.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.pendingCount == 0
                        ? 'Toutes les fiches sont envoyées au serveur.'
                        : '${state.pendingCount} modification(s) en attente d’envoi.',
                  ),
                  if (state.lastSyncError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      state.lastSyncError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: !state.serverConfigured || state.syncing
                        ? null
                        : state.sync,
                    icon: state.syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: const Text('Synchroniser maintenant'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Identifiant de cet appareil : ${state.deviceId}',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
