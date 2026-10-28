part of 'profile_grid_screen.dart';

/// «Өөр хэрэглэгчээр нэвтрэх» → username / password login (Figma gs 1953:1679),
/// with a back chevron and the Dark/Light switch.
/// Same top bar, logo and animated background as the profile grid; the
/// background shares its clock, so it carries on without a jump.
class _PasswordLoginScreen extends StatefulWidget {
  const _PasswordLoginScreen({
    required this.initialLight,
    required this.onThemeChanged,
  });

  /// The look the profile screen was in when this was opened.
  final bool initialLight;

  /// Keeps the profile screen's look in step with the switch here.
  final ValueChanged<bool> onThemeChanged;

  @override
  State<_PasswordLoginScreen> createState() => _PasswordLoginScreenState();
}

class _PasswordLoginScreenState extends State<_PasswordLoginScreen>
    with SingleTickerProviderStateMixin {
  final _user = TextEditingController();
  final _pass = TextEditingController();

  // 0 = dark, 1 = light.
  late final AnimationController _theme = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: widget.initialLight ? 1 : 0,
  );

  void _setLight(bool light) {
    if ((light && _theme.value == 1) || (!light && _theme.value == 0)) return;
    HapticFeedback.selectionClick();
    light ? _theme.forward() : _theme.reverse();
    widget.onThemeChanged(light);
  }

  @override
  void initState() {
    super.initState();
    _user.addListener(_changed);
    _pass.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _theme.dispose();
    super.dispose();
  }

  bool get _ready => _user.text.trim().isNotEmpty && _pass.text.isNotEmpty;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Өглөөний мэнд!';
    if (h >= 12 && h < 18) return 'Өдрийн мэнд!';
    return 'Оройн мэнд!';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _theme, builder: _build);
  }

  Widget _build(BuildContext context, Widget? _) {
    final t = Curves.easeInOut.transform(_theme.value);
    final look = _Look.lerp(_Look.dark, _Look.light, t);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final ink = Color.lerp(Colors.white, const Color(0xFF242424), t)!;
    final link = Color.lerp(const Color(0xFF80A9D2), _brand, t)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: t < 0.5 ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: look.page,
        body: Stack(
          fit: StackFit.expand,
          children: [
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
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  children: [
                    _TopBar(
                      look,
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 32),
                    _TdbLogo(look.logo),
                    const SizedBox(height: 32),
                    Text(
                      _greeting,
                      style: TextStyle(
                        fontSize: 16,
                        height: 24 / 16,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 44),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _LoginField(
                            controller: _user,
                            hint: 'Нэвтрэх нэр',
                            appearance: t,
                            action: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          _LoginField(
                            controller: _pass,
                            hint: 'Нууц үг',
                            appearance: t,
                            obscure: true,
                            action: TextInputAction.done,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _Pressable(
                              onTap: () => HapticFeedback.selectionClick(),
                              child: SizedBox(
                                height: 30,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: 1,
                                  child: Text(
                                    'Нэвтэрч чадахгүй байна уу?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: link,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 44),
                          _LoginButton(
                            label: 'Нэвтрэх',
                            fill: _ready
                                ? _brand
                                : Color.lerp(
                                    const Color(0x14FFFFFF),
                                    const Color(0xFFE1E1E1),
                                    t,
                                  )!,
                            color: _ready
                                ? Colors.white
                                : Color.lerp(
                                    const Color(0x66FFFFFF),
                                    const Color(0xFF75808A),
                                    t,
                                  )!,
                            onTap: _ready
                                ? () {
                                    HapticFeedback.selectionClick();
                                    FocusScope.of(context).unfocus();
                                    debugPrint('login: ${_user.text}');
                                  }
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _LoginButton(
                            label: 'Бүртгүүлэх/Идэвхжүүлэх',
                            fill: Color.lerp(
                              const Color(0x00FFFFFF),
                              Colors.white,
                              t,
                            )!,
                            border: Color.lerp(
                              const Color(0x33FFFFFF),
                              const Color(0xFFE3E3E3),
                              t,
                            ),
                            color: Color.lerp(Colors.white, _brand, t)!,
                            onTap: () => HapticFeedback.selectionClick(),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 16,
              child: IgnorePointer(
                ignoring: keyboard,
                child: AnimatedOpacity(
                  opacity: keyboard ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Center(
                    child: _Segmented(
                      appearance: t,
                      position: t,
                      segmentWidth: 96,
                      segments: const [
                        ('Dark', Icons.dark_mode_rounded),
                        ('Light', Icons.light_mode_rounded),
                      ],
                      onSelect: (i) => _setLight(i == 1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 68pt white field, radius 16, SemiBold 16 hint in #75808A (Figma Input).
class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.hint,
    required this.appearance,
    required this.action,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String hint;
  final double appearance;
  final TextInputAction action;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    final t = appearance;
    final style = TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
      color: Color.lerp(Colors.white, const Color(0xFF242424), t),
    );
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Color.lerp(const Color(0x14FFFFFF), Colors.white, t),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color.lerp(
            const Color(0x1FFFFFFF),
            const Color(0x00FFFFFF),
            t,
          )!,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        textInputAction: action,
        autocorrect: false,
        enableSuggestions: !obscure,
        cursorColor: Color.lerp(Colors.white, _brand, t),
        style: style,
        decoration: InputDecoration.collapsed(
          hintText: hint,
          hintStyle: style.copyWith(
            color: Color.lerp(
              const Color(0x80FFFFFF),
              const Color(0xFF75808A),
              t,
            ),
          ),
        ),
      ),
    );
  }
}

/// 50pt button, radius 16, SemiBold 14 (Figma buttons/standard).
class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.label,
    required this.fill,
    required this.color,
    required this.onTap,
    this.border,
  });

  final String label;
  final Color fill;
  final Color color;
  final Color? border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
    final tap = onTap;
    return tap == null ? box : _Pressable(onTap: tap, child: box);
  }
}
