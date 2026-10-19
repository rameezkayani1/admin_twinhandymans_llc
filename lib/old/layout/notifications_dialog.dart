import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../core/core.dart';

void showNotifications(BuildContext context) {
  final c = Get.find<AppController>();
  showDialog(
    context: context,
    builder: (_) => Dialog(
      alignment: Alignment.topRight,
      insetPadding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: c.markAllRead,
                    child: const Text('Mark all read'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: Obx(
                () => ListView(
                  shrinkWrap: true,
                  children: [
                    for (final n in c.notifications)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: C.navy,
                          radius: 18,
                          child: Icon(n.icon, color: C.yellow, size: 18),
                        ),
                        title: Text(
                          n.title,
                          style: TextStyle(
                            fontWeight: n.unread
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text('${n.body}\n${n.time}'),
                        isThreeLine: true,
                        trailing: n.unread
                            ? const Icon(Icons.circle, size: 9, color: C.yellow)
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
