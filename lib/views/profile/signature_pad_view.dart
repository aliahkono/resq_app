import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:resq/services/api_service.dart';
import 'package:resq/utils/constants/theme_constants.dart';

/// A finger-drawn signature pad for the Digital Health Card's "Signature ·
/// Lagda" box. Draws strokes on a plain canvas, exports them as a PNG
/// (transparent background, ink only) via RenderRepaintBoundary, uploads it
/// through ApiService.uploadSignature, and pops back with the resulting
/// hosted URL so the caller can update the card immediately.
class SignaturePadView extends StatefulWidget {
  final String token;

  const SignaturePadView({super.key, required this.token});

  @override
  State<SignaturePadView> createState() => _SignaturePadViewState();
}

class _SignaturePadViewState extends State<SignaturePadView> {
  final GlobalKey _boundaryKey = GlobalKey();
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
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not capture the signature.');
      // 3x pixel ratio so the exported PNG stays crisp on the card even
      // though the drawing surface itself is comparatively small.
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Could not export the signature image.');
      final pngBytes = byteData.buffer.asUint8List();

      final url = await ApiService.uploadSignature(widget.token, pngBytes);
      if (!mounted) return;
      Navigator.of(context).pop(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save signature: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                      RepaintBoundary(
                        key: _boundaryKey,
                        child: GestureDetector(
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          child: CustomPaint(
                            painter: _SignaturePainter(_strokes),
                            size: Size.infinite,
                          ),
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
