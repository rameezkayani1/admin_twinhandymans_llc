import 'package:flutter/material.dart';

import '../core/core.dart';

Future<void> showDetail(
  BuildContext context, {
  required String title,
  required Widget body,
  List<Widget> actions = const [],
}) {
  return showDialog(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: C.navy,
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: body,
              ),
            ),
            if (actions.isNotEmpty)
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: C.line)),
                ),
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
