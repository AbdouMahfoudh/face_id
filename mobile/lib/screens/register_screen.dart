import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/remote_api.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late Future<List<School>> _schools = AppScope.read(context).schools();
  School? _school;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_fullName, _phone, _username, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    String? err;
    if (_school == null) {
      err = context.tr('choose_school');
    } else if (_fullName.text.trim().isEmpty) {
      err = context.tr('full_name_required');
    } else if (!RegExp(r'^[A-Za-z0-9._-]{3,64}$')
        .hasMatch(_username.text.trim())) {
      err = context.tr('username_rule');
    } else if (_password.text.length < 6) {
      err = context.tr('password_rule');
    } else if (_password.text != _confirm.text) {
      err = context.tr('password_mismatch');
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).register(
        schoolId: _school!.id,
        fullName: _fullName.text.trim(),
        phone: _phone.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.hourglass_top, size: 40),
          title: Text(c.tr('account_created')),
          content: Text(c.tr('account_pending_info')),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: Text(c.tr('ok')),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on RemoteException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('create_account'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.tr('register_intro'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<School>>(
            future: _schools,
            builder: (context, snap) {
              if (snap.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${snap.error}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _school = null;
                        _schools = AppScope.read(context).schools();
                      }),
                      icon: const Icon(Icons.refresh),
                      label: Text(context.tr('retry')),
                    ),
                  ],
                );
              }
              if (!snap.hasData) return const LinearProgressIndicator();
              return DropdownButtonFormField<School>(
                initialValue: _school,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('school'),
                  prefixIcon: const Icon(Icons.school_outlined),
                ),
                items: [
                  for (final s in snap.data!)
                    DropdownMenuItem(
                      value: s,
                      child: Text(
                        s.city.isEmpty ? s.name : '${s.name} — ${s.city}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (s) => setState(() => _school = s),
              );
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.tr('full_name'),
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.tr('phone'),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _username,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.tr('username'),
              helperText: context.tr('username_rule'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.tr('password'),
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.tr('password_confirm'),
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(context.tr('create_account')),
          ),
        ],
      ),
    );
  }
}
