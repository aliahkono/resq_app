import 'package:flutter/material.dart';
import 'package:resq/utils/constants/theme_constants.dart';

class CustomInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String labelText;
  final IconData? icon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool readOnly;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final int maxLines;

  const CustomInputField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.labelText,
    this.icon,
    this.suffixIcon,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onTap,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText.isNotEmpty) ...[
          Text(
            labelText,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: ResQTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onTap: onTap,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E1E1E)),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
            prefixIcon: icon != null
                ? Icon(icon, color: const Color(0xFF9B1B20), size: 20)
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: readOnly ? const Color(0xFFF9FAFB) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF9B1B20), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF9B1B20), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF9B1B20), width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
            ),
          ),
        ),
      ],
    );
  }
}