import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../core/core.dart';
import '../pages/login/login_page.dart';
import '../widgets/widgets.dart';
import 'nav_item.dart';

class SideNav extends StatelessWidget {
  final bool extended;
  final bool inDrawer;
  const SideNav({super.key, required this.extended, this.inDrawer = false});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return Container(
      width: extended ? 252 : 74,
      color: C.navy,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              height: 72,
              alignment: extended ? Alignment.centerLeft : Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: extended ? 18 : 0),
              child: extended
                  ? const Logo(light: true, small: true)
                  : const LogoMark(size: 40),
            ),
            const Divider(height: 1, color: C.navy2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (int i = 0; i < navItems.length; i++)
                    Obx(() {
                      final sel = c.page.value == i;
                      final badge = i == 2
                          ? c.requests.where((r) => r.status == 'New').length
                          : (i == 8
                                ? c.threads.fold<int>(0, (s, t) => s + t.unread)
                                : 0);
                      return Tooltip(
                        message: extended ? '' : navItems[i].label,
                        child: InkWell(
                          onTap: () {
                            c.page.value = i;
                            if (inDrawer) Navigator.of(context).pop();
                          },
                          child: Container(
                            height: 46,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: extended ? 14 : 0,
                            ),
                            color: sel ? C.yellow : Colors.transparent,
                            child: Row(
                              mainAxisAlignment: extended
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                Icon(
                                  navItems[i].icon,
                                  size: 21,
                                  color: sel ? C.navy : const Color(0xFFB8C4D6),
                                ),
                                if (extended) ...[
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      navItems[i].label,
                                      style: TextStyle(
                                        color: sel ? C.navy : Colors.white,
                                        fontWeight: sel
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (badge > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      color: sel ? C.navy : C.yellow,
                                      child: Text(
                                        '$badge',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: sel ? C.yellow : C.navy,
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const Divider(height: 1, color: C.navy2),
            InkWell(
              onTap: () => Get.offAll(() => const LoginView()),
              child: Container(
                height: 56,
                padding: EdgeInsets.symmetric(horizontal: extended ? 22 : 0),
                alignment: extended ? Alignment.centerLeft : Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.logout,
                      color: Color(0xFFB8C4D6),
                      size: 20,
                    ),
                    if (extended) ...const [
                      SizedBox(width: 14),
                      Text('Sign out', style: TextStyle(color: Colors.white)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
