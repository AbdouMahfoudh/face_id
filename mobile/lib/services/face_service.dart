import 'dart:io';
import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceAnalysis {
  final int faceCount;
  final Float32List? embedding;
  final Uint8List? thumbnailJpg;

  const FaceAnalysis(this.faceCount, this.embedding, this.thumbnailJpg);
}

class FaceService {
  FaceService._(this._interpreter, this._detector);

  static const modelName = 'mobilefacenet-v1';
  static const _modelAsset = 'assets/models/mobilefacenet.tflite';
  static const _inputSize = 112;
  static const _embeddingSize = 192;

  final Interpreter _interpreter;
  final FaceDetector _detector;

  static Future<FaceService> create() async {
    final interpreter = await Interpreter.fromAsset(_modelAsset);
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        minFaceSize: 0.1,
      ),
    );
    return FaceService._(interpreter, detector);
  }

  /// Detects faces in the photo at [path] and embeds the largest one.
  Future<FaceAnalysis> analyze(String path) async {
    final tmp = await getTemporaryDirectory();
    final uprightPath =
        p.join(tmp.path, 'upright_${DateTime.now().microsecondsSinceEpoch}.jpg');
    try {
      // ML Kit and our crop must see the same pixels, so bake EXIF rotation first.
      final ok = await compute(_writeUpright, [path, uprightPath]);
      if (!ok) throw const FaceServiceException('Image illisible.');

      final faces =
          await _detector.processImage(InputImage.fromFilePath(uprightPath));
      if (faces.isEmpty) return const FaceAnalysis(0, null, null);

      faces.sort((a, b) => _area(b.boundingBox).compareTo(_area(a.boundingBox)));
      final face = faces.first;
      final left = face.landmarks[FaceLandmarkType.leftEye]?.position;
      final right = face.landmarks[FaceLandmarkType.rightEye]?.position;
      final box = face.boundingBox;

      final crop = await compute(
        _cropFace,
        _CropRequest(
          path: uprightPath,
          cx: box.center.dx,
          cy: box.center.dy,
          size: max(box.width, box.height),
          eyes: (left != null && right != null)
              ? [left.x.toDouble(), left.y.toDouble(), right.x.toDouble(), right.y.toDouble()]
              : null,
        ),
      );

      final a = _embed(crop.input);
      final b = _embed(crop.flippedInput);
      final sum = Float32List(_embeddingSize);
      for (var i = 0; i < _embeddingSize; i++) {
        sum[i] = a[i] + b[i];
      }
      return FaceAnalysis(faces.length, _l2normalize(sum), crop.thumbnailJpg);
    } finally {
      final f = File(uprightPath);
      if (await f.exists()) await f.delete();
    }
  }

  Float32List _embed(Float32List input) {
    final output = [List<double>.filled(_embeddingSize, 0)];
    _interpreter.run(input.buffer, output);
    return _l2normalize(Float32List.fromList(output[0]));
  }

  static double _area(Rect rect) => rect.width * rect.height;

  static Float32List _l2normalize(Float32List v) {
    double n = 0;
    for (final x in v) {
      n += x * x;
    }
    n = sqrt(n);
    if (n == 0) return v;
    return Float32List.fromList([for (final x in v) x / n]);
  }

  void dispose() {
    _interpreter.close();
    _detector.close();
  }
}

class FaceServiceException implements Exception {
  final String message;
  const FaceServiceException(this.message);
  @override
  String toString() => message;
}

bool _writeUpright(List<String> paths) {
  final decoded = img.decodeImage(File(paths[0]).readAsBytesSync());
  if (decoded == null) return false;
  var image = img.bakeOrientation(decoded);
  const maxSide = 1280;
  if (max(image.width, image.height) > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide)
        : img.copyResize(image, height: maxSide);
  }
  File(paths[1]).writeAsBytesSync(img.encodeJpg(image, quality: 92));
  return true;
}

class _CropRequest {
  final String path;
  final double cx, cy, size;
  final List<double>? eyes;

  const _CropRequest({
    required this.path,
    required this.cx,
    required this.cy,
    required this.size,
    this.eyes,
  });
}

class _CropResult {
  final Float32List input;
  final Float32List flippedInput;
  final Uint8List thumbnailJpg;

  const _CropResult(this.input, this.flippedInput, this.thumbnailJpg);
}

_CropResult _cropFace(_CropRequest r) {
  final image = img.decodeJpg(File(r.path).readAsBytesSync())!;

  var angle = 0.0;
  final e = r.eyes;
  if (e != null) {
    // Order eyes by x so the angle is the tilt of the eye line in the image.
    final (x1, y1, x2, y2) =
        e[0] <= e[2] ? (e[0], e[1], e[2], e[3]) : (e[2], e[3], e[0], e[1]);
    angle = atan2(y2 - y1, x2 - x1);
  }
  final cosA = cos(angle), sinA = sin(angle);

  // Samples a rotated square window centered on the face (bilinear).
  img.Image sample(int outSize, double side) {
    final out = img.Image(width: outSize, height: outSize);
    for (var v = 0; v < outSize; v++) {
      final y = ((v + 0.5) / outSize - 0.5) * side;
      for (var u = 0; u < outSize; u++) {
        final x = ((u + 0.5) / outSize - 0.5) * side;
        final sx = (r.cx + x * cosA - y * sinA).clamp(0.0, image.width - 1.0);
        final sy = (r.cy + x * sinA + y * cosA).clamp(0.0, image.height - 1.0);
        out.setPixel(u, v, image.getPixelLinear(sx, sy));
      }
    }
    return out;
  }

  const n = FaceService._inputSize;
  final face = sample(n, r.size * 1.1);
  final input = Float32List(n * n * 3);
  final flipped = Float32List(n * n * 3);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final px = face.getPixel(x, y);
      final i = (y * n + x) * 3;
      final j = (y * n + (n - 1 - x)) * 3;
      final rr = (px.r - 127.5) / 128.0;
      final gg = (px.g - 127.5) / 128.0;
      final bb = (px.b - 127.5) / 128.0;
      input[i] = rr;
      input[i + 1] = gg;
      input[i + 2] = bb;
      flipped[j] = rr;
      flipped[j + 1] = gg;
      flipped[j + 2] = bb;
    }
  }

  final thumb = sample(320, r.size * 1.8);
  return _CropResult(input, flipped, img.encodeJpg(thumb, quality: 88));
}
