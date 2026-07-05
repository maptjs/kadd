import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';
import '../models/locked_app.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Counts push-up reps using ML Kit's on-device pose detector.
///
/// Rep-counting logic: track the elbow angle (shoulder–elbow–wrist). A rep
/// registers on the down->up transition once the angle has crossed both the
/// "down" and "up" thresholds — a simple, cheap state machine that's robust
/// to jitter without needing a trained classifier. Squats would mirror this
/// using the hip–knee–ankle angle instead.
class RepCameraScreen extends StatefulWidget {
  final LockedApp app;
  const RepCameraScreen({super.key, required this.app});

  @override
  State<RepCameraScreen> createState() => _RepCameraScreenState();
}

enum _RepPhase { up, down }

class _RepCameraScreenState extends State<RepCameraScreen> {
  CameraController? _controller;
  final _poseDetector = PoseDetector(options: PoseDetectorOptions());
  bool _busy = false;
  int _reps = 0;
  _RepPhase _phase = _RepPhase.up;

  static const _downAngleThreshold = 90.0; // elbow angle below this = "down"
  static const _upAngleThreshold = 160.0; // elbow angle above this = "up"

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21, // single-plane on Android, matches _toInputImage below
    );
    await controller.initialize();
    if (!mounted) return;
    setState(() => _controller = controller);
    controller.startImageStream(_onFrame);
  }

  // Maps the device's current physical rotation to the degrees ML Kit
  // expects, before combining it with the camera sensor's own mounting
  // rotation below.
  static const _deviceOrientationDegrees = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Future<void> _onFrame(CameraImage image) async {
    if (_busy) return;
    _busy = true;
    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isEmpty) return;

      final pose = poses.first;
      final angle = _elbowAngle(pose);
      if (angle == null) return;

      if (_phase == _RepPhase.up && angle < _downAngleThreshold) {
        _phase = _RepPhase.down;
      } else if (_phase == _RepPhase.down && angle > _upAngleThreshold) {
        _phase = _RepPhase.up;
        setState(() => _reps++);
        _checkComplete();
      }
    } finally {
      _busy = false;
    }
  }

  double? _elbowAngle(Pose pose) {
    final shoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final elbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final wrist = pose.landmarks[PoseLandmarkType.leftWrist];
    if (shoulder == null || elbow == null || wrist == null) return null;

    final a = atan2(shoulder.y - elbow.y, shoulder.x - elbow.x);
    final b = atan2(wrist.y - elbow.y, wrist.x - elbow.x);
    var angle = (a - b) * 180 / pi;
    angle = angle.abs();
    if (angle > 180) angle = 360 - angle;
    return angle;
  }

  /// Converts a raw [CameraImage] frame into the [InputImage] ML Kit expects.
  ///
  /// Two things make this fiddly and are handled explicitly here:
  ///  1. Rotation: ML Kit wants the image rotation relative to how a person
  ///     would view it upright. That's the camera sensor's own mounting
  ///     rotation (`sensorOrientation`, fixed per device) combined with how
  ///     the phone is currently held (`deviceOrientation`), and the two
  ///     combine in opposite directions for front vs. back cameras.
  ///  2. Format/plane layout: requesting `ImageFormatGroup.nv21` above
  ///     guarantees Android hands back a single interleaved plane, so we can
  ///     pass its bytes straight through instead of manually concatenating
  ///     Y/U/V planes (which is only needed for the default yuv420 format).
  InputImage? _toInputImage(CameraImage image) {
    if (_controller == null) return null;
    final camera = _controller!.description;

    final sensorOrientation = camera.sensorOrientation;
    int rotationCompensation = _deviceOrientationDegrees[_controller!.value.deviceOrientation] ?? 0;
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    final rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    if (rotation == null) return null;

    // We only support Android/NV21 here — this screen is Android-only per
    // the project's current scope (see README).
    if (!Platform.isAndroid) return null;
    if (image.planes.length != 1) return null; // guards against a misconfigured imageFormatGroup
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _checkComplete() {
    final state = context.read<AppState>();
    final needed = widget.app.repsFor(state.difficulty);
    if (_reps >= needed) {
      state.onRepsVerified(widget.app);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final needed = widget.app.repsFor(state.difficulty);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.ink,
        body: Stack(
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              Positioned.fill(child: CameraPreview(_controller!))
            else
              const Center(child: CircularProgressIndicator(color: AppColors.unlock)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        border: Border.all(color: AppColors.unlock.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('● عقلات', style: AppTextStyles.kufi(size: 12, color: AppColors.unlock)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.black.withOpacity(0.4),
                        child: const Icon(Icons.close, size: 15, color: AppColors.textDim),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.4),
              child: Column(
                children: [
                  Text('$_reps', style: AppTextStyles.kufi(size: 52)),
                  Text('من $needed عقلة', style: AppTextStyles.body(size: 12, color: AppColors.textDim)),
                ],
              ),
            ),
            Positioned(
              bottom: 56,
              left: 18,
              right: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'انزل ببطء حتى يقترب صدرك من الأرض، وثبّت ظهرك مستقيمًا',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(size: 12.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
