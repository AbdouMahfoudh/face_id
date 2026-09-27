import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../services/matcher.dart';
import '../services/remote_api.dart';
import '../theme.dart';
import '../widgets/camera_view.dart';
import '../widgets/face_guide.dart';
import '../widgets/person_widgets.dart';
import 'person_detail_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _camera = GlobalKey<CameraViewState>();
  bool _busy = false;

  Future<void> _scanFromCamera() async {
    await _run(() async => _camera.currentState?.capture());
  }

  Future<void> _scanFromGallery() async {
    await _run(() async {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery);
      return f?.path;
    });
  }

  Future<void> _run(Future<String?> Function() getPhoto) async {
    if (_busy) return;
    setState(() => _busy = true);
    final state = AppScope.read(context);
    try {
      final path = await getPhoto();
      if (path == null) return;
      final analysis = await state.faces.analyze(path);
      if (!mounted) return;
      if (analysis.embedding == null) {
        await _showSheet(const _NoFaceResult());
        return;
      }
      final embedding = analysis.embedding!;
      var result = state.identify(embedding);
      String? note;
      try {
        final online = await state.identifyOnline(embedding);
        final isLocal = state.people.any((p) => p.id == online.person?.id);
        if (!isLocal && online.score > result.score) result = online;
      } on RemoteException {
        note = 'offline_scan_note';
      }
      if (!mounted || state.session == null) return;
      await _showSheet(
        _MatchSheet(
          result: result,
          otherFaces: analysis.faceCount - 1,
          note: note,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${context.tr('error')} : $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showSheet(Widget child) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(child: child),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.tr('scan_face')),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        actions: [
          IconButton(
            tooltip: context.tr('switch_camera'),
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _camera.currentState?.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraView(key: _camera),
          const FaceGuide(color: AppColors.cyan),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  tooltip: context.tr('from_gallery'),
                  iconSize: 28,
                  onPressed: _busy ? null : _scanFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                ),
                SizedBox(
                  width: 88,
                  height: 88,
                  child: FloatingActionButton.large(
                    heroTag: 'scan',
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    onPressed: _busy ? null : _scanFromCamera,
                    child: _busy
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.face_retouching_natural, size: 42),
                  ),
                ),
                const SizedBox(width: 56),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoFaceResult extends StatelessWidget {
  const _NoFaceResult();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, size: 56),
          const SizedBox(height: 12),
          Text(
            context.tr('no_face'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(context.tr('no_face_tip'), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MatchSheet extends StatelessWidget {
  const _MatchSheet({
    required this.result,
    required this.otherFaces,
    this.note,
  });

  final MatchResult result;
  final int otherFaces;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final person = result.person;
    final percent = '${(result.score.clamp(0, 1) * 100).round()} %';

    final (Color color, IconData icon, String title) = switch (result.status) {
      MatchStatus.recognized => (
        AppColors.success,
        Icons.verified,
        context.tr('recognized'),
      ),
      MatchStatus.uncertain => (
        AppColors.warning,
        Icons.help_outline,
        context.tr('to_check'),
      ),
      MatchStatus.unknown => (
        AppColors.danger,
        Icons.person_off,
        context.tr('unknown'),
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 30),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (person == null)
            Text(context.tr('unknown_info'), textAlign: TextAlign.center)
          else ...[
            if (result.status == MatchStatus.uncertain)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  context.tr('uncertain_info'),
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: PersonAvatar(
                    person: result.remote ? null : person,
                    photo: result.remotePhoto,
                    radius: 44,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        [
                          context.tr('type_${person.type}'),
                          if (person.subtitle.isNotEmpty) person.subtitle,
                        ].join(' · '),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Pill(
                            '${context.tr('similarity')} $percent',
                            color: color,
                          ),
                          if (person.status != 'actif')
                            Pill(
                              context.tr('status_${person.status}'),
                              color: statusColor(person.status),
                            ),
                          if (result.remote)
                            Pill(
                              context.tr('online_base'),
                              color: AppColors.night,
                              icon: Icons.cloud_outlined,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PersonInfoSections(
              person: person,
              showSensitive: state.canSeeSensitive,
            ),
            ManagementLinkButton(person: person),
            if (!result.remote)
              OutlinedButton(
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(
                    MaterialPageRoute(
                      builder: (_) => PersonDetailScreen(personId: person.id),
                    ),
                  );
                },
                child: Text(context.tr('open_record')),
              ),
          ],
          if (note != null) ...[
            const SizedBox(height: 12),
            Text(
              context.tr(note!),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (otherFaces > 0) ...[
            const SizedBox(height: 12),
            Text(
              context.tr('other_faces', {'n': otherFaces}),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
