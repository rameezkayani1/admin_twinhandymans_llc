import 'package:flutter/material.dart';

class Grid extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;
  final double gap;
  const Grid({
    super.key,
    required this.children,
    this.minWidth = 240,
    this.gap = 14,
  });
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = (box.maxWidth / minWidth).floor().clamp(
          1,
          children.length == 0 ? 1 : children.length,
        );
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final ch in children) SizedBox(width: w, child: ch)],
        );
      },
    );
  }
}
