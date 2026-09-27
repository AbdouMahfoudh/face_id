import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../services/remote_api.dart';
import '../theme.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final state = AppScope.read(context);
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = context.tr('login_missing'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.login(_username.text, _password.text);
    } on RemoteException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editServer() async {
    final state = AppScope.read(context);
    final ctrl = TextEditingController(text: state.serverUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.tr('server_address')),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(hintText: defaultServerUrl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(c.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: Text(c.tr('save')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (url != null) await state.setServerUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final ended = state.sessionEndedMessage;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: LanguageSwitch(light: true),
                    ),
                    const SizedBox(height: 12),
                    const AppLogo(size: 88),
                    const SizedBox(height: 16),
                    Text(
                      'FaceID École',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('tagline'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.tr('login_title'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 18),
                            if (ended != null && _error == null)
                              _Banner(ended, color: AppColors.warning),
                            if (_error != null)
                              _Banner(_error!, color: AppColors.danger),
                            TextField(
                              controller: _username,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: context.tr('username'),
                                prefixIcon: const Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _password,
                              obscureText: _hide,
                              onSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                labelText: context.tr('password'),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _hide
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () =>
                                      setState(() => _hide = !_hide),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _busy ? null : _login,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(context.tr('login')),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    ),
                              child: Text(context.tr('create_account')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      onPressed: _editServer,
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: Text(context.tr('server_settings')),
                    ),
                    const SizedBox(height: 8),
                    const DeveloperCredit(light: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// FR | عربي toggle.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key, this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return SegmentedButton<AppLang>(
      showSelectedIcon: false,
      style: light
          ? SegmentedButton.styleFrom(
              foregroundColor: Colors.white,
              selectedForegroundColor: AppColors.night,
              selectedBackgroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
            )
          : null,
      segments: const [
        ButtonSegment(value: AppLang.fr, label: Text('FR')),
        ButtonSegment(value: AppLang.ar, label: Text('عربي')),
      ],
      selected: {state.lang},
      onSelectionChanged: (s) => state.setLanguage(s.first),
    );
  }
}
