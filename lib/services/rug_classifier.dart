import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Wraps a TFLite image classifier trained on prayer-rug vs. not-prayer-rug
/// photos (see assets/models/README.md for how to produce one, e.g. via
/// Google's Teachable Machine for a fast first version).
///
/// Handles both export formats Teachable Machine can produce:
///  - float32 model: input pixels expected as 0.0–1.0, output already a
///    probability per class.
///  - quantized (uint8) model: input pixels expected as raw 0–255 bytes,
///    output is a uint8 that must be divided by 255 to get a probability.
/// Which one you have is read from the model itself at load time, so this
/// class works unmodified either way.
class RugClassifier {
  Interpreter? _interpreter;
  List<String> _labels = [];
  int _rugLabelIndex = 0;
  late int _inputSize;
  late TensorType _inputType;

  bool get isLoaded => _interpreter != null;

  /// Call once (e.g. in RugScanScreen.initState) — loading the model and
  /// label file from assets is I/O-bound and shouldn't run per-frame.
  Future<void> load({
    String modelAsset = 'assets/models/rug_classifier.tflite',
    String labelsAsset = 'assets/models/labels.txt',
  }) async {
    try {
      _interpreter = await Interpreter.fromAsset(modelAsset);
    } catch (e) {
      // Model not bundled yet — expected until assets/models/README.md's
      // training plan is carried out. Callers should treat isLoaded==false
      // as "always fail closed", same as the previous hardcoded stub did.
      _interpreter = null;
      return;
    }

    final inputShape = _interpreter!.getInputTensor(0).shape; // [1, H, W, 3]
    _inputSize = inputShape[1];
    _inputType = _interpreter!.getInputTensor(0).type;

    try {
      final raw = await rootBundle.loadString(labelsAsset);
      _labels = raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          // Teachable Machine writes "0 rug", "1 not_rug" — drop the index.
          .map((l) => l.contains(' ') ? l.substring(l.indexOf(' ') + 1) : l)
          .toList();
      _rugLabelIndex = _labels.indexWhere((l) => l.toLowerCase().contains('rug'));
      if (_rugLabelIndex == -1) _rugLabelIndex = 0; // fall back to first class
    } catch (e) {
      _labels = ['rug', 'not_rug'];
      _rugLabelIndex = 0;
    }
  }

  /// Returns the model's confidence (0.0–1.0) that [jpegBytes] shows a
  /// prayer rug. Returns 0.0 if no model is loaded, so callers fail closed
  /// by default rather than accidentally unlocking on a missing model.
  Future<double> classify(Uint8List jpegBytes) async {
    if (_interpreter == null) return 0.0;

    final decoded = img.decodeImage(jpegBytes);
    if (decoded == null) return 0.0;
    final resized = img.copyResize(decoded, width: _inputSize, height: _inputSize);

    final input = _inputType == TensorType.uint8
        ? _toUint8Input(resized)
        : _toFloat32Input(resized);

    final outputTensor = _interpreter!.getOutputTensor(0);
    final output = outputTensor.type == TensorType.uint8
        ? [List<int>.filled(_labels.length, 0)]
        : [List<double>.filled(_labels.length, 0.0)];

    _interpreter!.run(input, output);

    final scores = output[0];
    final rawScore = scores[_rugLabelIndex];
    final confidence = outputTensor.type == TensorType.uint8
        ? (rawScore as int) / 255.0
        : (rawScore as double);

    return confidence.clamp(0.0, 1.0);
  }

  List<List<List<List<double>>>> _toFloat32Input(img.Image image) {
    return [
      List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final p = image.getPixel(x, y);
          return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        }),
      ),
    ];
  }

  List<List<List<List<int>>>> _toUint8Input(img.Image image) {
    return [
      List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final p = image.getPixel(x, y);
          return [p.r.toInt(), p.g.toInt(), p.b.toInt()];
        }),
      ),
    ];
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
