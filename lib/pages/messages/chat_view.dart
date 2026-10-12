import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';

class ChatView extends StatefulWidget {
  final int index;
  const ChatView({super.key, required this.index});
  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final ctl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>();
    return Column(
      children: [
        Obx(
          () => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: C.line)),
            ),
            child: Text(
              '${c.threads[widget.index].customer} • ${c.threads[widget.index].job}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        Expanded(
          child: Obx(
            () => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final m in c.threads[widget.index].msgs)
                  Align(
                    alignment: m.mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      color: m.mine ? C.navy : const Color(0xFFEEF1F5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            m.text,
                            style: TextStyle(
                              color: m.mine ? Colors.white : C.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.time,
                            style: TextStyle(
                              fontSize: 10,
                              color: m.mine ? const Color(0xFFB8C4D6) : C.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: C.line)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () =>
                    c.snack('Attach photo / video / document (demo)'),
                icon: const Icon(Icons.attach_file),
              ),
              Expanded(
                child: TextField(
                  controller: ctl,
                  onSubmitted: (v) {
                    c.sendMessage(widget.index, v);
                    ctl.clear();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  c.sendMessage(widget.index, ctl.text);
                  ctl.clear();
                },
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
