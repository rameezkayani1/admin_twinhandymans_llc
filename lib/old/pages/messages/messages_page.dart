import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import 'chat_view.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 860;
        final list = Obx(
          () => ListView(
            children: [
              for (int i = 0; i < c.threads.length; i++)
                Container(
                  color: wide && c.selectedThread.value == i
                      ? C.yellow.withAlpha(40)
                      : Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: C.navy,
                      child: Text(
                        c.threads[i].customer[0],
                        style: const TextStyle(
                          color: C.yellow,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      c.threads[i].customer,
                      style: TextStyle(
                        fontWeight: c.threads[i].unread > 0
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${c.threads[i].job}\n${c.threads[i].msgs.last.text}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: c.threads[i].unread > 0
                        ? CircleAvatar(
                            radius: 10,
                            backgroundColor: C.red,
                            child: Text(
                              '${c.threads[i].unread}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      c.selectedThread.value = i;
                      c.threads[i].unread = 0;
                      c.threads.refresh();
                      if (!wide)
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                backgroundColor: C.navy,
                                foregroundColor: Colors.white,
                                title: Text(c.threads[i].customer),
                              ),
                              body: ChatView(index: i),
                            ),
                          ),
                        );
                    },
                  ),
                ),
            ],
          ),
        );
        if (!wide) return list;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: C.line),
              color: Colors.white,
            ),
            child: Row(
              children: [
                SizedBox(width: 340, child: list),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Obx(() => ChatView(index: c.selectedThread.value)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
