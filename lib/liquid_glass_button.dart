import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'glass_background.dart';

/// Loads the liquid-glass program once. Shader backdrop filters need Impeller
/// (iOS); elsewhere, e.g. on the web, the button falls back to a blur.
class LiquidGlassShader {
  LiquidGlassShader._();

  static ui.FragmentProgram? program;

  static bool get supported =>
      program != null && ui.ImageFilter.isShaderFilterSupported;

  static Future<void> load() async {
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    try {
      program = await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
    } catch (_) {
      program = null;
    }
  }
}

/// An iOS 27-style Liquid Glass button: the backdrop refracts at the rim and
/// is frosted toward pale (light) or smoke (dark), with a darkened edge and a
/// specular highlight that faces the background's drifting light.
///
/// Like interactive glass on iOS, it swells under the finger, light pools
/// where it is touched, and it springs back on release. It casts no shadow:
/// a backdrop filter would sample the shadow and bend it into a dark band.
class LiquidGlassButton extends StatefulWidget {
  const LiquidGlassButton({
    super.key,
    required this.child,
    required this.onTap,
    this.size = 64,
    this.radius = 16,
    this.dark = 1,
  });

  final Widget child;
  final VoidCallback onTap;
  final double size;
  final double radius;

  /// Appearance, animatable: 1 = dark (smoked glass), 0 = light (pale glass).
  final double dark;

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton>
    with TickerProviderStateMixin {
  // Bouncy on purpose: the release overshoots into a small squish.
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 380,
    damping: 17,
  );

  ui.FragmentShader? _shader;

  /// Repaints every frame so the highlight tracks the background's light.
  late final Ticker _ticker = createTicker((_) => setState(() {}));
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  /// Where the pane was painted, in device pixels (includes the press scale).
  Rect? _rect;
  double _dpr = 1;
  bool _pending = false;

  /// Touch position as a fraction of the pane.
  Offset _touch = const Offset(0.5, 0.5);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _press.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _springTo(double target) {
    _press.animateWith(
      SpringSimulation(_spring, _press.value, target, _press.velocity),
    );
  }

  void _setTouch(Offset local) {
    _touch = Offset(
      (local.dx / widget.size).clamp(0.0, 1.0),
      (local.dy / widget.size).clamp(0.0, 1.0),
    );
  }

  void _onPaintRect(Rect logical) {
    if (!mounted) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final rect = Rect.fromLTRB(
      logical.left * dpr,
      logical.top * dpr,
      logical.right * dpr,
      logical.bottom * dpr,
    );
    if ((rect == _rect && dpr == _dpr) || _pending) return;
    _pending = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!mounted) return;
      setState(() {
        _rect = rect;
        _dpr = dpr;
      });
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Unit vector from the pane toward the background's drifting light.
  Offset _lightDir() {
    final rect = _rect;
    if (rect == null || !_ticker.isActive) {
      return const Offset(-0.45, -0.89); // above-left, when still
    }
    final screen = MediaQuery.sizeOf(context);
    final orb = GlassBackground.orbAt(GlassBackground.time, screen);
    final v = orb - rect.center / _dpr;
    return v.distance < 1 ? const Offset(0, -1) : v / v.distance;
  }

  ui.ImageFilter _filter(Offset light, double press) {
    final dark = widget.dark;
    final blur = ui.lerpDouble(10, 14, dark)!;
    final shader = _shader;
    final rect = _rect;
    if (shader == null || rect == null) {
      return ui.ImageFilter.blur(sigmaX: blur * 1.6, sigmaY: blur * 1.6);
    }
    final scale = rect.width / (widget.size * _dpr);
    final k = _dpr * scale;
    final frost = Color.lerp(
      const Color(0xFFFAFAFC),
      const Color(0xFF2A2A2E),
      dark,
    )!;
    shader
      ..setFloat(2, rect.left)
      ..setFloat(3, rect.top)
      ..setFloat(4, rect.right)
      ..setFloat(5, rect.bottom)
      ..setFloat(6, widget.radius * k)
      ..setFloat(7, 9 * k)
      ..setFloat(8, 8 * k)
      ..setFloat(9, ui.lerpDouble(0.50, 0.55, dark)!)
      ..setFloat(10, ui.lerpDouble(0.60, 0.55, dark)!)
      ..setFloat(11, dark)
      ..setFloat(12, frost.r)
      ..setFloat(13, frost.g)
      ..setFloat(14, frost.b)
      ..setFloat(15, light.dx)
      ..setFloat(16, light.dy)
      ..setFloat(17, rect.left + _touch.dx * rect.width)
      ..setFloat(18, rect.top + _touch.dy * rect.height)
      ..setFloat(19, press.clamp(0.0, 1.0));
    return ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(shader),
      inner: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The program may finish loading after this widget first builds.
    if (_shader == null && LiquidGlassShader.supported) {
      _shader = LiquidGlassShader.program!.fragmentShader();
    }
    final radius = BorderRadius.circular(widget.radius);
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;

    return Listener(
      onPointerDown: (e) {
        _setTouch(e.localPosition);
        _springTo(1);
        HapticFeedback.lightImpact();
      },
      onPointerMove: (e) => _setTouch(e.localPosition),
      onPointerUp: (_) => _springTo(0),
      onPointerCancel: (_) => _springTo(0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _press,
            builder: (context, child) {
              final press = _press.value;
              final light = _lightDir();
              final shaderOn = _shader != null && _rect != null;
              final pane = highContrast
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          const Color(0xF7FFFFFF),
                          const Color(0xF2242426),
                          widget.dark,
                        ),
                        borderRadius: radius,
                        border: Border.all(
                          color: Color.lerp(
                            const Color(0x33000000),
                            const Color(0x40FFFFFF),
                            widget.dark,
                          )!,
                        ),
                      ),
                      child: child,
                    )
                  : ClipRRect(
                      borderRadius: radius,
                      child: BackdropFilter(
                        filter: _filter(light, press),
                        child: CustomPaint(
                          // Without the shader, paint the frost, rim and
                          // touch light that it would otherwise draw.
                          painter: shaderOn
                              ? null
                              : _FallbackGlassPainter(
                                  radius: widget.radius,
                                  dark: widget.dark,
                                  light: light,
                                  touch: _touch,
                                  press: press.clamp(0.0, 1.0),
                                ),
                          child: child,
                        ),
                      ),
                    );
              return Transform.scale(
                scale: 1 + 0.12 * press,
                child: _PaintRectReporter(onRect: _onPaintRect, child: pane),
              );
            },
            child: Center(child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Glass approximation for renderers without shader backdrop filters.
class _FallbackGlassPainter extends CustomPainter {
  _FallbackGlassPainter({
    required this.radius,
    required this.dark,
    required this.light,
    required this.touch,
    required this.press,
  });

  final double radius;
  final double dark;
  final Offset light;
  final Offset touch;
  final double press;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // Frost.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Color.lerp(
          const Color(0xC7FAFAFC),
          const Color(0x8C2A2A2E),
          dark,
        )!,
    );

    // Touch light.
    if (press > 0) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(touch.dx * 2 - 1, touch.dy * 2 - 1),
            radius: 0.8,
            colors: [
              Colors.white.withValues(alpha: 0.22 * press),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    // Rim: bright where it faces the light, darker edge elsewhere.
    final toward = Alignment(light.dx, light.dy);
    canvas.drawRRect(
      rrect.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: toward,
          end: -toward,
          colors: [
            Colors.white.withValues(alpha: 0.85),
            Colors.white.withValues(alpha: ui.lerpDouble(0.25, 0.10, dark)!),
            Color.lerp(const Color(0x1F000000), const Color(0x33000000), dark)!,
            Colors.white.withValues(alpha: 0.30),
          ],
          stops: const [0, 0.35, 0.75, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_FallbackGlassPainter old) =>
      old.dark != dark ||
      old.light != light ||
      old.touch != touch ||
      old.press != press;
}

/// Reports the global rect it paints at (logical px, transforms included), so
/// a pane moved or scaled by an ancestor knows where it went.
class _PaintRectReporter extends SingleChildRenderObjectWidget {
  const _PaintRectReporter({required this.onRect, super.child});

  final ValueChanged<Rect> onRect;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaintRectReporter(onRect);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPaintRectReporter renderObject,
  ) {
    renderObject.onRect = onRect;
  }
}

class _RenderPaintRectReporter extends RenderProxyBox {
  _RenderPaintRectReporter(this.onRect);

  ValueChanged<Rect> onRect;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (attached && hasSize) {
      onRect(
        MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size),
      );
    }
  }
}
