import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/core.dart';

// Reads the same Firestore structure as the customer app:
//   chats/{customerUid}                -> summary (name, lastMessage, unread...)
//   chats/{customerUid}/messages/{id}  -> messages

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  String? _selectedId;
  String _selectedName = '';

  void _open(String id, String name, bool wide) {
    setState(() {
      _selectedId = id;
      _selectedName = name;
    });
    if (!wide) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              backgroundColor: C.navy,
              foregroundColor: Colors.white,
              title: Text(name),
            ),
            body: AdminChatView(chatId: id, customerName: name),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 860;

        final list = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .orderBy('lastMessageAt', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(
                child: Text('Could not load chats (check admin role / rules).'),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No customer messages yet.'));
            }
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i];
                final m = d.data();
                final name = (m['customerName'] ?? 'Customer').toString();
                final unread = (m['unreadForAdmin'] ?? 0) as int;
                return Container(
                  color: wide && _selectedId == d.id
                      ? C.yellow.withAlpha(40)
                      : Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: C.navy,
                      child: Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(
                          color: C.yellow,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: unread > 0
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      (m['lastMessage'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: unread > 0
                        ? CircleAvatar(
                            radius: 10,
                            backgroundColor: C.red,
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => _open(d.id, name, wide),
                  ),
                );
              },
            );
          },
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
                  child: _selectedId == null
                      ? const Center(child: Text('Select a conversation'))
                      : AdminChatView(
                          key: ValueKey(
                            _selectedId,
                          ), // fresh state per customer
                          chatId: _selectedId!,
                          customerName: _selectedName,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =========================================================
// Single conversation (admin side)
// =========================================================
class AdminChatView extends StatefulWidget {
  final String chatId; // = customer uid
  final String customerName;
  const AdminChatView({
    super.key,
    required this.chatId,
    required this.customerName,
  });
  @override
  State<AdminChatView> createState() => _AdminChatViewState();
}

class _AdminChatViewState extends State<AdminChatView> {
  final _ctl = TextEditingController();
  final _db = FirebaseFirestore.instance;
  String? _lastReadId;

  DocumentReference<Map<String, dynamic>> get _chatRef =>
      _db.collection('chats').doc(widget.chatId);
  CollectionReference<Map<String, dynamic>> get _msgs =>
      _chatRef.collection('messages');

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await _chatRef.update({'unreadForAdmin': 0});
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    _ctl.clear();

    final batch = _db.batch();
    batch.set(_msgs.doc(), {
      'text': text,
      'senderId': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
      'senderRole': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_chatRef, {
      'lastMessage': 'You: $text',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadForCustomer': FieldValue.increment(1),
      'unreadForAdmin': 0,
    }, SetOptions(merge: true));
    try {
      await batch.commit();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Message not sent')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: C.line)),
          ),
          child: Text(
            widget.customerName,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _msgs
                .orderBy('createdAt', descending: true)
                .limit(200)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;

              // New customer message while this chat is open -> clear badge
              if (docs.isNotEmpty &&
                  docs.first.data()['senderRole'] == 'customer' &&
                  _lastReadId != docs.first.id) {
                _lastReadId = docs.first.id;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _markRead(),
                );
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final m = docs[i].data();
                  final mine = m['senderRole'] == 'admin';
                  final time = (m['createdAt'] as Timestamp?)?.toDate();
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      color: mine ? C.navy : const Color(0xFFEEF1F5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (m['text'] ?? '').toString(),
                            style: TextStyle(
                              color: mine ? Colors.white : C.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            time == null ? 'sending…' : _fmt(time),
                            style: TextStyle(
                              fontSize: 10,
                              color: mine ? const Color(0xFFB8C4D6) : C.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
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
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Attachments coming soon')),
                ),
                icon: const Icon(Icons.attach_file),
              ),
              Expanded(
                child: TextField(
                  controller: _ctl,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _send, child: const Icon(Icons.send)),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }
}
