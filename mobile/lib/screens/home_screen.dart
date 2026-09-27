import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'people_screen.dart';
import 'person_form_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final session = state.session!;
    final count = state.people.length;

    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    final (
      IconData statusIcon,
      String statusText,
    ) = switch (state.serverStatus) {
      ServerStatus.online => (Icons.cloud_done, context.tr('online')),
      ServerStatus.offline => (Icons.cloud_off, context.tr('offline')),
      ServerStatus.unknown => (Icons.cloud_queue, context.tr('connecting')),
    };

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppLogo(size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.schoolName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${session.fullName} · ${context.tr(session.isAdmin ? 'role_admin' : 'role_agent')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('settings'),
                      color: Colors.white,
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => open(const SettingsScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    _Stat(
                      value: '$count',
                      label: context.tr('people_on_phone'),
                    ),
                    const SizedBox(width: 12),
                    _Stat(
                      value: '${state.pendingCount}',
                      label: context.tr('pending_upload'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(statusIcon, color: Colors.white, size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                statusText,
                                maxLines: 2,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.canScan) ...[
                  _ScanCard(onTap: () => open(const ScanScreen())),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _Tile(
                        icon: Icons.groups_2_outlined,
                        title: context.tr('people'),
                        color: AppColors.night,
                        onTap: () => open(const PeopleScreen()),
                      ),
                    ),
                    if (state.canEdit) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: _Tile(
                          icon: Icons.person_add_alt_1_outlined,
                          title: context.tr('add'),
                          color: AppColors.teal,
                          onTap: () => open(const PersonFormScreen()),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!state.canScan && !state.canEdit) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.tr('no_permissions')),
                    ),
                  ),
                ],
                if (state.lastSyncError != null) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                      ),
                      title: Text(state.lastSyncError!),
                      subtitle: Text(context.tr('offline_info')),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value, label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 84),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Big call-to-action with a softly pulsing icon.
class _ScanCard extends StatefulWidget {
  const _ScanCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ScanCard> createState() => _ScanCardState();
}

class _ScanCardState extends State<_ScanCard>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.teal, AppColors.cyan],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.92, end: 1.06).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.center_focus_strong,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('scan_face'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('scan_subtitle'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
