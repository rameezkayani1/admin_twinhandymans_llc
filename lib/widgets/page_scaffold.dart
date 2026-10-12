import 'package:flutter/material.dart';

import '../core/core.dart';

class PageScaffold extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle = '',
    this.actions = const [],
    required this.children,
  });
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final pad = w < 600 ? 14.0 : 24.0;
    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: C.navy,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, style: const TextStyle(color: C.muted)),
                ],
              ),
              if (actions.isNotEmpty)
                Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}
