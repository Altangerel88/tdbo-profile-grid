import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Full-screen animated background: a soft light drifting behind tilted
/// glass slabs on black (see `shaders/glass_bg.frag`).
class GlassBackground extends StatefulWidget {
  const GlassBackground({super.key});

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground>
    with SingleTickerProviderStateMixin {
  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset('shaders/glass_bg.frag');

  // Start mid-loop so the first frame already has the light near the glass.
  static const double _startAt = 4.0;

  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(_startAt);

  @override
  void initState() {
    super.initState();
    _program.then((program) {
      if (mounted) setState(() => _shader = program.fragmentShader());
    });
    _ticker = createTicker((elapsed) {
      _time.value = _startAt + elapsed.inMicroseconds / 1e6;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect "Reduce Motion": hold a still frame instead of animating.
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _GlassPainter(_shader, _time),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  _GlassPainter(this.shader, this.time) : super(repaint: time);

  final ui.FragmentShader? shader;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = this.shader;
    if (shader == null) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFF000206));
      return;
    }
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_GlassPainter old) => old.shader != shader;
}
