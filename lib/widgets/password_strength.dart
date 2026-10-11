import 'package:flutter/material.dart';
import 'package:resq/widgets/resq_ui.dart';

/// Strength bar + checklist (8+ characters, uppercase, number, symbol)
/// shown under a "New password" field. Shared by Settings' change-password
/// sheet and the Forgot Password screen so both give the same guidance.
/// Only the length is a hard requirement (the backend's
/// MIN_PASSWORD_LENGTH); the other three are suggestions.
class PasswordStrengthHints extends StatelessWidget {
  final String password;

  const PasswordStrengthHints({super.key, required this.password});

  static bool meetsMinLength(String password) => password.length >= 8;

  @override
  Widget build(BuildContext context) {
    final pw = password;
    final bool hasLen = meetsMinLength(pw);
    final bool hasUpper = pw.contains(RegExp(r'[A-Z]'));
    final bool hasNum = pw.contains(RegExp(r'[0-9]'));
    final bool hasSym = pw.contains(RegExp(r'[^A-Za-z0-9]'));
    final int score = [hasLen, hasUpper, hasNum, hasSym].where((b) => b).length;

    const labels = ['Too weak', 'Weak', 'Fair', 'Good', 'Strong'];
    final Color strengthColor = score >= 3
        ? RQColors.success
        : score == 2
            ? RQColors.warning
            : const Color(0xFFB91C1C);

    Widget rule(bool ok, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.check_rounded : Icons.circle_outlined,
                size: 15, color: ok ? RQColors.success : const Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text, style: TextStyle(fontSize: 12, color: ok ? RQColors.ink : RQColors.muted)),
            ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pw.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < score ? strengthColor : RQColors.hairline,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Text(labels[score], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: strengthColor)),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: rule(hasLen, '8+ characters')),
            Expanded(child: rule(hasUpper, 'Uppercase letter')),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: rule(hasNum, 'A number')),
            Expanded(child: rule(hasSym, 'A symbol (!@#)')),
          ],
        ),
      ],
    );
  }
}
