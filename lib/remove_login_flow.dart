part of 'profile_grid_screen.dart';

// Delete-saved-login flow (Figma gs section 1955:816):
//   press & hold a profile → manage mode (− badges, jiggle) → tap a profile →
//   confirm sheet «Хасах» → profile leaves, toast with «Буцаах» (undo).
//   «Болсон» or a tap on empty space leaves manage mode.

const _redDark = Color(0xFFFF453A); // iOS system red, dark
const _redLight = Color(0xFFFF3B30); // iOS system red, light
const _okGreen = Color(0xFF30D158);

enum _AvatarKind { photo, brand, soft }

class _Profile {
  const _Profile(this.name, this.role, this.kind, [this.initials = '']);

  final String name;
  final String role;
  final _AvatarKind kind;
  final String initials;
}

const _savedProfiles = [
  _Profile('Алтангэрэл', 'Иргэн', _AvatarKind.photo),
  _Profile('Эрдэнэ Трейд', 'Байгууллага', _AvatarKind.brand, 'ЭТ'),
  _Profile('Номин Групп', 'Байгууллага', _AvatarKind.soft, 'НГ'),
];

Widget _avatarFor(_Profile p, _Look look, {double size = 78}) {
  switch (p.kind) {
    case _AvatarKind.photo:
      return _PhotoAvatar(
        'assets/images/avatar.jpg',
        look.photoBorder,
        size: size,
      );
    case _AvatarKind.brand:
      return _InitialsAvatar(
        p.initials,
        background: _brand,
        foreground: Colors.white,
        size: size,
      );
    case _AvatarKind.soft:
      return _InitialsAvatar(
        p.initials,
        background: look.softAvatar,
        foreground: look.softAvatarText,
        size: size,
      );
  }
}

/// Red «−» badge pinned to an avatar's top-left in manage mode.
class _RemoveBadge extends StatelessWidget {
  const _RemoveBadge({required this.progress, required this.color});

  /// 0 = hidden, 1 = shown (pops in with a slight overshoot).
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = Curves.easeOutBack.transform(progress.clamp(0.0, 1.0));
    return Transform.scale(
      scale: s,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Container(
          width: 10,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

/// Confirmation sheet: «{name}-ийг хасах уу?» with «Хасах» / «Болих».
class _RemoveSheet extends StatelessWidget {
  const _RemoveSheet({
    required this.profile,
    required this.look,
    required this.appearance,
  });

  final _Profile profile;
  final _Look look;

  /// 0 = dark, 1 = light.
  final double appearance;

  @override
  Widget build(BuildContext context) {
    final t = appearance;
    final bg = Color.lerp(const Color(0xFF1C1C1E), Colors.white, t)!;
    final title = Color.lerp(Colors.white, const Color(0xFF242424), t)!;
    final body = Color.lerp(
      const Color(0x99FFFFFF),
      const Color(0xFF75808A),
      t,
    )!;
    final red = Color.lerp(_redDark, _redLight, t)!;
    final cancelBg = Color.lerp(
      const Color(0x1AFFFFFF),
      const Color(0x0F242424),
      t,
    )!;
    final bottom = MediaQuery.paddingOf(context).bottom;

    Widget button(String label, Color fill, Color fg, bool result) {
      return _Pressable(
        onTap: () => Navigator.of(context).pop(result),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottom + 24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: title.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 16),
          _avatarFor(profile, look, size: 64),
          const SizedBox(height: 16),
          Text(
            // U+2060 keeps the suffix glued to the name when wrapping.
            '${profile.name}-⁠ийг хасах уу?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              height: 28 / 20,
              fontWeight: FontWeight.w700,
              color: title,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нэвтрэх мэдээлэл зөвхөн энэ төхөөрөмжөөс устна. Таны данс, '
            'гүйлгээнд нөлөөлөхгүй — дараа нь нэвтрэх нэр, нууц үгээрээ '
            'дахин нэвтэрч болно.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 20 / 14,
              fontWeight: FontWeight.w500,
              color: body,
            ),
          ),
          const SizedBox(height: 24),
          button('Хасах', red, Colors.white, true),
          const SizedBox(height: 10),
          button('Болих', cancelBg, title, false),
        ],
      ),
    );
  }
}

/// «{name} хасагдлаа» with «Буцаах» (undo).
class _RemovedToast extends StatelessWidget {
  const _RemovedToast({
    required this.name,
    required this.appearance,
    required this.onUndo,
  });

  final String name;
  final double appearance;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final t = appearance;
    final bg = Color.lerp(const Color(0xF52C2C2E), Colors.white, t)!;
    final fg = Color.lerp(Colors.white, const Color(0xFF242424), t)!;
    final undoBg = Color.lerp(
      const Color(0x1FFFFFFF),
      const Color(0x1A0054A6),
      t,
    )!;
    final undoFg = Color.lerp(Colors.white, _brand, t)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(
              const Color(0x00000000),
              const Color(0x1A242424),
              t,
            )!,
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 20, color: _okGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$name хасагдлаа',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ),
          _Pressable(
            onTap: onUndo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: undoBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Буцаах',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: undoFg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
