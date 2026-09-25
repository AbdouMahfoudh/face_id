import 'package:flutter/material.dart';

import '../widgets/camera_view.dart';
import '../widgets/face_guide.dart';

/// Full-screen camera that returns the captured photo path.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, this.title = 'Prendre une photo'});

  final String title;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _camera = GlobalKey<CameraViewState>();
  bool _busy = false;

  Future<void> _shoot() async {
    setState(() => _busy = true);
    try {
      final path = await _camera.currentState?.capture();
      if (path != null && mounted) Navigator.pop(context, path);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: FloatingActionButton.large(
                heroTag: 'capture',
                onPressed: _busy ? null : _shoot,
                child: _busy
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.camera_alt),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
