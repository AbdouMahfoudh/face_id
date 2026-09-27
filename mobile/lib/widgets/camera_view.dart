import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Live camera preview; call [CameraViewState.capture] to take a photo.
class CameraView extends StatefulWidget {
  const CameraView({
    super.key,
    this.preferFront = false,
    this.resolution = ResolutionPreset.high,
  });

  final bool preferFront;
  final ResolutionPreset resolution;

  @override
  State<CameraView> createState() => CameraViewState();
}

class CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _index = 0;
  String? _error;

  bool get ready => _controller?.value.isInitialized ?? false;
  bool get canSwitch => _cameras.length > 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'Aucune caméra disponible.');
        return;
      }
      final wanted = widget.preferFront
          ? CameraLensDirection.front
          : CameraLensDirection.back;
      final i = _cameras.indexWhere((c) => c.lensDirection == wanted);
      _index = i < 0 ? 0 : i;
      await _start();
    } on CameraException catch (e) {
      setState(() => _error = _describe(e));
    }
  }

  Future<void> _start() async {
    final old = _controller;
    _controller = null;
    if (mounted) setState(() {});
    await old?.dispose();
    final c = CameraController(
      _cameras[_index],
      widget.resolution,
      enableAudio: false,
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _error = null;
      });
    } on CameraException catch (e) {
      await c.dispose();
      if (mounted) setState(() => _error = _describe(e));
    }
  }

  String _describe(CameraException e) {
    if (e.code.contains('AccessDenied') || e.code.contains('Permission')) {
      return "Accès à la caméra refusé.\nAutorisez-le dans les paramètres du téléphone.";
    }
    return 'Caméra indisponible (${e.code}).';
  }

  Future<void> switchCamera() async {
    if (!canSwitch) return;
    _index = (_index + 1) % _cameras.length;
    await _start();
  }

  Future<String?> capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) {
      return null;
    }
    final file = await c.takePicture();
    return file.path;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameras.isEmpty) return;
    if (state == AppLifecycleState.inactive) {
      final c = _controller;
      _controller = null;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      );
    }
    return Container(
      color: Colors.black,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: c.value.previewSize?.height ?? 1,
            height: c.value.previewSize?.width ?? 1,
            child: CameraPreview(c),
          ),
        ),
      ),
    );
  }
}
