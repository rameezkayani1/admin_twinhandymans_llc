import 'package:flutter/material.dart';

import '../core/core.dart';

class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.white,
      child: Image.network(
        kLogoUrl,
        fit: BoxFit.contain,
        loadingBuilder: (c, child, p) => p == null
            ? child
            : const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: C.navy,
                  ),
                ),
              ),
        errorBuilder: (c, e, st) => Container(
          alignment: Alignment.center,
          color: C.yellow,
          child: Text(
            'TH',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: size * .42,
              color: C.navy,
            ),
          ),
        ),
      ),
    );
  }
}

class Logo extends StatelessWidget {
  final bool light;
  final bool small;
  const Logo({super.key, this.light = false, this.small = false});
  @override
  Widget build(BuildContext context) {
    final s = small ? 38.0 : 52.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // LogoMark(size: s),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TWINS HANDYMAN',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                fontSize: small ? 13 : 16,
                color: light ? Colors.white : C.navy,
              ),
            ),
            Text(
              'ADMIN PORTAL',
              style: TextStyle(
                fontSize: small ? 10 : 11,
                letterSpacing: 2,
                color: light ? C.yellow : C.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
