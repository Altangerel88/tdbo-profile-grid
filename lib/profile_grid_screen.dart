import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'glass_background.dart';

// Figma: gs · «A · Netflix — Profile grid» (1922:246), restyled for the dark
// animated background. Sizes and spacing follow the frame; light-theme greys
// are mapped to white at reduced opacity so they read on black.
const _muted = Color(0x99FFFFFF); // #75808A on light
const _name = Color(0xF2FFFFFF); // #424242 on light
const _sub = Color(0x8CFFFFFF); // #75808A on light
const _brand = Color(0xFF0054A6);

class ProfileGridScreen extends StatefulWidget {
  const ProfileGridScreen({super.key});

  @override
  State<ProfileGridScreen> createState() => _ProfileGridScreenState();
}

class _ProfileGridScreenState extends State<ProfileGridScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Widget _reveal(double start, Widget child) {
    final curve = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(curve),
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Positioned.fill(child: GlassBackground()),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _reveal(0.0, const _TopBar()),
                  const SizedBox(height: 36),
                  _reveal(0.05, const _TdbLogo()),
                  const SizedBox(height: 100),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _reveal(
                        0.2,
                        _ProfileTile(
                          name: 'Алтангэрэл',
                          role: 'Иргэн',
                          avatar: const _PhotoAvatar('assets/images/avatar.jpg'),
                          onTap: () => _select('Алтангэрэл'),
                        ),
                      ),
                      const SizedBox(width: 24),
                      _reveal(
                        0.28,
                        _ProfileTile(
                          name: 'Эрдэнэ Трейд',
                          role: 'Байгууллага',
                          avatar: const _InitialsAvatar('ЭТ'),
                          onTap: () => _select('Эрдэнэ Трейд'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _reveal(0.4, _AddTile(onTap: () => _select('add'))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  static const _style = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
    color: _muted,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Pressable(
            onTap: () => HapticFeedback.selectionClick(),
            child: const Row(
              children: [
                Text('Тусламж', style: _style),
                SizedBox(width: 4),
                _Icon('assets/icons/dots_three.svg', 24, 24, _muted),
              ],
            ),
          ),
          _Pressable(
            onTap: () => HapticFeedback.selectionClick(),
            child: const Row(
              children: [
                Text('English', style: _style),
                _Icon('assets/icons/chevron_right.svg', 24, 24, _muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// TDB logo (Figma 1922:265): five vector groups placed in a 120×48 box,
/// tinted white for the dark background.
class _TdbLogo extends StatelessWidget {
  const _TdbLogo();

  static Widget _part(String file, double l, double t, double w, double h) =>
      Positioned(
        left: l,
        top: t,
        child: _Icon('assets/icons/$file.svg', w, h, Colors.white),
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
    required this.name,
    required this.role,
    required this.avatar,
    required this.onTap,
  });

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
            style: const TextStyle(
              fontSize: 15,
              height: 22 / 15,
              fontWeight: FontWeight.w700,
              color: _name,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            role,
            style: const TextStyle(
              fontSize: 12,
              height: 16 / 12,
              fontWeight: FontWeight.w500,
              color: _sub,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoAvatar extends StatelessWidget {
  const _PhotoAvatar(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x29FFFFFF), width: 1.04),
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
  const _AddTile({required this.onTap});

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
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: const _Icon(
                'assets/icons/plus.svg', 24, 24, Color(0xD9FFFFFF)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Нэмэх',
            style: TextStyle(
              fontSize: 13,
              height: 20 / 13,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
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
