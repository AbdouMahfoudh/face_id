import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../services/matcher.dart';
import '../services/remote_api.dart';
import '../widgets/camera_view.dart';
import '../widgets/face_guide.dart';
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
      if (state.serverConfigured) {
        try {
          final online = await state.identifyOnline(embedding);
          final isLocal = state.people.any((p) => p.id == online?.person?.id);
          if (online != null && !isLocal && online.score > result.score) {
            result = online;
          }
        } on RemoteException {
          note = 'Hors ligne : comparaison avec ce téléphone uniquement.';
        }
      }
      if (!mounted) return;
      await _showSheet(
        _MatchSheet(
          result: result,
          otherFaces: analysis.faceCount - 1,
          note: note,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showSheet(Widget child) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SafeArea(child: child),
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final empty = state.people.isEmpty && !state.serverConfigured;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner un visage'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Changer de caméra',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _camera.currentState?.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraView(key: _camera),
          const FaceGuide(),
          if (empty)
            const Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    "La base est vide : ajoutez d'abord des personnes, sinon tout visage sera « Inconnu ».",
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Depuis la galerie',
                  iconSize: 28,
                  onPressed: _busy ? null : _scanFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                ),
                FloatingActionButton.large(
                  heroTag: 'scan',
                  onPressed: _busy ? null : _scanFromCamera,
                  child: _busy
                      ? const CircularProgressIndicator()
                      : const Icon(Icons.face_retouching_natural, size: 40),
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
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography_outlined, size: 56),
          SizedBox(height: 12),
          Text(
            'Aucun visage détecté',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Placez le visage de face, bien éclairé, dans le cadre.',
            textAlign: TextAlign.center,
          ),
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
    final scheme = Theme.of(context).colorScheme;
    final person = result.person;
    final percent = '${(result.score.clamp(0, 1) * 100).round()} %';

    final (Color color, IconData icon, String title) = switch (result.status) {
      MatchStatus.recognized => (
        Colors.green,
        Icons.verified,
        'Personne reconnue',
      ),
      MatchStatus.uncertain => (
        Colors.orange,
        Icons.help_outline,
        'À vérifier',
      ),
      MatchStatus.unknown => (scheme.error, Icons.person_off, 'INCONNU'),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (person == null)
            const Text(
              "Ce visage ne correspond à aucune personne enregistrée.",
              textAlign: TextAlign.center,
            )
          else ...[
            if (result.status == MatchStatus.uncertain)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Ressemblance partielle. Vérifiez l’identité avant de conclure.',
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: result.remote
                      ? (result.remotePhoto == null
                            ? null
                            : MemoryImage(result.remotePhoto!))
                      : (person.coverPhoto == null
                            ? null
                            : FileImage(File(person.coverPhoto!))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (person.role.isNotEmpty) Text(person.role),
                      Text(
                        'Similarité : $percent',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (result.remote)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Chip(
                            avatar: Icon(Icons.cloud_outlined, size: 18),
                            label: Text('Base en ligne'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (person.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(person.description),
            ],
            if (!result.remote) ...[
              const SizedBox(height: 12),
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
                child: const Text('Voir la fiche complète'),
              ),
            ],
          ],
          if (note != null) ...[
            const SizedBox(height: 12),
            Text(
              note!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (otherFaces > 0) ...[
            const SizedBox(height: 12),
            Text(
              '$otherFaces autre(s) visage(s) sur la photo : seul le plus grand a été analysé.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
