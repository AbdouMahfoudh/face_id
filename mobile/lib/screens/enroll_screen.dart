import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../services/face_service.dart';
import '../widgets/camera_view.dart';
import '../widgets/face_guide.dart';

enum Pose {
  front('Regardez droit devant', Icons.face),
  left('Tournez lentement la tête à gauche', Icons.arrow_back),
  right('Tournez lentement la tête à droite', Icons.arrow_forward),
  up('Levez légèrement la tête', Icons.arrow_upward),
  down('Baissez légèrement la tête', Icons.arrow_downward);

  const Pose(this.instruction, this.icon);

  final String instruction;
  final IconData icon;

  /// Which pose a head rotation (degrees) corresponds to, if any.
  /// ML Kit: positive yaw = face turned toward the image's right side,
  /// positive pitch = looking up.
  static Pose? of(double yaw, double pitch) {
    if (yaw.abs() < 10 && pitch.abs() < 10) return front;
    if (pitch.abs() < 20) {
      if (yaw >= 25) return left;
      if (yaw <= -25) return right;
    }
    if (yaw.abs() < 20) {
      if (pitch >= 15) return up;
      if (pitch <= -12) return down;
    }
    return null;
  }
}

/// Guided enrollment: the user follows instructions and each pose is
/// captured automatically. Returns the captured faces (front first).
class EnrollScreen extends StatefulWidget {
  const EnrollScreen({super.key});

  @override
  State<EnrollScreen> createState() => _EnrollScreenState();
}

class _EnrollScreenState extends State<EnrollScreen> {
  final _camera = GlobalKey<CameraViewState>();
  final Map<Pose, EnrolledFace> _captured = {};
  String? _hint;
  bool _running = true;

  Pose? get _target =>
      Pose.values.where((p) => !_captured.containsKey(p)).firstOrNull;

  @override
  void initState() {
    super.initState();
    _loop();
  }

  @override
  void dispose() {
    _running = false;
    super.dispose();
  }

  Future<void> _loop() async {
    final faces = AppScope.read(context).faces;
    while (_running && mounted) {
      final cam = _camera.currentState;
      String? path;
      try {
        if (cam != null && cam.ready) path = await cam.capture();
      } catch (_) {
        path = null;
      }
      if (path == null) {
        await Future.delayed(const Duration(milliseconds: 300));
        continue;
      }
      try {
        final a = await faces.analyze(path);
        if (_running && mounted) _handle(a);
      } catch (_) {
        // Unreadable frame: just try the next one.
      } finally {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }
    }
  }

  void _handle(FaceAnalysis a) {
    if (a.faceCount == 0) {
      setState(() => _hint = 'Placez votre visage dans le cadre');
      return;
    }
    if (a.faceCount > 1) {
      setState(() => _hint = 'Une seule personne devant la caméra');
      return;
    }
    final pose = Pose.of(a.yaw, a.pitch);
    // The front photo comes first: it is the reference and the profile photo.
    final accept =
        pose != null &&
        !_captured.containsKey(pose) &&
        (pose == Pose.front || _captured.containsKey(Pose.front));
    if (!accept) {
      setState(() => _hint = null);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _captured[pose] = EnrolledFace(a.embedding!, a.thumbnailJpg!);
      _hint = null;
    });
    if (_target == null) _finish();
  }

  void _finish() {
    _running = false;
    Navigator.pop(context, [
      for (final p in Pose.values)
        if (_captured[p] != null) _captured[p]!,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final target = _target;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Enregistrement du visage'),
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
          CameraView(
            key: _camera,
            preferFront: true,
            resolution: ResolutionPreset.medium,
          ),
          FaceGuide(
            color: _captured.isEmpty ? Colors.white : Colors.greenAccent,
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      target?.icon ?? Icons.check_circle,
                      size: 36,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            target?.instruction ?? 'Terminé !',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_hint != null)
                            Text(_hint!, style: TextStyle(color: scheme.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final p in Pose.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: _captured.containsKey(p)
                              ? Colors.green
                              : p == target
                              ? scheme.primary
                              : Colors.white24,
                          child: Icon(
                            _captured.containsKey(p) ? Icons.check : p.icon,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_captured.length} / ${Pose.values.length} poses',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: _captured.containsKey(Pose.front) ? _finish : null,
                  child: const Text('Terminer maintenant'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
