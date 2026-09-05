import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:resq/services/api_service.dart';

enum _CaptureKind { idFront, idBack, faceFront, faceLeft, faceRight, faceUp, faceDown }

class _CaptureStep {
  final _CaptureKind kind;
  final String title;
  final String instruction;
  final IconData icon;

  const _CaptureStep({required this.kind, required this.title, required this.instruction, required this.icon});
}

/// "Get Verified" flow — a separate step from the Profile screen (not part
/// of registration): scans the donor's valid ID front and back, then
/// guides them through five face captures (front, left, right, up, down).
///
/// Each face capture is run through on-device face detection (ML Kit) to
/// reject an obviously bad take — no face found, or the head isn't turned
/// roughly the way the step asked for — before letting the donor move on.
/// This is a capture-quality check only, not a security/identity check:
/// it can't detect a spoofed photo or confirm the ID actually belongs to
/// this person. Actually verifying identity happens after upload, either
/// by an admin reviewing these on the Web Dashboard or (later) a 3rd-party
/// KYC provider — this screen's job ends at getting good-quality images
/// into that review queue.
class GetVerifiedView extends StatefulWidget {
  final String token;

  const GetVerifiedView({super.key, required this.token});

  @override
  State<GetVerifiedView> createState() => _GetVerifiedViewState();
}

class _GetVerifiedViewState extends State<GetVerifiedView> {
  static const List<_CaptureStep> _steps = [
    _CaptureStep(
      kind: _CaptureKind.idFront,
      title: 'Scan ID — Front',
      instruction: 'Place the front of your valid government ID inside the frame. Make sure all text is readable.',
      icon: Icons.badge_outlined,
    ),
    _CaptureStep(
      kind: _CaptureKind.idBack,
      title: 'Scan ID — Back',
      instruction: 'Now flip it over and capture the back of the same ID.',
      icon: Icons.badge_outlined,
    ),
    _CaptureStep(
      kind: _CaptureKind.faceFront,
      title: 'Face — Straight Ahead',
      instruction: 'Look directly at the camera with a neutral expression.',
      icon: Icons.face_retouching_natural_rounded,
    ),
    _CaptureStep(
      kind: _CaptureKind.faceLeft,
      title: 'Face — Turn Left',
      instruction: 'Slowly turn your head to your left, about 45°.',
      icon: Icons.face_retouching_natural_rounded,
    ),
    _CaptureStep(
      kind: _CaptureKind.faceRight,
      title: 'Face — Turn Right',
      instruction: 'Now turn your head to your right, about 45°.',
      icon: Icons.face_retouching_natural_rounded,
    ),
    _CaptureStep(
      kind: _CaptureKind.faceUp,
      title: 'Face — Tilt Up',
      instruction: 'Tilt your chin up slightly, keeping your face in frame.',
      icon: Icons.face_retouching_natural_rounded,
    ),
    _CaptureStep(
      kind: _CaptureKind.faceDown,
      title: 'Face — Tilt Down',
      instruction: 'Tilt your chin down slightly, keeping your face in frame.',
      icon: Icons.face_retouching_natural_rounded,
    ),
  ];

  int _currentIndex = 0;
  final Map<_CaptureKind, String> _capturedPaths = {};
  bool _processing = false;
  String? _error;
  bool _submitting = false;

  late final FaceDetector _faceDetector;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(enableTracking: false, performanceMode: FaceDetectorMode.accurate),
    );
  }

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  _CaptureStep get _current => _steps[_currentIndex];
  bool get _isIdStep => _current.kind == _CaptureKind.idFront || _current.kind == _CaptureKind.idBack;
  bool get _isLastStep => _currentIndex == _steps.length - 1;

  Future<void> _capture() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 90);
    if (picked == null) {
      setState(() => _processing = false);
      return;
    }

    if (_isIdStep) {
      // No face-pose check for the ID photos themselves — just accept the
      // capture and move on.
      setState(() {
        _capturedPaths[_current.kind] = picked.path;
        _processing = false;
      });
      _advanceOrFinish();
      return;
    }

    // Face steps: run on-device detection to catch an obviously bad take
    // before it's uploaded. Thresholds here are a starting point — ML
    // Kit's exact angle sign/scale can vary a little by device/camera, so
    // treat these as needing a quick real-device calibration pass rather
    // than exact clinical figures.
    try {
      final faces = await _faceDetector.processImage(InputImage.fromFilePath(picked.path));
      if (faces.isEmpty) {
        setState(() {
          _error = 'No face detected — please make sure your face is clearly visible and try again.';
          _processing = false;
        });
        return;
      }
      final face = faces.first;
      final yaw = face.headEulerAngleY ?? 0; // left/right turn
      final pitch = face.headEulerAngleX ?? 0; // up/down tilt
      String? mismatch;
      switch (_current.kind) {
        case _CaptureKind.faceFront:
          if (yaw.abs() > 15 || pitch.abs() > 15) mismatch = 'Please face the camera directly.';
          break;
        case _CaptureKind.faceLeft:
          if (yaw < 15) mismatch = 'Please turn your head further to the left.';
          break;
        case _CaptureKind.faceRight:
          if (yaw > -15) mismatch = 'Please turn your head further to the right.';
          break;
        case _CaptureKind.faceUp:
          if (pitch < 10) mismatch = 'Please tilt your chin up a bit more.';
          break;
        case _CaptureKind.faceDown:
          if (pitch > -10) mismatch = 'Please tilt your chin down a bit more.';
          break;
        case _CaptureKind.idFront:
        case _CaptureKind.idBack:
          break;
      }

      if (mismatch != null) {
        setState(() {
          _error = mismatch;
          _processing = false;
        });
        return;
      }

      setState(() {
        _capturedPaths[_current.kind] = picked.path;
        _processing = false;
      });
      _advanceOrFinish();
    } catch (e) {
      setState(() {
        _error = 'Could not analyze that photo — please try again.';
        _processing = false;
      });
    }
  }

  void _advanceOrFinish() {
    if (_isLastStep) {
      _submit();
    } else {
      setState(() => _currentIndex++);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiService.submitVerification(
        widget.token,
        idFrontPath: _capturedPaths[_CaptureKind.idFront]!,
        idBackPath: _capturedPaths[_CaptureKind.idBack]!,
        facePosePaths: {
          'front': _capturedPaths[_CaptureKind.faceFront]!,
          'left': _capturedPaths[_CaptureKind.faceLeft]!,
          'right': _capturedPaths[_CaptureKind.faceRight]!,
          'up': _capturedPaths[_CaptureKind.faceUp]!,
          'down': _capturedPaths[_CaptureKind.faceDown]!,
        },
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: Color(0xFF9B1B20), size: 22),
              SizedBox(width: 10),
              Text('Submitted for Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text(
            'Your ID and photos have been submitted. This usually takes 1-2 business days to review — you\'ll be notified once your account is verified.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B1B20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true); // true = submitted, caller should refresh status
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit for review: ${e.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not reach the ResQ server. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9B1B20),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: (_processing || _submitting) ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Get Verified (${_currentIndex + 1}/${_steps.length})',
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: (_currentIndex) / _steps.length,
                backgroundColor: const Color(0xFFE5E7EB),
                color: const Color(0xFF9B1B20),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 28),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(color: Color(0xFFFDEBEC), shape: BoxShape.circle),
                  child: Icon(_current.icon, size: 44, color: const Color(0xFF9B1B20)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  _current.title,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _current.instruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.4),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_processing || _submitting) ? null : _capture,
                  icon: (_processing || _submitting)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt_rounded),
                  label: Text(
                    _submitting
                        ? 'SUBMITTING...'
                        : _processing
                            ? 'CHECKING...'
                            : (_isIdStep ? 'CAPTURE ID' : 'CAPTURE PHOTO'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B1B20),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}