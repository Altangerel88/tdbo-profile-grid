import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const _darkShader = 'shaders/glass_bg.frag';
const _lightShader = 'shaders/glass_bg_light.frag';

final Map<String, Future<ui.FragmentProgram>> _programs = {};

Future<ui.FragmentProgram> _load(String asset) =>
    _programs.putIfAbsent(asset, () => ui.FragmentProgram.fromAsset(asset));

/// Full-screen animated background: a soft light drifting behind tilted
/// glass slabs, on black (`shaders/glass_bg.frag`) or on the light #F7F7F7
/// page (`shaders/glass_bg_light.frag`).
class GlassBackground extends StatefulWidget {
  const GlassBackground({super.key})
    : shader = _darkShader,
      fallback = const Color(0xFF000206);

  const GlassBackground.light({super.key})
    : shader = _lightShader,
      fallback = const Color(0xFFF7F7F7);

  final String shader;

  /// Painted until the shader has loaded.
  final Color fallback;

  /// Loads both shaders and draws each once off-screen, so the first switch
  /// between versions doesn't stall on shader compilation.
  static Future<void> precache() async {
    for (final asset in const [_darkShader, _lightShader]) {
      final shader = (await _load(asset)).fragmentShader()
        ..setFloat(0, 8)
        ..setFloat(1, 8)
        ..setFloat(2, 0);
      final recorder = ui.PictureRecorder();
      Canvas(
        recorder,
      ).drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..shader = shader);
      final picture = recorder.endRecording();
      (await picture.toImage(8, 8)).dispose();
      picture.dispose();
      shader.dispose();
    }
  }

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground>
    with SingleTickerProviderStateMixin {
  // Start mid-loop so the first frame already has the light near the glass.
  static const double _startAt = 4.0;

  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  final ValueNotifier<double> _time = ValueNotifier(_startAt);

  @override
  void initState() {
    super.initState();
    _load(widget.shader).then((program) {
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
        painter: _GlassPainter(_shader, _time, widget.fallback),
      ),
    );
  }
}

class _GlassPainter extends CustomPainter {
  _GlassPainter(this.shader, this.time, this.fallback) : super(repaint: time);

  final ui.FragmentShader? shader;
  final ValueNotifier<double> time;
  final Color fallback;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shader = this.shader;
    if (shader == null) {
      canvas.drawRect(rect, Paint()..color = fallback);
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
