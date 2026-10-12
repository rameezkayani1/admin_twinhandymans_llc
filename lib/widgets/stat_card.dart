import 'package:flutter/material.dart';

import '../core/core.dart';

class Stat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final String? hint;
  final Color color;
  final VoidCallback? onTap;
  const Stat(
    this.label,
    this.value,
    this.icon, {
    super.key,
    this.hint,
    this.color = C.navy,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: C.line),
          boxShadow: const [],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              color: color.withAlpha(25),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: C.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: C.text,
                      ),
                    ),
                  ),
                  if (hint != null)
                    Text(
                      hint!,
                      style: const TextStyle(fontSize: 11, color: C.muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
