import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../core/core.dart';
import 'nav_item.dart';
import 'notifications_dialog.dart';

class TopBar extends StatelessWidget {
  final bool mobile;
  const TopBar({super.key, required this.mobile});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          if (mobile)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          Expanded(
            child: Obx(
              () => Text(
                navItems[c.page.value].label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: C.navy,
                ),
              ),
            ),
          ),
          if (!mobile)
            SizedBox(
              width: 280,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search customers, jobs, invoices...',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onSubmitted: (v) {
                  c.custSearch.value = v;
                  c.page.value = 1;
                },
              ),
            ),
          const SizedBox(width: 6),
          Obx(
            () => IconButton(
              onPressed: () => showNotifications(context),
              icon: Badge(
                isLabelVisible: c.unreadNotifs > 0,
                label: Text('${c.unreadNotifs}'),
                backgroundColor: C.red,
                child: const Icon(Icons.notifications_none),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const CircleAvatar(
            radius: 17,
            backgroundColor: C.navy,
            child: Text(
              'MI',
              style: TextStyle(
                color: C.yellow,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!mobile) ...const [
            SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mathew Ihemesie',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text('Owner', style: TextStyle(color: C.muted, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
