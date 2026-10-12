import 'package:flutter/material.dart';

import '../core/core.dart';

class Chip2 extends StatelessWidget {
  final String text;
  final Color? color;
  const Chip2(this.text, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final col = color ?? statusColor(text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      color: col.withAlpha(30),
      child: Text(
        text,
        style: TextStyle(
          color: col,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}
