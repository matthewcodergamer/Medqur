import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared responsive policy for Medqur.
///
/// The UI is intentionally content-led and restrained: phone layouts stack
/// before controls become cramped, tablet layouts use small grids, and desktop
/// layouts gain breathing room without stretching clinical content edge to edge.
abstract final class MedqurResponsive {
  static const double tiny = 360;
  static const double phone = 600;
  static const double tablet = 900;
  static const double desktop = 1180;
  static const double wide = 1440;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isTiny(BuildContext context) => width(context) < tiny;
  static bool isPhone(BuildContext context) => width(context) < phone;
  static bool isTablet(BuildContext context) =>
      width(context) >= phone && width(context) < desktop;
  static bool isDesktop(BuildContext context) => width(context) >= desktop;

  static double horizontalPagePadding(BuildContext context) {
    final value = width(context);
    if (value < 360) return 12;
    if (value < 600) return 16;
    if (value < 900) return 22;
    if (value < 1180) return 26;
    return 32;
  }

  static double verticalPagePadding(BuildContext context) {
    final value = width(context);
    if (value < 360) return 14;
    if (value < 600) return 18;
    if (value < 900) return 22;
    return 26;
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final horizontal = horizontalPagePadding(context);
    final vertical = verticalPagePadding(context);
    return EdgeInsets.fromLTRB(
      horizontal,
      vertical,
      horizontal,
      vertical + 12,
    );
  }

  /// Caps line length on large desktop displays while still allowing worklists
  /// and dashboards to use more horizontal space than forms.
  static double contentMax(BuildContext context, {bool wide = false}) {
    final viewport = width(context);
    final desired = wide ? 1180.0 : 960.0;
    return math.min(viewport, desired);
  }
}

/// Two or more form fields that become a vertical stack before text, menus or
/// touch targets are squeezed.
class ResponsiveFields extends StatelessWidget {
  const ResponsiveFields({
    super.key,
    required this.children,
    this.gap = 10,
    this.minFieldWidth = 180,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<Widget> children;
  final double gap;
  final double minFieldWidth;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = (children.length * minFieldWidth) +
            ((children.length - 1) * gap);
        final stack = constraints.maxWidth < needed;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) SizedBox(height: gap),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1) SizedBox(width: gap),
            ],
          ],
        );
      },
    );
  }
}

/// Button/actions row that wraps into full-width controls on narrow phones.
class ResponsiveActions extends StatelessWidget {
  const ResponsiveActions({
    super.key,
    required this.children,
    this.gap = 8,
    this.minActionWidth = 150,
  });

  final List<Widget> children;
  final double gap;
  final double minActionWidth;

  @override
  Widget build(BuildContext context) => ResponsiveFields(
        gap: gap,
        minFieldWidth: minActionWidth,
        children: children,
      );
}

/// Compatibility spelling used by V0.14 prescribing code. This intentionally
/// shares the same responsive behavior as [ResponsiveActions].
class ResponsiveButtonRow extends ResponsiveActions {
  const ResponsiveButtonRow({
    super.key,
    required super.children,
    super.gap,
    super.minActionWidth,
  });
}

/// Adaptive grid used by compact dashboard summaries. It chooses fewer columns
/// rather than allowing labels to wrap into broken-looking tiles.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 190,
    this.maxColumns = 3,
    this.spacing = 10,
    this.runSpacing = 10,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final possible = math.max(
          1,
          ((constraints.maxWidth + spacing) / (minItemWidth + spacing)).floor(),
        );
        final columns = math.min(maxColumns, possible);
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Keeps secondary helper copy from dominating small screens.
class CompactHelperText extends StatelessWidget {
  const CompactHelperText(
    this.text, {
    super.key,
    this.maxLinesPhone = 2,
    this.maxLinesWide = 3,
    this.textAlign,
  });

  final String text;
  final int maxLinesPhone;
  final int maxLinesWide;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: MedqurResponsive.isPhone(context) ? maxLinesPhone : maxLinesWide,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: const TextStyle(
          color: Color(0xFF748091),
          fontSize: 11.25,
          height: 1.3,
        ),
      );
}
