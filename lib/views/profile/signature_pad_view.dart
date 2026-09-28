import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:resq/services/api_service.dart';
import 'package:resq/utils/constants/theme_constants.dart';

/// A finger-drawn signature pad for the Digital Health Card's "Signature ·
/// Lagda" box. Draws strokes on a plain canvas and, on save, replays just
/// those strokes onto a small offscreen canvas cropped tightly to their
/// bounding box (see _exportPng) rather than capturing the whole drawing
/// pad — the pad itself is much bigger than the signature box on the card,
/// so exporting the full (mostly blank) canvas made the actual ink look
/// tiny once it was scaled down to fit there. Uploads the cropped PNG
/// through ApiService.uploadSignature and pops back with the resulting
/// hosted URL so the caller can update the card immediately.
class SignaturePadView extends StatefulWidget {
  final String token;

  const SignaturePadView({super.key, required this.token});

  @override
  State<SignaturePadView> createState() => _SignaturePadViewState();
}

class _SignaturePadViewState extends State<SignaturePadView> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  bool _saving = false;

  bool get _hasContent => _strokes.isNotEmpty;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = [details.localPosition];
      _strokes.add(_currentStroke!);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() => _currentStroke?.add(details.localPosition));
  }

  void _onPanEnd(DragEndDetails details) {
    _currentStroke = null;
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
  }

  Future<void> _save() async {
    if (!_hasContent || _saving) return;
    setState(() => _saving = true);
    try {
      final pngBytes = await _exportPng();
      final url = await ApiService.uploadSignature(widget.token, pngBytes);
      if (!mounted) return;
      Navigator.of(context).pop(url);
    } on ApiException catch (e) {
      // A 403 here means the cooldown lapsed between opening this screen and
      // saving (DigitalHealthCardView already checks before letting the
      // donor in) — e.message is already the donor-facing "you can update
      // it again on <date>" text from the server, no need to prefix it.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save signature: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Replays the drawn strokes onto a small offscreen canvas cropped to
  // their bounding box (plus a small margin), instead of capturing the
  // whole drawing pad. The pad is a big screen-sized rectangle so the
  // donor has room to draw comfortably, but the card's signature box is
  // tiny — exporting the full pad meant almost the entire image was blank,
  // and BoxFit.contain on the card shrank that whole blank canvas down,
  // making the actual ink barely visible. Cropping first means the ink
  // fills the exported image, which is what actually gets scaled to fit
  // the card.
  Future<Uint8List> _exportPng() async {
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final stroke in _strokes) {
      for (final point in stroke) {
        if (point.dx < minX) minX = point.dx;
        if (point.dy < minY) minY = point.dy;
        if (point.dx > maxX) maxX = point.dx;
        if (point.dy > maxY) maxY = point.dy;
      }
    }
    if (!minX.isFinite) throw Exception('Nothing was drawn.');

    const margin = 20.0;
    minX -= margin;
    minY -= margin;
    maxX += margin;
    maxY += margin;
    final width = maxX - minX;
    final height = maxY - minY;

    const scale = 4.0; // crisp on the card despite the small crop
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    final paint = Paint()
      ..color = ResQTheme.textDark
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      final shifted = stroke.map((p) => p.translate(-minX, -minY)).toList();
      if (shifted.length < 2) {
        if (shifted.isNotEmpty) {
          canvas.drawCircle(shifted.first, 1.5, Paint()..color = ResQTheme.textDark);
        }
        continue;
      }
      final path = Path()..moveTo(shifted.first.dx, shifted.first.dy);
      for (final point in shifted.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage((width * scale).ceil(), (height * scale).ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Could not export the signature image.');
    return byteData.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Digitally')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Draw your signature in the box below, then save. This will '
                'appear on your Digital Health Card.',
                style: ResQTheme.bodyText.copyWith(color: ResQTheme.textMuted),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(ResQTheme.cardRadius),
                    border: Border.all(color: ResQTheme.lightBorder, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: CustomPaint(
                          painter: _SignaturePainter(_strokes),
                          size: Size.infinite,
                        ),
                      ),
                      if (!_hasContent)
                        const Center(
                          child: Text(
                            'Sign here',
                            style: TextStyle(color: Color(0xFFC9C4BA), fontSize: 16),
                          ),
                        ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 12,
                        child: Container(height: 1, color: ResQTheme.lightBorder),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _hasContent && !_saving ? _clear : null,
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _hasContent && !_saving ? _save : null,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Signature'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ResQTheme.textDark
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.isNotEmpty) canvas.drawPoints(ui.PointMode.points, stroke, paint..strokeWidth = 3);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
