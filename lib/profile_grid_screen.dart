import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'glass_background.dart';

const _brand = Color(0xFF0054A6);

/// Colours for one version of the screen. [dark] is the animated-glass
/// restyle; [light] is the Figma frame's own palette.
class _Look {
  const _Look({
    required this.page,
    required this.muted,
    required this.name,
    required this.sub,
    required this.logo,
    required this.photoBorder,
    required this.tile,
    required this.tileBorder,
    required this.plus,
  });

  final Color page;
  final Color muted; // top bar, icons, «Нэмэх»
  final Color name;
  final Color sub;
  final Color logo;
  final Color photoBorder;
  final Color tile;
  final Color tileBorder;
  final Color plus;

  // Light-theme greys mapped to white at reduced opacity so they read on black.
  static const dark = _Look(
    page: Colors.black,
    muted: Color(0x99FFFFFF),
    name: Color(0xF2FFFFFF),
    sub: Color(0x8CFFFFFF),
    logo: Colors.white,
    photoBorder: Color(0x29FFFFFF),
    tile: Color(0x14FFFFFF),
    tileBorder: Color(0x1FFFFFFF),
    plus: Color(0xD9FFFFFF),
  );

  // Figma gs 1922:246 as designed.
  static const light = _Look(
    page: Color(0xFFF7F7F7),
    muted: Color(0xFF75808A),
    name: Color(0xFF424242),
    sub: Color(0xFF75808A),
    logo: _brand,
    photoBorder: Color(0xFFE3E3E3),
    tile: Colors.white,
    tileBorder: Color(0x00FFFFFF),
    plus: Color(0xFF75808A),
  );

  static _Look lerp(_Look a, _Look b, double t) => _Look(
    page: Color.lerp(a.page, b.page, t)!,
    muted: Color.lerp(a.muted, b.muted, t)!,
    name: Color.lerp(a.name, b.name, t)!,
    sub: Color.lerp(a.sub, b.sub, t)!,
    logo: Color.lerp(a.logo, b.logo, t)!,
    photoBorder: Color.lerp(a.photoBorder, b.photoBorder, t)!,
    tile: Color.lerp(a.tile, b.tile, t)!,
    tileBorder: Color.lerp(a.tileBorder, b.tileBorder, t)!,
    plus: Color.lerp(a.plus, b.plus, t)!,
  );
}

// Figma: gs · «A · Netflix — Profile grid» (1922:246). Sizes and spacing follow
// the frame in both versions.
class ProfileGridScreen extends StatefulWidget {
  const ProfileGridScreen({super.key});

  @override
  State<ProfileGridScreen> createState() => _ProfileGridScreenState();
}

class _ProfileGridScreenState extends State<ProfileGridScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  // 0 = dark, 1 = light.
  late final AnimationController _version = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  // Built once: the screen rebuilds every frame while the version crossfades.
  final _reveals = <double, CurvedAnimation>{};

  @override
  void dispose() {
    for (final r in _reveals.values) {
      r.dispose();
    }
    _intro.dispose();
    _version.dispose();
    super.dispose();
  }

  void _setLight(bool light) {
    if ((light && _version.value == 1) || (!light && _version.value == 0)) {
      return;
    }
    HapticFeedback.selectionClick();
    light ? _version.forward() : _version.reverse();
  }

  Widget _reveal(double start, Widget child) {
    final curve = _reveals.putIfAbsent(
      start,
      () => CurvedAnimation(
        parent: _intro,
        curve: Interval(
          start,
          (start + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }

  void _select(String who) {
    HapticFeedback.selectionClick();
    debugPrint('profile: $who');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _version,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_version.value);
        final look = _Look.lerp(_Look.dark, _Look.light, t);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: t < 0.5
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: look.page,
            body: Stack(
              children: [
                // Only the visible background(s) run; both run mid-crossfade.
                if (t < 1)
                  const Positioned.fill(
                    key: ValueKey('bg-dark'),
                    child: GlassBackground(),
                  ),
                if (t > 0)
                  Positioned.fill(
                    key: const ValueKey('bg-light'),
                    child: Opacity(
                      opacity: t,
                      child: const GlassBackground.light(),
                    ),
                  ),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _reveal(0.0, _TopBar(look)),
                      const SizedBox(height: 36),
                      _reveal(0.05, _TdbLogo(look.logo)),
                      const SizedBox(height: 100),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _reveal(
                            0.2,
                            _ProfileTile(
                              look: look,
                              name: 'Алтангэрэл',
                              role: 'Иргэн',
                              avatar: _PhotoAvatar(
                                'assets/images/avatar.jpg',
                                look.photoBorder,
                              ),
                              onTap: () => _select('Алтангэрэл'),
                            ),
                          ),
                          const SizedBox(width: 24),
                          _reveal(
                            0.28,
                            _ProfileTile(
                              look: look,
                              name: 'Эрдэнэ Трейд',
                              role: 'Байгууллага',
                              avatar: const _InitialsAvatar('ЭТ'),
                              onTap: () => _select('Эрдэнэ Трейд'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _reveal(0.4, _AddTile(look, onTap: () => _select('add'))),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.paddingOf(context).bottom + 16,
                  child: Center(
                    child: _reveal(
                      0.5,
                      _VersionSwitch(t: t, onChanged: _setLight),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar(this.look);

  final _Look look;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w700,
      color: look.muted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Pressable(
            onTap: () => HapticFeedback.selectionClick(),
            child: Row(
              children: [
                Text('Тусламж', style: style),
                const SizedBox(width: 4),
                _Icon('assets/icons/dots_three.svg', 24, 24, look.muted),
              ],
            ),
          ),
          _Pressable(
            onTap: () => HapticFeedback.selectionClick(),
            child: Row(
              children: [
                Text('English', style: style),
                _Icon('assets/icons/chevron_right.svg', 24, 24, look.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// TDB logo (Figma 1922:265): five vector groups placed in a 120×48 box,
/// tinted [color] (white on dark, the source #0054A6 on light).
class _TdbLogo extends StatelessWidget {
  const _TdbLogo(this.color);

  final Color color;

  Widget _part(String file, double l, double t, double w, double h) =>
      Positioned(
        left: l,
        top: t,
        child: _Icon('assets/icons/$file.svg', w, h, color),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 48,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          _part('logo_line1', 1.61, 38.78, 43.517, 7.00898),
          _part('logo_line2', 48, 37.37, 45.4837, 7.28779),
          _part('logo_line3', 97.6, 38.78, 20.79, 5.71898),
          _part('logo_tdb', 36.07, 3.42, 82.3258, 28.9572),
          _part('logo_mark', 1.67, 2.22, 31.197, 31.1995),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.look,
    required this.name,
    required this.role,
    required this.avatar,
    required this.onTap,
  });

  final _Look look;
  final String name;
  final String role;
  final Widget avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Column(
        children: [
          avatar,
          const SizedBox(height: 10),
          Text(
            name,
            style: TextStyle(
              fontSize: 15,
              height: 22 / 15,
              fontWeight: FontWeight.w700,
              color: look.name,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            role,
            style: TextStyle(
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w500,
              color: look.sub,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoAvatar extends StatelessWidget {
  const _PhotoAvatar(this.asset, this.border);

  final String asset;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.04),
      ),
      child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar(this.initials);

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _brand, shape: BoxShape.circle),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile(this.look, {required this.onTap});

  final _Look look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: look.tile,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: look.tileBorder),
            ),
            child: _Icon('assets/icons/plus.svg', 24, 24, look.plus),
          ),
          const SizedBox(height: 8),
          Text(
            'Нэмэх',
            style: TextStyle(
              fontSize: 13,
              height: 20 / 13,
              fontWeight: FontWeight.w600,
              color: look.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Prototype control: switches between the dark and light versions.
class _VersionSwitch extends StatelessWidget {
  const _VersionSwitch({required this.t, required this.onChanged});

  /// 0 = dark selected, 1 = light selected (animated in between).
  final double t;
  final ValueChanged<bool> onChanged;

  static const _segW = 96.0;
  static const _segH = 40.0;

  @override
  Widget build(BuildContext context) {
    final track = Color.lerp(const Color(0x1AFFFFFF), Colors.white, t)!;
    final border = Color.lerp(
      const Color(0x24FFFFFF),
      const Color(0xFFE3E3E3),
      t,
    )!;
    final thumb = Color.lerp(Colors.white, _brand, t)!;
    final selected = Color.lerp(Colors.black, Colors.white, t)!;
    final unselected = Color.lerp(
      const Color(0xB3FFFFFF),
      const Color(0xFF75808A),
      t,
    )!;

    Widget segment(String label, IconData icon, bool light) {
      final sel = light ? t : 1 - t;
      final color = Color.lerp(unselected, selected, sel)!;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(light),
        child: SizedBox(
          width: _segW,
          height: _segH,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(
              const Color(0x00000000),
              const Color(0x14242424),
              t,
            )!,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: _segW * t,
            top: 0,
            width: _segW,
            height: _segH,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: thumb,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              segment('Dark', Icons.dark_mode_rounded, false),
              segment('Light', Icons.light_mode_rounded, true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon(this.asset, this.width, this.height, this.color);

  final String asset;
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

/// Scales down slightly while pressed.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
