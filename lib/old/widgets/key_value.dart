import 'package:flutter/material.dart';

import '../core/core.dart';

class KV extends StatelessWidget {
  final String k, v;
  final bool boldV;
  const KV(this.k, this.v, {super.key, this.boldV = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(k, style: const TextStyle(color: C.muted)),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              fontWeight: boldV ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class KV2 extends StatelessWidget {
  final String k, v;
  const KV2(this.k, this.v, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    color: const Color(0xFFF7F8FA),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}
