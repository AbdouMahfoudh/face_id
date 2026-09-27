import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/remote_api.dart';
import '../theme.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppState _state = AppScope.read(context);
  late final _url = TextEditingController(text: _state.serverUrl);
  bool _testing = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _saveServer() async {
    FocusScope.of(context).unfocus();
    await _state.setServerUrl(_url.text);
    setState(() => _testing = true);
    try {
      await _state.testServer();
      if (mounted) _message(context.tr('connection_ok'));
      await _state.checkAccount();
      await _state.sync();
    } on RemoteException catch (e) {
      if (mounted) _message(e.message);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _logout() async {
    final state = _state;
    final pending = state.pendingCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('logout')),
        content: Text(
          pending > 0
              ? c.tr('logout_pending_warning', {'n': pending})
              : c.tr('logout_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(c.tr('logout')),
          ),
        ],
      ),
    );
    if (ok == true) await state.logout();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.session;
    final text = Theme.of(context).textTheme;
    if (s == null) return const Scaffold();

    Widget perm(bool on, String key) => ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        on ? Icons.check_circle : Icons.cancel_outlined,
        color: on ? AppColors.success : Colors.grey,
      ),
      title: Text(context.tr(key)),
    );

    final (
      IconData icon,
      Color color,
      String label,
    ) = switch (state.serverStatus) {
      ServerStatus.unknown => (
        Icons.cloud_queue,
        Colors.grey,
        context.tr('connecting'),
      ),
      ServerStatus.online => (
        Icons.cloud_done,
        AppColors.success,
        context.tr('online'),
      ),
      ServerStatus.offline => (
        Icons.cloud_off,
        AppColors.warning,
        context.tr('offline'),
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.teal.withValues(alpha: 0.15),
                        child: Text(
                          s.fullName.isEmpty
                              ? '?'
                              : s.fullName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.fullName, style: text.titleMedium),
                            Text(
                              '@${s.username} · ${s.schoolName}',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Pill(
                        context.tr(s.isAdmin ? 'role_admin' : 'role_agent'),
                        color: AppColors.night,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(context.tr('my_permissions'), style: text.labelLarge),
                  perm(s.canScan, 'perm_scan'),
                  perm(s.canEdit, 'perm_edit'),
                  perm(s.canDelete, 'perm_delete'),
                  perm(s.canSeeSensitive, 'perm_sensitive'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('language'), style: text.titleSmall),
                  const SizedBox(height: 10),
                  const LanguageSwitch(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
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
                  const SizedBox(height: 6),
                  Text(
                    state.pendingCount == 0
                        ? context.tr('all_synced')
                        : context.tr('pending_changes', {
                            'n': state.pendingCount,
                          }),
                  ),
                  if (state.lastSyncError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      state.lastSyncError!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: state.syncing ? null : state.sync,
                    icon: state.syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(context.tr('sync_now')),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: context.tr('server_address'),
                      hintText: defaultServerUrl,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _testing ? null : _saveServer,
                    icon: _testing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(context.tr('save_and_test')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: Text(context.tr('logout')),
          ),
          const SizedBox(height: 16),
          Text(
            '${context.tr('device_id')} : ${state.deviceId}',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
