import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'glass_background.dart';

part 'remove_login_flow.dart';

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
    required this.plus,
    required this.softAvatar,
    required this.softAvatarText,
  });

  final Color page;
  final Color muted; // top bar, icons, «Нэмэх»
  final Color name;
  final Color sub;
  final Color logo;
  final Color photoBorder;
  final Color plus;

  /// Secondary initials avatar (e.g. «НГ»), as in Figma 1936:453 / 1936:627.
  final Color softAvatar;
  final Color softAvatarText;

  // Light-theme greys mapped to white at reduced opacity so they read on black.
  static const dark = _Look(
    page: Colors.black,
    muted: Color(0x99FFFFFF),
    name: Color(0xF2FFFFFF),
    sub: Color(0x8CFFFFFF),
    logo: Colors.white,
    photoBorder: Color(0x29FFFFFF),
    plus: Color(0xD9FFFFFF),
    softAvatar: Color(0x1AFFFFFF),
    softAvatarText: Colors.white,
  );

  // Figma gs 1922:246 as designed.
  static const light = _Look(
    page: Color(0xFFF7F7F7),
    muted: Color(0xFF75808A),
    name: Color(0xFF424242),
    sub: Color(0xFF75808A),
    logo: _brand,
    photoBorder: Color(0xFFE3E3E3),
    plus: Color(0xFF75808A),
    softAvatar: Color(0x1A0054A6),
    softAvatarText: _brand,
  );

  static _Look lerp(_Look a, _Look b, double t) => _Look(
    page: Color.lerp(a.page, b.page, t)!,
    muted: Color.lerp(a.muted, b.muted, t)!,
    name: Color.lerp(a.name, b.name, t)!,
    sub: Color.lerp(a.sub, b.sub, t)!,
    logo: Color.lerp(a.logo, b.logo, t)!,
    photoBorder: Color.lerp(a.photoBorder, b.photoBorder, t)!,
    plus: Color.lerp(a.plus, b.plus, t)!,
    softAvatar: Color.lerp(a.softAvatar, b.softAvatar, t)!,
    softAvatarText: Color.lerp(a.softAvatarText, b.softAvatarText, t)!,
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

  // 0 = two users, 1 = three users (drives the prototype switch thumb).
  late final AnimationController _users = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  bool _threeUsers = false;

  // Per-profile presence (1 = shown); profiles grow in / out of the row.
  late final List<AnimationController> _shown = [
    for (var i = 0; i < _savedProfiles.length; i++)
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
        value: i < 2 ? 1 : 0,
      ),
  ];
  final Set<int> _removed = {};

  // Manage mode («Хэрэглэгч удирдах»): badges + a gentle jiggle.
  bool _managing = false;
  late final AnimationController _manage = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final AnimationController _jiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  // «… хасагдлаа · Буцаах» toast.
  late final AnimationController _toast = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  int? _lastRemoved;
  Timer? _toastTimer;

  final _tileKeys = [for (final _ in _savedProfiles) GlobalKey()];

  // Built once: the screen rebuilds every frame while things animate.
  final _reveals = <double, CurvedAnimation>{};

  @override
  @override
  void dispose() {
    for (final r in _reveals.values) {
      r.dispose();
    }
    for (final c in _shown) {
      c.dispose();
    }
    _toastTimer?.cancel();
    _intro.dispose();
    _version.dispose();
    _users.dispose();
    _manage.dispose();
    _jiggle.dispose();
    _toast.dispose();
    super.dispose();
  }

  bool get _still => MediaQuery.disableAnimationsOf(context);

  bool _included(int i) => i < 2 || _threeUsers;

  int get _visibleCount => [
    for (var i = 0; i < _savedProfiles.length; i++)
      if (_included(i) && !_removed.contains(i)) i,
  ].length;

  void _setLight(bool light) {
    if ((light && _version.value == 1) || (!light && _version.value == 0)) {
      return;
    }
    HapticFeedback.selectionClick();
    light ? _version.forward() : _version.reverse();
  }

  /// Prototype reset: choose 2 or 3 saved users (restores removed ones).
  void _setThree(bool three) {
    HapticFeedback.selectionClick();
    _threeUsers = three;
    three ? _users.forward() : _users.reverse();
    _removed.clear();
    _hideToast();
    _setManaging(false);
    for (var i = 0; i < _shown.length; i++) {
      _shown[i].animateTo(_included(i) ? 1 : 0, curve: Curves.easeInOutCubic);
    }
  }

  void _setManaging(bool on) {
    if (_managing == on) return;
    setState(() => _managing = on);
    if (on) {
      HapticFeedback.mediumImpact();
      _manage.forward();
      if (!_still) _jiggle.repeat();
    } else {
      _manage.reverse();
      _jiggle.stop();
    }
  }

  Future<void> _confirmRemove(int i) async {
    HapticFeedback.selectionClick();
    final t = Curves.easeInOut.transform(_version.value);
    final remove = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _RemoveSheet(
        profile: _savedProfiles[i],
        look: _Look.lerp(_Look.dark, _Look.light, t),
        appearance: t,
      ),
    );
    if (remove == true && mounted) _remove(i);
  }

  void _remove(int i) {
    HapticFeedback.heavyImpact();
    _removed.add(i);
    _shown[i].animateTo(0, curve: Curves.easeInOutCubic);
    _lastRemoved = i;
    _toast.forward(from: 0);
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 4), _hideToast);
    if (_visibleCount == 0) _setManaging(false);
    setState(() {});
  }

  void _undo() {
    final i = _lastRemoved;
    if (i == null) return;
    HapticFeedback.selectionClick();
    _removed.remove(i);
    _shown[i].animateTo(1, curve: Curves.easeInOutCubic);
    _hideToast();
    setState(() {});
  }

  void _hideToast() {
    _toastTimer?.cancel();
    _toast.reverse();
  }

  Future<void> _openMenu(int i, _Look look, double t) async {
    final box = _tileKeys[i].currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    HapticFeedback.mediumImpact();
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final p = _savedProfiles[i];
    final action = await Navigator.of(context).push<_MenuAction>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, _) => _ProfileMenu(
          animation: animation,
          rect: rect,
          appearance: t,
          tile: _ProfileTile(
            look: look,
            name: p.name,
            role: p.role,
            avatar: _avatarFor(p, look),
            onTap: () {},
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == _MenuAction.remove) _confirmRemove(i);
    if (action == _MenuAction.login) _select(p.name);
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

  Widget _profilesRow(_Look look, double t) {
    final m = _manage.value;
    final vs = [for (final c in _shown) c.value];
    final total = vs.fold(0.0, (a, b) => a + b);
    final gap = 24 - 8 * (total - 2).clamp(0.0, 1.0);
    final red = Color.lerp(_redDark, _redLight, t)!;
    final children = <Widget>[];
    var before = 0.0;
    for (var i = 0; i < _savedProfiles.length; i++) {
      final v = vs[i];
      if (v <= 0) continue;
      final p = _savedProfiles[i];
      final wiggle = _managing && !_still
          ? math.sin((_jiggle.value + i * 0.37) * 2 * math.pi) * 0.026 * m
          : 0.0;
      Widget tile = _ProfileTile(
        key: _tileKeys[i],
        look: look,
        name: p.name,
        role: p.role,
        avatar: Transform.rotate(
          angle: wiggle,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _avatarFor(p, look),
              if (m > 0)
                Positioned(
                  left: -1,
                  top: -1,
                  child: _RemoveBadge(progress: m, color: red),
                ),
            ],
          ),
        ),
        onTap: _managing ? () => _confirmRemove(i) : () => _select(p.name),
        onLongPress: _managing ? null : () => _openMenu(i, look, t),
      );
      tile = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: gap * before.clamp(0.0, 1.0)),
          tile,
        ],
      );
      if (v < 1) {
        tile = ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: Opacity(
              opacity: v,
              child: Transform.scale(scale: 0.85 + 0.15 * v, child: tile),
            ),
          ),
        );
      }
      children.add(_reveal(0.2 + 0.08 * i, tile));
      before += v;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _actions(_Look look, double t) {
    final Widget child;
    if (_managing) {
      child = Column(
        key: const ValueKey('manage'),
        children: [
          Text(
            'Энэ төхөөрөмжөөс хасах хэрэглэгчээ сонгоно уу',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 20 / 13,
              fontWeight: FontWeight.w500,
              color: look.muted,
            ),
          ),
          const SizedBox(height: 16),
          _Pressable(
            onTap: () => _setManaging(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              decoration: BoxDecoration(
                color: Color.lerp(Colors.white, _brand, t),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Болсон',
                style: TextStyle(
                  fontSize: 14,
                  height: 20 / 14,
                  fontWeight: FontWeight.w600,
                  color: Color.lerp(Colors.black, Colors.white, t),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      child = Column(
        key: const ValueKey('login'),
        children: [
          _TextLink(
            look,
            'Өөр хэрэглэгчээр нэвтрэх',
            onTap: () => _select('other'),
          ),
          if (_visibleCount > 0)
            _TextLink(
              look,
              'Хэрэглэгч удирдах',
              onTap: () => _setManaging(true),
            ),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _version,
        _users,
        _manage,
        _jiggle,
        _toast,
        ..._shown,
      ]),
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_version.value);
        final u = Curves.easeInOutCubic.transform(_users.value);
        final look = _Look.lerp(_Look.dark, _Look.light, t);
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final toastA = Curves.easeOutCubic.transform(_toast.value);
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
                      _profilesRow(look, t),
                      const SizedBox(height: 28),
                      _reveal(0.4, _actions(look, t)),
                    ],
                  ),
                ),
                if (_toast.value > 0 && _lastRemoved != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: bottomInset + 16 + 50 + 12 - 12 * (1 - toastA),
                    child: Opacity(
                      opacity: toastA,
                      child: _RemovedToast(
                        name: _savedProfiles[_lastRemoved!].name,
                        appearance: t,
                        onUndo: _undo,
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomInset + 16,
                  child: Center(
                    child: _reveal(
                      0.5,
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Segmented(
                            appearance: t,
                            position: t,
                            segmentWidth: 96,
                            segments: const [
                              ('Dark', Icons.dark_mode_rounded),
                              ('Light', Icons.light_mode_rounded),
                            ],
                            onSelect: (i) => _setLight(i == 1),
                          ),
                          const SizedBox(width: 8),
                          _Segmented(
                            appearance: t,
                            position: u,
                            segmentWidth: 56,
                            segments: const [
                              ('2', Icons.person_rounded),
                              ('3', Icons.group_rounded),
                            ],
                            onSelect: (i) => _setThree(i == 1),
                          ),
                        ],
                      ),
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
    // Help (?) replaces «Тусламж ···»; the flag replaces «English ›» and shows
    // the language you can switch to (US flag on these Mongolian screens).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Pressable(
            onTap: () => HapticFeedback.selectionClick(),
            child: Semantics(
              label: 'Тусламж',
              button: true,
              child: _Icon('assets/icons/help.svg', 24, 24, look.muted),
            ),
          ),
          _Pressable(
            onTap: () => HapticFeedback.selectionClick(),
            child: Semantics(
              label: 'English',
              button: true,
              child: const _Flag('assets/flags/en.svg'),
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
    super.key,
    required this.look,
    required this.name,
    required this.role,
    required this.avatar,
    required this.onTap,
    this.onLongPress,
  });

  final _Look look;
  final String name;
  final String role;
  final Widget avatar;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
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
  const _PhotoAvatar(this.asset, this.border, {this.size = 78});

  final String asset;
  final Color border;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar(
    this.initials, {
    required this.background,
    required this.foreground,
    this.size = 78,
  });

  final String initials;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 19 / 78,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

/// Text link in the style of Figma 1943:1086 («Өөр хэрэглэгчээр нэвтрэх»):
/// SemiBold 13/20, muted, centred in a 36pt-tall box.
class _TextLink extends StatelessWidget {
  const _TextLink(this.look, this.label, {required this.onTap});

  final _Look look;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            height: 20 / 13,
            fontWeight: FontWeight.w600,
            color: look.muted,
          ),
        ),
      ),
    );
  }
}

/// Prototype control: a pill of segments with a sliding thumb (Dark/Light,
/// and 2/3 users). Colours follow [appearance]; the thumb follows [position].
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.appearance,
    required this.position,
    required this.segmentWidth,
    required this.segments,
    required this.onSelect,
  });

  /// 0 = dark styling, 1 = light (animated in between).
  final double appearance;

  /// Thumb position: 0 = first segment, 1 = second (animated in between).
  final double position;
  final double segmentWidth;
  final List<(String, IconData)> segments;
  final ValueChanged<int> onSelect;

  static const _segH = 40.0;

  @override
  Widget build(BuildContext context) {
    final t = appearance;
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

    Widget segment(int i) {
      final (label, icon) = segments[i];
      final sel = i == 1 ? position : 1 - position;
      final color = Color.lerp(unselected, selected, sel)!;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(i),
        child: SizedBox(
          width: segmentWidth,
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
            left: segmentWidth * position,
            top: 0,
            width: segmentWidth,
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
            children: [segment(0), segment(1)],
          ),
        ],
      ),
    );
  }
}

/// Language flag as supplied by the designer (28×22 box, art kept as-is).
class _Flag extends StatelessWidget {
  const _Flag(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(asset, width: 28, height: 22);
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
  const _Pressable({
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

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
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _set(false);
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
