import 'package:flutter/material.dart';

/// Colour tokens from the ResQ design system (Profile & Records / donor card
/// palette). Kept separate from ResQTheme so the redesigned screens share
/// one exact palette without changing anything that already uses ResQTheme.
class RQColors {
  RQColors._();

  static const Color blood = Color(0xFF9B1B20); // app bar, primary buttons
  static const Color bloodText = Color(0xFF8E1A1E); // red text on white
  static const Color bloodTint = Color(0xFFF8E6E6); // icon boxes, avatar
  static const Color surface = Color(0xFFF2F2F4); // screen background
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1F1F1F);
  static const Color body = Color(0xFF444444);
  static const Color muted = Color(0xFF666666);
  static const Color hairline = Color(0xFFE4E4E7);
  static const Color fieldBorder = Color(0xFFD4D4D8);
  static const Color navy = Color(0xFF1F3A8A);
  static const Color navyTint = Color(0xFFE8ECF7);
  static const Color success = Color(0xFF2E7D32);
  static const Color successTint = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFC2410C);
  static const Color warningTint = Color(0xFFFFF1E0);
  static const Color warningTrack = Color(0xFFF6E7D8);
  static const Color caution = Color(0xFFFFFBE6);
  static const Color cautionBorder = Color(0xFFF3D36B);
}

/// Opens a ResQ-styled bottom sheet. Pair it with [ResQSheet] as the root of
/// [builder] (wrap in a StatefulBuilder when the sheet has its own state).
Future<T?> showResQSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C140A0C),
    builder: builder,
  );
}

/// Shared pop-up layout: drag handle, icon + title + subtitle + close button,
/// a scrollable body and an optional footer that stays pinned at the bottom
/// (so the main action is never pushed off-screen by long content or the
/// keyboard).
class ResQSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final Widget? footer;
  final Color bodyColor;
  final EdgeInsetsGeometry bodyPadding;

  const ResQSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
    this.footer,
    this.bodyColor = RQColors.card,
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 16, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        decoration: const BoxDecoration(
          color: RQColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: RQColors.fieldBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 14),
              child: Row(
                children: [
                  if (icon != null) ...[
                    RQIconBox(icon: icon!, size: 44),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 17, height: 1.4, fontWeight: FontWeight.w600, color: RQColors.ink),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: const TextStyle(fontSize: 12, height: 1.35, color: RQColors.muted),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      backgroundColor: RQColors.surface,
                      fixedSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20, color: RQColors.ink),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: RQColors.hairline),
            Flexible(
              child: ColoredBox(
                color: bodyColor,
                child: SingleChildScrollView(
                  padding: bodyPadding,
                  child: child,
                ),
              ),
            ),
            if (footer != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + (media.viewInsets.bottom > 0 ? 0 : media.padding.bottom)),
                decoration: const BoxDecoration(
                  color: RQColors.card,
                  border: Border(top: BorderSide(color: RQColors.hairline)),
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

/// Rounded square holding an icon — the list-row / header icon style.
class RQIconBox extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color background;
  final Color color;

  const RQIconBox({
    super.key,
    required this.icon,
    this.size = 40,
    this.background = RQColors.bloodTint,
    this.color = RQColors.blood,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Small rounded status label (e.g. TEMPORARILY DEFERRED, Donated, Yes/No).
class RQPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color color;
  final bool dot;
  final bool uppercase;
  final double radius;

  const RQPill({
    super.key,
    required this.label,
    required this.background,
    required this.color,
    this.dot = false,
    this.uppercase = false,
    this.radius = 999,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: uppercase ? 0.6 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey uppercase label above a group of fields ("BASIC INFO", "CONTACT").
class RQSectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const RQSectionLabel(this.text, {super.key, this.color = RQColors.muted});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.7, color: color),
    );
  }
}

/// Primary (filled red) and secondary (outlined) buttons used in sheet
/// footers and cards.
class RQButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;
  final IconData? icon;
  final double height;
  final Color? color;

  const RQButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.loading = false,
    this.icon,
    this.height = 52,
    this.color,
  });

  const RQButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.height = 52,
    this.color,
  }) : primary = false;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? RQColors.blood;
    const textStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final content = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: primary ? Colors.white : accent),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: textStyle)),
            ],
          );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: primary
          ? ElevatedButton(
              onPressed: loading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: accent.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: shape,
              ),
              child: content,
            )
          : OutlinedButton(
              onPressed: loading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: color ?? RQColors.ink,
                side: BorderSide(color: color ?? RQColors.hairline, width: 1.5),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: shape,
              ),
              child: content,
            ),
    );
  }
}

/// Title + subtitle + switch row used inside grouped cards.
class RQToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;

  const RQToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showDivider ? const Border(bottom: BorderSide(color: RQColors.hairline)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: RQColors.ink)),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(fontSize: 12, color: RQColors.muted, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: RQColors.blood,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: RQColors.fieldBorder,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

/// Outlined text field with its label inside the box, as in the redesign.
class RQTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const RQTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      enabled: enabled,
      style: const TextStyle(fontSize: 15, color: RQColors.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: RQColors.muted),
        floatingLabelStyle: const TextStyle(fontSize: 13, color: RQColors.blood, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        suffixIcon: suffix,
        border: border(RQColors.fieldBorder, 1),
        enabledBorder: border(RQColors.fieldBorder, 1),
        focusedBorder: border(RQColors.blood, 2),
        disabledBorder: border(RQColors.hairline, 1),
      ),
    );
  }
}