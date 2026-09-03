import 'package:flutter/material.dart';

/// Lightweight responsive helpers so screens designed for phone width
/// (~390px, matching the Figma mockups) don't stretch or look
/// disproportionate on larger devices (tablets like the SM P615, foldables,
/// etc.). Intentionally simple — no external package dependency.
class Responsive {
  Responsive._();

  /// Reference width our layouts were designed against (iPhone 12/13 class).
  static const double _baseWidth = 390.0;

  /// Anything at or above this width is treated as a tablet.
  static const double tabletBreakpoint = 600.0;

  /// The widest a single-column form/content area is allowed to get.
  /// Prevents text fields, cards, and buttons from stretching edge-to-edge
  /// on tablets — content stays centered at a comfortable reading width
  /// instead of scaling up awkwardly.
  static const double maxContentWidth = 480.0;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= tabletBreakpoint;

  /// Scale factor for font/icon sizes, clamped so tablets don't blow text
  /// up 2-3x just because the screen is physically wider.
  static double scale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final raw = width / _baseWidth;
    return raw.clamp(0.9, 1.15);
  }

  /// Scaled font size helper: Responsive.sp(context, 14)
  static double sp(BuildContext context, double size) => size * scale(context);

  /// Horizontal padding that grows slightly on wider screens instead of
  /// staying pinned at a phone-sized 20px on a 10" tablet.
  static double horizontalPadding(BuildContext context) {
    return isTablet(context) ? 40 : 20;
  }

  /// Grid columns for things like the blood-type picker — a few more
  /// columns fit comfortably once there's real width to work with.
  static int gridColumns(BuildContext context, {int phoneColumns = 4, int tabletColumns = 6}) {
    return isTablet(context) ? tabletColumns : phoneColumns;
  }
}

/// Wrap any scrollable screen body's content in this so it centers and
/// caps width on tablets instead of stretching every card/button
/// edge-to-edge across a 10" screen. Usage:
///
/// ```dart
/// SingleChildScrollView(
///   child: ResponsiveContentArea(
///     child: Column(children: [...]),
///   ),
/// )
/// ```
class ResponsiveContentArea extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveContentArea({
    super.key,
    required this.child,
    this.maxWidth = Responsive.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}