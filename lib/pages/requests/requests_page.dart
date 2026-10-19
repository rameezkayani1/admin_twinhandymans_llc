// =============================================================
// requests_page.dart — Admin: Quote Requests (simple pipeline)
//
// Firestore (unchanged):
//   quote_requests/{id}  written by the customer app, updated here
//   quotes/{id}          copy of the quote sent to the customer
//   notifications/{id}   in-app notification for the customer
//
// Pipeline: New Request -> Under Review -> Quote Sent -> Quote Accepted
//           -> Deposit Paid -> Scheduled   (or Declined)
//
// When admin sends a quote, this writes on quote_requests/{id}:
//   status: 'quoted'
//   quoteAmount: total
//   quote: { total, deposit, depositPct, depositType, depositValue,
//            notes, issuedAt, expiresAt }
// which is exactly what the customer app reads.
//
// Packages: cloud_firestore, firebase_auth, url_launcher, get
// =============================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/widgets.dart';

// ── Tokens ──────────────────────────────────────────────────
const _orange = Color(0xFFFF7A00);
const _navy = Color(0xFF1B1464);
const _ink = Color(0xFF1F2430);
const _muted = Color(0xFF7A8194);
const _line = Color(0xFFE6E9F2);
const _bg = Color(0xFFF6F7FB);
const _red = Color(0xFFD63638);
const _green = Color(0xFF22B573);

class _St {
  final String label;
  final Color color;
  const _St(this.label, this.color);
}

/// Display statuses. 'paid' = accepted + depositPaid (derived).
const _statuses = <String, _St>{
  'pending': _St('New Request', Color(0xFF8A94A6)),
  'reviewing': _St('Under Review', Color(0xFF2271B1)),
  'quoted': _St('Quote Sent', Color(0xFFC99700)),
  'changes_requested': _St('Changes Requested', Color(0xFFE67E22)),
  'accepted': _St('Quote Accepted', Color(0xFF1F8A5B)),
  'paid': _St('Deposit Paid', Color(0xFF22B573)),
  'scheduled': _St('Scheduled', Color(0xFF1B1464)),
  'completed': _St('Completed', Color(0xFF4F5D75)),
  'rejected': _St('Declined', Color(0xFFD63638)),
  'cancelled': _St('Cancelled', Color(0xFF828282)),
};

/// Cards on top (also work as filters).
const _cardKeys = [
  'pending',
  'reviewing',
  'quoted',
  'accepted',
  'paid',
  'scheduled',
  'rejected',
];

/// Statuses the admin may set by hand ("Quote Sent" is set by sending a quote).
const _manualStatuses = [
  'pending',
  'reviewing',
  'accepted',
  'paid',
  'scheduled',
  'completed',
  'rejected',
  'cancelled',
];

const _svcIcons = <String, IconData>{
  'Painting': Icons.format_paint_outlined,
  'Moving': Icons.local_shipping_outlined,
  'Cleaning': Icons.cleaning_services_outlined,
  'Assembly': Icons.build_outlined,
  'Lawn Services': Icons.grass_outlined,
  'Waste Disposal': Icons.delete_outline,
  'Pressure Washing': Icons.water_drop_outlined,
};

// ── Helpers ─────────────────────────────────────────────────
const _mon = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _money(num v) {
  final p = v.toStringAsFixed(2).split('.');
  final i = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '\$$i.${p[1]}';
}

String _d(DateTime d) => '${_mon[d.month - 1]} ${d.day}, ${d.year}';

String _dt(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${_d(d)} • $h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String _ago(DateTime d) {
  final x = DateTime.now().difference(d);
  if (x.inMinutes < 1) return 'just now';
  if (x.inMinutes < 60) return '${x.inMinutes}m ago';
  if (x.inHours < 24) return '${x.inHours}h ago';
  if (x.inDays < 7) return '${x.inDays}d ago';
  return _d(d);
}

double _r2(double v) => (v * 100).round() / 100;
String _fmt(num v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';

/// Tolerant number parser (num, "450", "$1,250.50", null).
double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
}

double _p(TextEditingController c) => _num(c.text);

void _toast(String msg, {bool error = false}) => Get.snackbar(
  error ? 'Oops' : 'Done',
  msg,
  snackPosition: SnackPosition.BOTTOM,
  margin: const EdgeInsets.all(16),
  maxWidth: 520,
  borderRadius: 14,
  backgroundColor: error ? _red : _green,
  colorText: Colors.white,
);

Future<void> _open(String url) async {
  final u = Uri.tryParse(url);
  if (u == null || !await launchUrl(u, mode: LaunchMode.externalApplication)) {
    _toast('Could not open link', error: true);
  }
}

OutlineInputBorder _ob(Color c, {double w = 1}) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(10),
  borderSide: BorderSide(color: c, width: w),
);

InputDecoration _dec(
  String? label, {
  String? hint,
  IconData? icon,
  String? prefix,
  String? suffix,
}) => InputDecoration(
  labelText: label,
  hintText: hint,
  prefixText: prefix,
  suffixText: suffix,
  prefixIcon: icon == null ? null : Icon(icon, size: 20, color: _muted),
  isDense: true,
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  border: _ob(_line),
  enabledBorder: _ob(_line),
  focusedBorder: _ob(_orange, w: 1.6),
);

/// Solid pill, like the WordPress pipeline.
Widget _chip(String status) {
  final m = _statuses[status] ?? _St(status, Colors.grey);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: m.color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      m.label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
  );
}

Widget _box({required Widget child, EdgeInsets? pad}) => Container(
  width: double.infinity,
  padding: pad ?? const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _line),
  ),
  child: child,
);

Widget _heading(String t, {double top = 22}) => Padding(
  padding: EdgeInsets.only(top: top, bottom: 8),
  child: Text(
    t,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 14.5,
      color: _ink,
    ),
  ),
);

// ── Attachments ─────────────────────────────────────────────
enum _Kind { image, video, file }

/// One uploaded file, normalised from whatever the customer app stored
/// (map or plain url string; http url, gs:// url or storage path).
class _Att {
  _Att(this.name, this.raw, this.kind);
  final String name;
  final String raw;
  final _Kind kind;

  static const _img = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif',
  ];
  static const _vid = ['mp4', 'mov', 'm4v', 'webm', 'avi', 'mkv', '3gp'];

  static _Att? parse(dynamic e, [String? hint]) {
    var raw = '', name = '', type = '';
    if (e is String) {
      raw = e;
    } else if (e is Map) {
      raw =
          '${e['url'] ?? e['downloadUrl'] ?? e['downloadURL'] ?? e['fileUrl'] ?? e['link'] ?? e['path'] ?? ''}';
      name = '${e['name'] ?? e['fileName'] ?? ''}';
      type = '${e['type'] ?? e['contentType'] ?? e['mimeType'] ?? ''}'
          .toLowerCase();
    } else {
      return null;
    }
    raw = raw.trim();
    if (raw.isEmpty) return null;

    String decoded;
    try {
      decoded = Uri.decodeFull(raw.split('?').first);
    } catch (_) {
      decoded = raw.split('?').first;
    }
    if (name.isEmpty) name = decoded.split('/').last;
    final ext = (name.contains('.') ? name : decoded)
        .split('.')
        .last
        .toLowerCase();

    final kind = type.contains('image') || hint == 'image' || _img.contains(ext)
        ? _Kind.image
        : type.contains('video') || hint == 'video' || _vid.contains(ext)
        ? _Kind.video
        : _Kind.file;
    return _Att(name, raw, kind);
  }

  /// Returns a browser-loadable https url.
  Future<String> resolve() async {
    if (raw.startsWith('http')) return raw;
    final st = FirebaseStorage.instance;
    return raw.startsWith('gs://')
        ? st.refFromURL(raw).getDownloadURL()
        : st.ref(raw).getDownloadURL();
  }
}

// ── Data ────────────────────────────────────────────────────
class _Req {
  _Req(this.id, this.m);
  final String id;
  final Map<String, dynamic> m;
  factory _Req.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      _Req(d.id, d.data() ?? {});

  String s(String k) => (m[k] ?? '').toString();
  String get number => s('requestNumber').isEmpty ? id : s('requestNumber');
  String get name => s('customerName');
  String get service => s('service');

  String get rawStatus => s('status').isEmpty ? 'pending' : s('status');
  bool get paid => m['depositPaid'] == true;

  /// Status shown in the UI ('paid' is derived).
  String get status => rawStatus == 'accepted' && paid ? 'paid' : rawStatus;

  bool get canQuote => const [
    'pending',
    'reviewing',
    'quoted',
    'changes_requested',
  ].contains(rawStatus);

  double get budget => _num(m['budget']);
  DateTime? get preferred => (m['preferredDate'] as Timestamp?)?.toDate();
  DateTime? get created => (m['createdAt'] as Timestamp?)?.toDate();
  String? get quoteId => m['quoteId'] as String?;

  Map<String, dynamic> get quote =>
      m['quote'] is Map ? Map<String, dynamic>.from(m['quote']) : {};
  double get quoteTotal {
    final t = _num(quote['total']);
    return t > 0 ? t : _num(m['quoteAmount']);
  }

  double get deposit => _num(quote['deposit']);

  /// "$100.00 / $20.00" like the pipeline table.
  String get amountText => quoteTotal <= 0
      ? '—'
      : '${_money(quoteTotal)} / ${deposit > 0 ? _money(deposit) : '—'}';

  List<_Att> get files {
    final out = <_Att>[];
    final seen = <String>{};
    const keys = {
      'attachments': null,
      'files': null,
      'images': 'image',
      'photos': 'image',
      'videos': 'video',
    };
    keys.forEach((k, hint) {
      final v = m[k];
      if (v is! List) return;
      for (final e in v) {
        final a = _Att.parse(e, hint);
        if (a != null && seen.add(a.raw)) out.add(a);
      }
    });
    return out;
  }

  List<Map<String, dynamic>> get history => _list('statusHistory');
  List<Map<String, dynamic>> _list(String k) => ((m[k] as List?) ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

class _Api {
  static final db = FirebaseFirestore.instance;
  static DocumentReference<Map<String, dynamic>> req(String id) =>
      db.collection('quote_requests').doc(id);
  static String get me => FirebaseAuth.instance.currentUser?.email ?? 'admin';

  static Map<String, dynamic> historyEntry(String status, {String note = ''}) =>
      {
        'status': status,
        'at': Timestamp.now(),
        'by': me,
        if (note.isNotEmpty) 'note': note,
      };

  /// Sets a status. 'paid' = approved + deposit marked as paid.
  static Future<void> setStatus(_Req r, String key) async {
    final isPaid = key == 'paid';
    final status = isPaid ? 'accepted' : key;
    await req(r.id).update({
      'status': status,
      if (isPaid) ...{
        'depositPaid': true,
        'depositPaidAt': FieldValue.serverTimestamp(),
        'paymentMethod': 'admin',
      },
      'updatedAt': FieldValue.serverTimestamp(),
      'statusHistory': FieldValue.arrayUnion([
        historyEntry(status, note: isPaid ? 'Deposit marked as paid' : ''),
      ]),
    });
    await notify(
      r,
      'Request update',
      'Your ${r.service} request is now ${_statuses[key]?.label ?? key}.',
      'request',
    );
  }

  /// In-app notification doc (a Cloud Function can turn this into a push).
  static Future<void> notify(
    _Req r,
    String title,
    String body,
    String type, {
    String? quoteId,
  }) async {
    final uid = r.s('userId');
    if (uid.isEmpty) return;
    try {
      await db.collection('notifications').add({
        'userId': uid,
        'title': title,
        'body': body,
        'type': type,
        'requestId': r.id,
        'quoteId': quoteId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

// =============================================================
// PAGE
// =============================================================
class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});
  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  late final Stream<List<_Req>> _stream = FirebaseFirestore.instance
      .collection('quote_requests')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(_Req.fromDoc).toList());

  String? _filter; // null = all
  String _q = '';

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Quote Pipeline',
    subtitle: 'Review requests, send a quote, and track payment',
    children: [
      StreamBuilder<List<_Req>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('Could not load requests.\n${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final all = snap.data!;
          int count(String k) => all.where((r) => r.status == k).length;
          final q = _q.toLowerCase();
          final list = all.where((r) {
            if (_filter != null && r.status != _filter) return false;
            if (q.isEmpty) return true;
            return '${r.name} ${r.number} ${r.service} ${r.s('phone')} ${r.s('email')} ${r.s('address')}'
                .toLowerCase()
                .contains(q);
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stats(count),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _filter == null
                          ? 'Recent requests'
                          : _statuses[_filter]!.label,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                  ),
                  if (_filter != null)
                    TextButton(
                      onPressed: () => setState(() => _filter = null),
                      child: const Text('Show all'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: _dec(
                  null,
                  hint: 'Search name, reference, service, phone, address',
                  icon: Icons.search,
                ),
              ),
              const SizedBox(height: 14),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'No requests found',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (_, b) =>
                      b.maxWidth >= 820 ? _table(list) : _cards(list),
                ),
            ],
          );
        },
      ),
    ],
  );

  // ── stat cards (tap = filter) ──
  Widget _stats(int Function(String) count) => LayoutBuilder(
    builder: (_, b) {
      final cols = b.maxWidth >= 1100 ? 7 : (b.maxWidth >= 760 ? 4 : 2);
      const gap = 10.0;
      final w = (b.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final k in _cardKeys)
            SizedBox(
              width: w,
              child: _StatCard(
                label: _statuses[k]!.label,
                count: count(k),
                color: _statuses[k]!.color,
                selected: _filter == k,
                onTap: () => setState(() => _filter = _filter == k ? null : k),
              ),
            ),
        ],
      );
    },
  );

  // ── wide layout: table ──
  Widget _table(List<_Req> list) {
    const head = TextStyle(fontWeight: FontWeight.w700, color: _ink);
    Widget cell(int flex, Widget w) => Expanded(flex: flex, child: w);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                cell(2, const Text('Reference', style: head)),
                cell(2, const Text('Customer', style: head)),
                cell(2, const Text('Service', style: head)),
                cell(2, const Text('Quoted / Deposit', style: head)),
                cell(2, const Text('Status', style: head)),
                cell(2, const Text('Submitted', style: head)),
                const SizedBox(width: 56),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          for (var i = 0; i < list.length; i++)
            InkWell(
              onTap: () => openRequestById(context, list[i].id),
              child: Container(
                color: i.isOdd ? _bg : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    cell(
                      2,
                      Text(
                        list[i].number,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                    cell(
                      2,
                      Text(
                        list[i].name.isEmpty ? 'Customer' : list[i].name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    cell(
                      2,
                      Text(list[i].service, overflow: TextOverflow.ellipsis),
                    ),
                    cell(2, Text(list[i].amountText)),
                    cell(
                      2,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _chip(list[i].status),
                      ),
                    ),
                    cell(
                      2,
                      Text(
                        list[i].created == null ? '—' : _d(list[i].created!),
                        style: const TextStyle(color: _muted),
                      ),
                    ),
                    const SizedBox(
                      width: 56,
                      child: Text(
                        'View',
                        style: TextStyle(
                          color: Color(0xFF2271B1),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── narrow layout: cards ──
  Widget _cards(List<_Req> list) =>
      Column(children: [for (final r in list) _tile(r)]);

  Widget _tile(_Req r) {
    final icon = _svcIcons[r.service] ?? Icons.handyman_outlined;
    final color = _statuses[r.status]?.color ?? _orange;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _line),
        ),
        child: InkWell(
          onTap: () => openRequestById(context, r.id),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name.isEmpty ? 'Customer' : r.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _ink,
                            ),
                          ),
                          Text(
                            '${r.number} • ${r.service}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _chip(r.status),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.quoteTotal > 0
                            ? 'Quote ${r.amountText}'
                            : 'Budget ${_money(r.budget)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                    Text(
                      r.created == null ? '' : _ago(r.created!),
                      style: const TextStyle(color: _muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: selected ? color : _line,
        width: selected ? 1.8 : 1,
      ),
    ),
    child: InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 5, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
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
  );
}

/// Public entry point (use from the dashboard etc.).
void openRequestById(BuildContext context, String id) => showDialog(
  context: context,
  builder: (_) => _RequestDialog(id: id),
);

// =============================================================
// REQUEST DETAIL DIALOG
// =============================================================
class _RequestDialog extends StatefulWidget {
  const _RequestDialog({required this.id});
  final String id;
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _s = _Api.req(
    widget.id,
  ).snapshots();
  final _note = TextEditingController();
  bool _noteInit = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    try {
      await _Api.req(widget.id).update({
        'adminNote': _note.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _toast('Note saved');
    } catch (_) {
      _toast('Could not save note', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: _bg,
    insetPadding: const EdgeInsets.all(12),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 1000,
        maxHeight: MediaQuery.of(context).size.height * .94,
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _s,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snap.data!.exists) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Request not found'),
            );
          }
          final r = _Req.fromDoc(snap.data!);
          if (!_noteInit) {
            _note.text = r.s('adminNote');
            _noteInit = true;
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(r),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: LayoutBuilder(
                    builder: (_, b) {
                      final panel = _StatusPanel(key: ValueKey(r.id), r: r);
                      final details = _details(r);
                      if (b.maxWidth < 760) {
                        return Column(
                          children: [
                            panel,
                            const SizedBox(height: 16),
                            details,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 16),
                          SizedBox(width: 340, child: panel),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _header(_Req r) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${r.number} — ${r.name.isEmpty ? 'Customer' : r.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              Text(
                r.created == null
                    ? r.service
                    : '${r.service} • ${_ago(r.created!)}',
                style: const TextStyle(color: _muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _chip(r.status),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );

  // ── request details ──
  Widget _row(String k, String v, int i, {String? uri}) => Container(
    color: i.isOdd ? _bg : Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: const TextStyle(color: _muted)),
        ),
        Expanded(child: SelectableText(v.isEmpty ? '—' : v)),
        if (uri != null && v.isNotEmpty)
          InkWell(
            onTap: () => _open(uri),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.open_in_new, size: 17, color: _orange),
            ),
          ),
      ],
    ),
  );

  Widget _details(_Req r) {
    final pref = r.preferred == null ? '' : _d(r.preferred!);
    final rows = <(String, String, String?)>[
      ('Reference', r.number, null),
      ('Full name', r.name, null),
      ('Phone', r.s('phone'), 'tel:${r.s('phone')}'),
      ('Email', r.s('email'), 'mailto:${r.s('email')}'),
      ('Service needed', r.service, null),
      ('Job description', r.s('description'), null),
      ('Job address', r.s('address'), null),
      ('Preferred date', pref, null),
      ('Preferred time', r.s('preferredSlot'), null),
      ('Urgency', r.s('urgency'), null),
      ('Customer budget', r.budget > 0 ? _money(r.budget) : '', null),
    ];
    final cNote = r.s('customerNote');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                _row(rows[i].$1, rows[i].$2, i, uri: rows[i].$3),
            ],
          ),
        ),
        if (cNote.isNotEmpty) ...[
          _heading('Message from customer'),
          _box(child: Text('"$cNote"', style: const TextStyle(height: 1.4))),
        ],
        _heading('Uploaded files (${r.files.length})'),
        _files(r),
        _heading('Internal note (not shown to customer)'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: _dec(null, hint: 'Site visit details, reminders…'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saveNote,
              child: const Text('Save note'),
            ),
          ],
        ),
        if (r.history.isNotEmpty) ...[_heading('Activity'), _timeline(r)],
      ],
    );
  }

  Widget _files(_Req r) {
    if (r.files.isEmpty) {
      return const Text(
        'No files were attached to this request.',
        style: TextStyle(color: _muted, fontStyle: FontStyle.italic),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final a in r.files)
          _AttTile(key: ValueKey(a.raw), a: a, onImage: _viewImage),
      ],
    );
  }

  void _viewImage(_Att a, String url) => showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  loadingBuilder: (_, child, p) => p == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                  errorBuilder: (_, __, ___) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white70,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Preview not available',
                        style: TextStyle(color: Colors.white70),
                      ),
                      TextButton.icon(
                        onPressed: () => _open(url),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open in browser'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 12,
            right: 4,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                IconButton(
                  tooltip: 'Open / download',
                  onPressed: () => _open(url),
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _timeline(_Req r) => Column(
    children: [
      for (final h in r.history.reversed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: _statuses['${h['status']}']?.color ?? _muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _statuses['${h['status']}']?.label ?? '${h['status']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${h['by'] == 'customer' ? 'Customer' : (h['by'] ?? '')}'
                  '${h['at'] is Timestamp ? ' • ${_dt((h['at'] as Timestamp).toDate())}' : ''}'
                  '${'${h['note'] ?? ''}'.isEmpty ? '' : ' • ${h['note']}'}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

// =============================================================
// STATUS & QUOTE PANEL  (simple: status + amount + deposit)
// =============================================================
class _StatusPanel extends StatefulWidget {
  const _StatusPanel({super.key, required this.r});
  final _Req r;
  @override
  State<_StatusPanel> createState() => _StatusPanelState();
}

class _StatusPanelState extends State<_StatusPanel> {
  final _amount = TextEditingController();
  final _depositVal = TextEditingController(text: '20');
  final _notes = TextEditingController();
  String _depositType = 'percent'; // percent | fixed
  DateTime _expires = DateTime.now().add(const Duration(days: 14));
  String? _sel;
  bool _busy = false;

  _Req get r => widget.r;

  @override
  void initState() {
    super.initState();
    final q = r.quote;
    if (r.quoteTotal > 0) _amount.text = _fmt(r.quoteTotal);
    if (q['depositType'] != null) _depositType = '${q['depositType']}';
    if (_num(q['depositValue']) > 0)
      _depositVal.text = _fmt(_num(q['depositValue']));
    if (q['expiresAt'] is Timestamp) {
      _expires = (q['expiresAt'] as Timestamp).toDate();
    }
    _notes.text = '${q['notes'] ?? ''}';
  }

  @override
  void dispose() {
    _amount.dispose();
    _depositVal.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ── calculations ──
  double get _total => _r2(_p(_amount));
  double get _deposit => _depositType == 'percent'
      ? _r2(_total * _p(_depositVal).clamp(0.0, 100.0) / 100)
      : _r2(_p(_depositVal).clamp(0.0, _total).toDouble());
  double get _balance => _r2(_total - _deposit);

  Future<void> _updateStatus() async {
    final s = _sel;
    if (s == null) return;
    setState(() => _busy = true);
    try {
      await _Api.setStatus(r, s);
      _toast('Status: ${_statuses[s]?.label ?? s}');
      _sel = null;
    } catch (_) {
      _toast('Could not update status. Check permissions.', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _expires.isBefore(now) ? now : _expires,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _expires = d);
  }

  Future<void> _send() async {
    if (_total <= 0) {
      _toast('Enter the quoted amount', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final quotes = _Api.db.collection('quotes');
      final isNew = r.quoteId == null;
      final ref = isNew ? quotes.doc() : quotes.doc(r.quoteId);
      final digits = r.number.replaceAll(RegExp(r'[^0-9]'), '');
      final expiresAt = Timestamp.fromDate(
        DateTime(_expires.year, _expires.month, _expires.day, 23, 59),
      );
      final pct = _total > 0 ? _r2(_deposit / _total * 100) : 0.0;

      // 1) the quote the customer app reads (on the request itself)
      final quote = {
        'total': _total,
        'deposit': _deposit,
        'depositPct': pct,
        'depositType': _depositType,
        'depositValue': _p(_depositVal),
        'notes': _notes.text.trim(),
        'issuedAt': Timestamp.now(),
        'expiresAt': expiresAt,
      };

      // 2) copy in `quotes` collection
      await ref.set({
        'id': ref.id,
        'quoteNumber': 'QT-${digits.isEmpty ? r.id.substring(0, 6) : digits}',
        'requestId': r.id,
        'requestNumber': r.number,
        'userId': r.s('userId'),
        'customerName': r.name,
        'email': r.s('email'),
        'phone': r.s('phone'),
        'service': r.service,
        ...quote,
        'balance': _balance,
        'status': 'sent',
        'createdBy': _Api.me,
        'updatedAt': FieldValue.serverTimestamp(),
        if (isNew) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3) update the request -> customer sees amount + deposit live
      await _Api.req(r.id).update({
        'status': 'quoted',
        'quoteAmount': _total,
        'quoteId': ref.id,
        'quote': quote,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          _Api.historyEntry('quoted', note: 'Quote ${_money(_total)}'),
        ]),
      });

      await _Api.notify(
        r,
        isNew ? 'Quote received' : 'Quote updated',
        'Your ${r.service} quote is ready: ${_money(_total)}. '
            'Deposit due: ${_money(_deposit)}.',
        'quote',
        quoteId: ref.id,
      );
      _toast(isNew ? 'Quote sent to customer' : 'Quote updated and resent');
    } on FirebaseException catch (e) {
      _toast(e.message ?? 'Could not save quote', error: true);
    } catch (_) {
      _toast('Something went wrong. Please try again.', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t,
      style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final items = [
      ..._manualStatuses,
      if (!_manualStatuses.contains(r.status)) r.status,
    ];

    return _box(
      pad: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status & Quote',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          _label('Current status'),
          Align(alignment: Alignment.centerLeft, child: _chip(r.status)),
          const SizedBox(height: 16),

          // ── set status ──
          _label('Set status'),
          DropdownButtonFormField<String>(
            value: _sel ?? r.status,
            isExpanded: true,
            decoration: _dec(null),
            items: [
              for (final k in items)
                DropdownMenuItem(
                  value: k,
                  child: Text(_statuses[k]?.label ?? k),
                ),
            ],
            onChanged: _busy ? null : (v) => setState(() => _sel = v),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: (_busy || _sel == null || _sel == r.status)
                ? null
                : _updateStatus,
            child: const Text('Update status'),
          ),

          const Divider(height: 34, color: _line),

          // ── payment received info ──
          if (r.paid) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded, color: _green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Deposit paid'
                      '${r.deposit > 0 ? ' · ${_money(r.deposit)}' : ''}'
                      '${r.s('paymentMethod').isEmpty ? '' : ' · ${r.s('paymentMethod')}'}'
                      '${r.s('paymentRef').isEmpty ? '' : '\nRef: ${r.s('paymentRef')}'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── quote ──
          if (!r.canQuote)
            Text(
              r.quoteTotal > 0
                  ? 'Quote: ${r.amountText}\n(Quote is locked after the customer responds.)'
                  : 'A quote can be sent while the request is new, in review, or quoted.',
              style: const TextStyle(color: _muted, height: 1.4),
            )
          else ...[
            _label('Quoted amount (\$)'),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: _dec(null, hint: '0.00', prefix: '\$ '),
            ),
            const SizedBox(height: 14),
            _label('Deposit (payable in advance)'),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: DropdownButtonFormField<String>(
                    value: _depositType,
                    isExpanded: true,
                    decoration: _dec(null),
                    items: const [
                      DropdownMenuItem(
                        value: 'percent',
                        child: Text('% of quote'),
                      ),
                      DropdownMenuItem(value: 'fixed', child: Text('Fixed \$')),
                    ],
                    onChanged: (v) => setState(() {
                      _depositType = v!;
                      _depositVal.text = v == 'percent' ? '20' : '';
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _depositVal,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: _dec(null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // live preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _sum('Total', _money(_total)),
                  _sum(
                    'Pay in advance',
                    _money(_deposit),
                    color: _orange,
                    bold: true,
                  ),
                  _sum('After the job', _money(_balance)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _label('Valid until'),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event, size: 18),
              label: Text(_d(_expires)),
            ),
            const SizedBox(height: 14),
            _label('Note for customer (optional)'),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: _dec(
                null,
                hint: 'Scope, materials included, timeline…',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  r.quoteId == null
                      ? 'Save & send quote to customer'
                      : 'Update & resend quote',
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFF2145E6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The customer is notified in the app and can review, approve and pay the deposit online.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sum(String k, String v, {Color? color, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(k, style: const TextStyle(color: _muted)),
        const Spacer(),
        Text(
          v,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
            color: color ?? _ink,
          ),
        ),
      ],
    ),
  );
}

// =============================================================
// ATTACHMENT TILE  (image preview / video / document)
// =============================================================
class _AttTile extends StatefulWidget {
  const _AttTile({super.key, required this.a, required this.onImage});
  final _Att a;
  final void Function(_Att a, String url) onImage;
  @override
  State<_AttTile> createState() => _AttTileState();
}

class _AttTileState extends State<_AttTile> {
  late final Future<String> _url = widget.a.resolve();

  Future<void> _tap() async {
    try {
      final url = await _url;
      if (widget.a.kind == _Kind.image) {
        widget.onImage(widget.a, url);
      } else {
        await _open(url); // video plays / document opens in a new tab
      }
    } catch (_) {
      _toast(
        'Could not load this file. Check Firebase Storage rules.',
        error: true,
      );
    }
  }

  Widget _icon(IconData i, Color c) =>
      Center(child: Icon(i, color: c, size: 34));

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final isVideo = a.kind == _Kind.video;

    Widget preview;
    if (a.kind == _Kind.image) {
      preview = FutureBuilder<String>(
        future: _url,
        builder: (_, snap) {
          if (snap.hasError) {
            return _icon(Icons.broken_image_outlined, _muted);
          }
          if (!snap.hasData) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return Image.network(
            snap.data!,
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            loadingBuilder: (_, child, p) => p == null
                ? child
                : const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            errorBuilder: (_, __, ___) =>
                _icon(Icons.image_not_supported_outlined, _muted),
          );
        },
      );
    } else if (isVideo) {
      preview = Container(
        color: _navy,
        child: _icon(Icons.play_circle_fill_rounded, Colors.white),
      );
    } else {
      preview = _icon(Icons.insert_drive_file_outlined, _orange);
    }

    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _tap,
            child: Container(
              width: 110,
              height: 110,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  preview,
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        a.kind == _Kind.image
                            ? Icons.zoom_in_rounded
                            : Icons.open_in_new_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            a.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: _muted),
          ),
        ],
      ),
    );
  }
}

// // =============================================================
// // requests_page.dart — Admin: Quote Requests (simple pipeline)
// //
// // Firestore (unchanged):
// //   quote_requests/{id}  written by the customer app, updated here
// //   quotes/{id}          copy of the quote sent to the customer
// //   notifications/{id}   in-app notification for the customer
// //
// // Pipeline: New Request -> Under Review -> Quote Sent -> Quote Accepted
// //           -> Deposit Paid -> Scheduled   (or Declined)
// //
// // When admin sends a quote, this writes on quote_requests/{id}:
// //   status: 'quoted'
// //   quoteAmount: total
// //   quote: { total, deposit, depositPct, depositType, depositValue,
// //            notes, issuedAt, expiresAt }
// // which is exactly what the customer app reads.
// //
// // Packages: cloud_firestore, firebase_auth, url_launcher, get
// // =============================================================
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// // ignore: depend_on_referenced_packages
// import 'package:url_launcher/url_launcher.dart';

// import '../../widgets/widgets.dart';

// // ── Tokens ──────────────────────────────────────────────────
// const _orange = Color(0xFFFF7A00);
// const _navy = Color(0xFF1B1464);
// const _ink = Color(0xFF1F2430);
// const _muted = Color(0xFF7A8194);
// const _line = Color(0xFFE6E9F2);
// const _bg = Color(0xFFF6F7FB);
// const _red = Color(0xFFD63638);
// const _green = Color(0xFF22B573);

// class _St {
//   final String label;
//   final Color color;
//   const _St(this.label, this.color);
// }

// /// Display statuses. 'paid' = accepted + depositPaid (derived).
// const _statuses = <String, _St>{
//   'pending': _St('New Request', Color(0xFF8A94A6)),
//   'reviewing': _St('Under Review', Color(0xFF2271B1)),
//   'quoted': _St('Quote Sent', Color(0xFFC99700)),
//   'changes_requested': _St('Changes Requested', Color(0xFFE67E22)),
//   'accepted': _St('Quote Accepted', Color(0xFF1F8A5B)),
//   'paid': _St('Deposit Paid', Color(0xFF22B573)),
//   'scheduled': _St('Scheduled', Color(0xFF1B1464)),
//   'completed': _St('Completed', Color(0xFF4F5D75)),
//   'rejected': _St('Declined', Color(0xFFD63638)),
//   'cancelled': _St('Cancelled', Color(0xFF828282)),
// };

// /// Cards on top (also work as filters).
// const _cardKeys = [
//   'pending',
//   'reviewing',
//   'quoted',
//   'accepted',
//   'paid',
//   'scheduled',
//   'rejected',
// ];

// /// Statuses the admin may set by hand ("Quote Sent" is set by sending a quote).
// const _manualStatuses = [
//   'pending',
//   'reviewing',
//   'accepted',
//   'paid',
//   'scheduled',
//   'completed',
//   'rejected',
//   'cancelled',
// ];

// const _svcIcons = <String, IconData>{
//   'Painting': Icons.format_paint_outlined,
//   'Moving': Icons.local_shipping_outlined,
//   'Cleaning': Icons.cleaning_services_outlined,
//   'Assembly': Icons.build_outlined,
//   'Lawn Services': Icons.grass_outlined,
//   'Waste Disposal': Icons.delete_outline,
//   'Pressure Washing': Icons.water_drop_outlined,
// };

// // ── Helpers ─────────────────────────────────────────────────
// const _mon = [
//   'Jan',
//   'Feb',
//   'Mar',
//   'Apr',
//   'May',
//   'Jun',
//   'Jul',
//   'Aug',
//   'Sep',
//   'Oct',
//   'Nov',
//   'Dec',
// ];

// String _money(num v) {
//   final p = v.toStringAsFixed(2).split('.');
//   final i = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
//   return '\$$i.${p[1]}';
// }

// String _d(DateTime d) => '${_mon[d.month - 1]} ${d.day}, ${d.year}';

// String _dt(DateTime d) {
//   final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
//   final m = d.minute.toString().padLeft(2, '0');
//   return '${_d(d)} • $h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
// }

// String _ago(DateTime d) {
//   final x = DateTime.now().difference(d);
//   if (x.inMinutes < 1) return 'just now';
//   if (x.inMinutes < 60) return '${x.inMinutes}m ago';
//   if (x.inHours < 24) return '${x.inHours}h ago';
//   if (x.inDays < 7) return '${x.inDays}d ago';
//   return _d(d);
// }

// double _r2(double v) => (v * 100).round() / 100;
// String _fmt(num v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';

// /// Tolerant number parser (num, "450", "$1,250.50", null).
// double _num(dynamic v) {
//   if (v is num) return v.toDouble();
//   return double.tryParse('$v'.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
// }

// double _p(TextEditingController c) => _num(c.text);

// void _toast(String msg, {bool error = false}) => Get.snackbar(
//   error ? 'Oops' : 'Done',
//   msg,
//   snackPosition: SnackPosition.BOTTOM,
//   margin: const EdgeInsets.all(16),
//   maxWidth: 520,
//   borderRadius: 14,
//   backgroundColor: error ? _red : _green,
//   colorText: Colors.white,
// );

// Future<void> _open(String url) async {
//   final u = Uri.tryParse(url);
//   if (u == null || !await launchUrl(u, mode: LaunchMode.externalApplication)) {
//     _toast('Could not open link', error: true);
//   }
// }

// OutlineInputBorder _ob(Color c, {double w = 1}) => OutlineInputBorder(
//   borderRadius: BorderRadius.circular(10),
//   borderSide: BorderSide(color: c, width: w),
// );

// InputDecoration _dec(
//   String? label, {
//   String? hint,
//   IconData? icon,
//   String? prefix,
//   String? suffix,
// }) => InputDecoration(
//   labelText: label,
//   hintText: hint,
//   prefixText: prefix,
//   suffixText: suffix,
//   prefixIcon: icon == null ? null : Icon(icon, size: 20, color: _muted),
//   isDense: true,
//   filled: true,
//   fillColor: Colors.white,
//   contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//   border: _ob(_line),
//   enabledBorder: _ob(_line),
//   focusedBorder: _ob(_orange, w: 1.6),
// );

// /// Solid pill, like the WordPress pipeline.
// Widget _chip(String status) {
//   final m = _statuses[status] ?? _St(status, Colors.grey);
//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
//     decoration: BoxDecoration(
//       color: m.color,
//       borderRadius: BorderRadius.circular(20),
//     ),
//     child: Text(
//       m.label,
//       style: const TextStyle(
//         color: Colors.white,
//         fontWeight: FontWeight.w800,
//         fontSize: 12,
//       ),
//     ),
//   );
// }

// Widget _box({required Widget child, EdgeInsets? pad}) => Container(
//   width: double.infinity,
//   padding: pad ?? const EdgeInsets.all(16),
//   decoration: BoxDecoration(
//     color: Colors.white,
//     borderRadius: BorderRadius.circular(14),
//     border: Border.all(color: _line),
//   ),
//   child: child,
// );

// Widget _heading(String t, {double top = 22}) => Padding(
//   padding: EdgeInsets.only(top: top, bottom: 8),
//   child: Text(
//     t,
//     style: const TextStyle(
//       fontWeight: FontWeight.w800,
//       fontSize: 14.5,
//       color: _ink,
//     ),
//   ),
// );

// // ── Data ────────────────────────────────────────────────────
// class _Req {
//   _Req(this.id, this.m);
//   final String id;
//   final Map<String, dynamic> m;
//   factory _Req.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
//       _Req(d.id, d.data() ?? {});

//   String s(String k) => (m[k] ?? '').toString();
//   String get number => s('requestNumber').isEmpty ? id : s('requestNumber');
//   String get name => s('customerName');
//   String get service => s('service');

//   String get rawStatus => s('status').isEmpty ? 'pending' : s('status');
//   bool get paid => m['depositPaid'] == true;

//   /// Status shown in the UI ('paid' is derived).
//   String get status => rawStatus == 'accepted' && paid ? 'paid' : rawStatus;

//   bool get canQuote => const [
//     'pending',
//     'reviewing',
//     'quoted',
//     'changes_requested',
//   ].contains(rawStatus);

//   double get budget => _num(m['budget']);
//   DateTime? get preferred => (m['preferredDate'] as Timestamp?)?.toDate();
//   DateTime? get created => (m['createdAt'] as Timestamp?)?.toDate();
//   String? get quoteId => m['quoteId'] as String?;

//   Map<String, dynamic> get quote =>
//       m['quote'] is Map ? Map<String, dynamic>.from(m['quote']) : {};
//   double get quoteTotal {
//     final t = _num(quote['total']);
//     return t > 0 ? t : _num(m['quoteAmount']);
//   }

//   double get deposit => _num(quote['deposit']);

//   /// "$100.00 / $20.00" like the pipeline table.
//   String get amountText => quoteTotal <= 0
//       ? '—'
//       : '${_money(quoteTotal)} / ${deposit > 0 ? _money(deposit) : '—'}';

//   List<Map<String, dynamic>> get files => _list('attachments');
//   List<Map<String, dynamic>> get history => _list('statusHistory');
//   List<Map<String, dynamic>> _list(String k) => ((m[k] as List?) ?? [])
//       .whereType<Map>()
//       .map((e) => Map<String, dynamic>.from(e))
//       .toList();
// }

// class _Api {
//   static final db = FirebaseFirestore.instance;
//   static DocumentReference<Map<String, dynamic>> req(String id) =>
//       db.collection('quote_requests').doc(id);
//   static String get me => FirebaseAuth.instance.currentUser?.email ?? 'admin';

//   static Map<String, dynamic> historyEntry(String status, {String note = ''}) =>
//       {
//         'status': status,
//         'at': Timestamp.now(),
//         'by': me,
//         if (note.isNotEmpty) 'note': note,
//       };

//   /// Sets a status. 'paid' = approved + deposit marked as paid.
//   static Future<void> setStatus(_Req r, String key) async {
//     final isPaid = key == 'paid';
//     final status = isPaid ? 'accepted' : key;
//     await req(r.id).update({
//       'status': status,
//       if (isPaid) ...{
//         'depositPaid': true,
//         'depositPaidAt': FieldValue.serverTimestamp(),
//         'paymentMethod': 'admin',
//       },
//       'updatedAt': FieldValue.serverTimestamp(),
//       'statusHistory': FieldValue.arrayUnion([
//         historyEntry(status, note: isPaid ? 'Deposit marked as paid' : ''),
//       ]),
//     });
//     await notify(
//       r,
//       'Request update',
//       'Your ${r.service} request is now ${_statuses[key]?.label ?? key}.',
//       'request',
//     );
//   }

//   /// In-app notification doc (a Cloud Function can turn this into a push).
//   static Future<void> notify(
//     _Req r,
//     String title,
//     String body,
//     String type, {
//     String? quoteId,
//   }) async {
//     final uid = r.s('userId');
//     if (uid.isEmpty) return;
//     try {
//       await db.collection('notifications').add({
//         'userId': uid,
//         'title': title,
//         'body': body,
//         'type': type,
//         'requestId': r.id,
//         'quoteId': quoteId,
//         'read': false,
//         'createdAt': FieldValue.serverTimestamp(),
//       });
//     } catch (_) {}
//   }
// }

// // =============================================================
// // PAGE
// // =============================================================
// class RequestsPage extends StatefulWidget {
//   const RequestsPage({super.key});
//   @override
//   State<RequestsPage> createState() => _RequestsPageState();
// }

// class _RequestsPageState extends State<RequestsPage> {
//   late final Stream<List<_Req>> _stream = FirebaseFirestore.instance
//       .collection('quote_requests')
//       .orderBy('createdAt', descending: true)
//       .snapshots()
//       .map((s) => s.docs.map(_Req.fromDoc).toList());

//   String? _filter; // null = all
//   String _q = '';

//   @override
//   Widget build(BuildContext context) => PageScaffold(
//     title: 'Quote Pipeline',
//     subtitle: 'Review requests, send a quote, and track payment',
//     children: [
//       StreamBuilder<List<_Req>>(
//         stream: _stream,
//         builder: (context, snap) {
//           if (snap.hasError) {
//             return Padding(
//               padding: const EdgeInsets.all(24),
//               child: SelectableText('Could not load requests.\n${snap.error}'),
//             );
//           }
//           if (!snap.hasData) {
//             return const Padding(
//               padding: EdgeInsets.all(40),
//               child: Center(child: CircularProgressIndicator()),
//             );
//           }
//           final all = snap.data!;
//           int count(String k) => all.where((r) => r.status == k).length;
//           final q = _q.toLowerCase();
//           final list = all.where((r) {
//             if (_filter != null && r.status != _filter) return false;
//             if (q.isEmpty) return true;
//             return '${r.name} ${r.number} ${r.service} ${r.s('phone')} ${r.s('email')} ${r.s('address')}'
//                 .toLowerCase()
//                 .contains(q);
//           }).toList();

//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _stats(count),
//               const SizedBox(height: 22),
//               Row(
//                 children: [
//                   Expanded(
//                     child: Text(
//                       _filter == null
//                           ? 'Recent requests'
//                           : _statuses[_filter]!.label,
//                       style: const TextStyle(
//                         fontSize: 19,
//                         fontWeight: FontWeight.w900,
//                         color: _ink,
//                       ),
//                     ),
//                   ),
//                   if (_filter != null)
//                     TextButton(
//                       onPressed: () => setState(() => _filter = null),
//                       child: const Text('Show all'),
//                     ),
//                 ],
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 onChanged: (v) => setState(() => _q = v),
//                 decoration: _dec(
//                   null,
//                   hint: 'Search name, reference, service, phone, address',
//                   icon: Icons.search,
//                 ),
//               ),
//               const SizedBox(height: 14),
//               if (list.isEmpty)
//                 const Padding(
//                   padding: EdgeInsets.symmetric(vertical: 48),
//                   child: Center(
//                     child: Text(
//                       'No requests found',
//                       style: TextStyle(color: _muted),
//                     ),
//                   ),
//                 )
//               else
//                 LayoutBuilder(
//                   builder: (_, b) =>
//                       b.maxWidth >= 820 ? _table(list) : _cards(list),
//                 ),
//             ],
//           );
//         },
//       ),
//     ],
//   );

//   // ── stat cards (tap = filter) ──
//   Widget _stats(int Function(String) count) => LayoutBuilder(
//     builder: (_, b) {
//       final cols = b.maxWidth >= 1100 ? 7 : (b.maxWidth >= 760 ? 4 : 2);
//       const gap = 10.0;
//       final w = (b.maxWidth - gap * (cols - 1)) / cols;
//       return Wrap(
//         spacing: gap,
//         runSpacing: gap,
//         children: [
//           for (final k in _cardKeys)
//             SizedBox(
//               width: w,
//               child: _StatCard(
//                 label: _statuses[k]!.label,
//                 count: count(k),
//                 color: _statuses[k]!.color,
//                 selected: _filter == k,
//                 onTap: () => setState(() => _filter = _filter == k ? null : k),
//               ),
//             ),
//         ],
//       );
//     },
//   );

//   // ── wide layout: table ──
//   Widget _table(List<_Req> list) {
//     const head = TextStyle(fontWeight: FontWeight.w700, color: _ink);
//     Widget cell(int flex, Widget w) => Expanded(flex: flex, child: w);
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: _line),
//       ),
//       clipBehavior: Clip.antiAlias,
//       child: Column(
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//             child: Row(
//               children: [
//                 cell(2, const Text('Reference', style: head)),
//                 cell(2, const Text('Customer', style: head)),
//                 cell(2, const Text('Service', style: head)),
//                 cell(2, const Text('Quoted / Deposit', style: head)),
//                 cell(2, const Text('Status', style: head)),
//                 cell(2, const Text('Submitted', style: head)),
//                 const SizedBox(width: 56),
//               ],
//             ),
//           ),
//           const Divider(height: 1, color: _line),
//           for (var i = 0; i < list.length; i++)
//             InkWell(
//               onTap: () => openRequestById(context, list[i].id),
//               child: Container(
//                 color: i.isOdd ? _bg : Colors.white,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 16,
//                   vertical: 14,
//                 ),
//                 child: Row(
//                   children: [
//                     cell(
//                       2,
//                       Text(
//                         list[i].number,
//                         style: const TextStyle(
//                           fontWeight: FontWeight.w800,
//                           color: _ink,
//                         ),
//                       ),
//                     ),
//                     cell(
//                       2,
//                       Text(
//                         list[i].name.isEmpty ? 'Customer' : list[i].name,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     cell(
//                       2,
//                       Text(list[i].service, overflow: TextOverflow.ellipsis),
//                     ),
//                     cell(2, Text(list[i].amountText)),
//                     cell(
//                       2,
//                       Align(
//                         alignment: Alignment.centerLeft,
//                         child: _chip(list[i].status),
//                       ),
//                     ),
//                     cell(
//                       2,
//                       Text(
//                         list[i].created == null ? '—' : _d(list[i].created!),
//                         style: const TextStyle(color: _muted),
//                       ),
//                     ),
//                     const SizedBox(
//                       width: 56,
//                       child: Text(
//                         'View',
//                         style: TextStyle(
//                           color: Color(0xFF2271B1),
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   // ── narrow layout: cards ──
//   Widget _cards(List<_Req> list) =>
//       Column(children: [for (final r in list) _tile(r)]);

//   Widget _tile(_Req r) {
//     final icon = _svcIcons[r.service] ?? Icons.handyman_outlined;
//     final color = _statuses[r.status]?.color ?? _orange;
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 10),
//       child: Material(
//         color: Colors.white,
//         clipBehavior: Clip.antiAlias,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(14),
//           side: const BorderSide(color: _line),
//         ),
//         child: InkWell(
//           onTap: () => openRequestById(context, r.id),
//           child: Padding(
//             padding: const EdgeInsets.all(14),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Container(
//                       width: 42,
//                       height: 42,
//                       decoration: BoxDecoration(
//                         color: color.withValues(alpha: .12),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Icon(icon, color: color, size: 22),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             r.name.isEmpty ? 'Customer' : r.name,
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: const TextStyle(
//                               fontWeight: FontWeight.w800,
//                               fontSize: 15,
//                               color: _ink,
//                             ),
//                           ),
//                           Text(
//                             '${r.number} • ${r.service}',
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: const TextStyle(
//                               color: _muted,
//                               fontSize: 12.5,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     _chip(r.status),
//                   ],
//                 ),
//                 const SizedBox(height: 10),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         r.quoteTotal > 0
//                             ? 'Quote ${r.amountText}'
//                             : 'Budget ${_money(r.budget)}',
//                         style: const TextStyle(
//                           fontWeight: FontWeight.w700,
//                           color: _ink,
//                         ),
//                       ),
//                     ),
//                     Text(
//                       r.created == null ? '' : _ago(r.created!),
//                       style: const TextStyle(color: _muted, fontSize: 12.5),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _StatCard extends StatelessWidget {
//   const _StatCard({
//     required this.label,
//     required this.count,
//     required this.color,
//     required this.selected,
//     required this.onTap,
//   });
//   final String label;
//   final int count;
//   final Color color;
//   final bool selected;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) => Material(
//     color: Colors.white,
//     clipBehavior: Clip.antiAlias,
//     shape: RoundedRectangleBorder(
//       borderRadius: BorderRadius.circular(12),
//       side: BorderSide(
//         color: selected ? color : _line,
//         width: selected ? 1.8 : 1,
//       ),
//     ),
//     child: InkWell(
//       onTap: onTap,
//       child: IntrinsicHeight(
//         child: Row(
//           children: [
//             Container(width: 5, color: color),
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 14,
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       '$count',
//                       style: const TextStyle(
//                         fontSize: 26,
//                         height: 1.1,
//                         fontWeight: FontWeight.w900,
//                         color: _navy,
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       label,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         color: _ink,
//                         fontWeight: FontWeight.w600,
//                         fontSize: 12.5,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );
// }

// /// Public entry point (use from the dashboard etc.).
// void openRequestById(BuildContext context, String id) => showDialog(
//   context: context,
//   builder: (_) => _RequestDialog(id: id),
// );

// // =============================================================
// // REQUEST DETAIL DIALOG
// // =============================================================
// class _RequestDialog extends StatefulWidget {
//   const _RequestDialog({required this.id});
//   final String id;
//   @override
//   State<_RequestDialog> createState() => _RequestDialogState();
// }

// class _RequestDialogState extends State<_RequestDialog> {
//   late final Stream<DocumentSnapshot<Map<String, dynamic>>> _s = _Api.req(
//     widget.id,
//   ).snapshots();
//   final _note = TextEditingController();
//   bool _noteInit = false;

//   @override
//   void dispose() {
//     _note.dispose();
//     super.dispose();
//   }

//   Future<void> _saveNote() async {
//     try {
//       await _Api.req(widget.id).update({
//         'adminNote': _note.text.trim(),
//         'updatedAt': FieldValue.serverTimestamp(),
//       });
//       _toast('Note saved');
//     } catch (_) {
//       _toast('Could not save note', error: true);
//     }
//   }

//   @override
//   Widget build(BuildContext context) => Dialog(
//     backgroundColor: _bg,
//     insetPadding: const EdgeInsets.all(12),
//     clipBehavior: Clip.antiAlias,
//     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//     child: ConstrainedBox(
//       constraints: BoxConstraints(
//         maxWidth: 1000,
//         maxHeight: MediaQuery.of(context).size.height * .94,
//       ),
//       child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//         stream: _s,
//         builder: (context, snap) {
//           if (snap.hasError) {
//             return Padding(
//               padding: const EdgeInsets.all(24),
//               child: SelectableText('${snap.error}'),
//             );
//           }
//           if (!snap.hasData) {
//             return const SizedBox(
//               height: 220,
//               child: Center(child: CircularProgressIndicator()),
//             );
//           }
//           if (!snap.data!.exists) {
//             return const Padding(
//               padding: EdgeInsets.all(32),
//               child: Text('Request not found'),
//             );
//           }
//           final r = _Req.fromDoc(snap.data!);
//           if (!_noteInit) {
//             _note.text = r.s('adminNote');
//             _noteInit = true;
//           }
//           return Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               _header(r),
//               Flexible(
//                 child: SingleChildScrollView(
//                   padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
//                   child: LayoutBuilder(
//                     builder: (_, b) {
//                       final panel = _StatusPanel(key: ValueKey(r.id), r: r);
//                       final details = _details(r);
//                       if (b.maxWidth < 760) {
//                         return Column(
//                           children: [
//                             panel,
//                             const SizedBox(height: 16),
//                             details,
//                           ],
//                         );
//                       }
//                       return Row(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Expanded(child: details),
//                           const SizedBox(width: 16),
//                           SizedBox(width: 340, child: panel),
//                         ],
//                       );
//                     },
//                   ),
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     ),
//   );

//   Widget _header(_Req r) => Container(
//     color: Colors.white,
//     padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
//     child: Row(
//       children: [
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 '${r.number} — ${r.name.isEmpty ? 'Customer' : r.name}',
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   fontSize: 19,
//                   fontWeight: FontWeight.w900,
//                   color: _ink,
//                 ),
//               ),
//               Text(
//                 r.created == null
//                     ? r.service
//                     : '${r.service} • ${_ago(r.created!)}',
//                 style: const TextStyle(color: _muted, fontSize: 12.5),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(width: 8),
//         _chip(r.status),
//         IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: const Icon(Icons.close),
//         ),
//       ],
//     ),
//   );

//   // ── request details ──
//   Widget _row(String k, String v, int i, {String? uri}) => Container(
//     color: i.isOdd ? _bg : Colors.white,
//     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
//     child: Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         SizedBox(
//           width: 120,
//           child: Text(k, style: const TextStyle(color: _muted)),
//         ),
//         Expanded(child: SelectableText(v.isEmpty ? '—' : v)),
//         if (uri != null && v.isNotEmpty)
//           InkWell(
//             onTap: () => _open(uri),
//             child: const Padding(
//               padding: EdgeInsets.only(left: 8),
//               child: Icon(Icons.open_in_new, size: 17, color: _orange),
//             ),
//           ),
//       ],
//     ),
//   );

//   Widget _details(_Req r) {
//     final pref = r.preferred == null ? '' : _d(r.preferred!);
//     final rows = <(String, String, String?)>[
//       ('Reference', r.number, null),
//       ('Full name', r.name, null),
//       ('Phone', r.s('phone'), 'tel:${r.s('phone')}'),
//       ('Email', r.s('email'), 'mailto:${r.s('email')}'),
//       ('Service needed', r.service, null),
//       ('Job description', r.s('description'), null),
//       ('Job address', r.s('address'), null),
//       ('Preferred date', pref, null),
//       ('Preferred time', r.s('preferredSlot'), null),
//       ('Urgency', r.s('urgency'), null),
//       ('Customer budget', r.budget > 0 ? _money(r.budget) : '', null),
//     ];
//     final cNote = r.s('customerNote');

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Container(
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(14),
//             border: Border.all(color: _line),
//           ),
//           clipBehavior: Clip.antiAlias,
//           child: Column(
//             children: [
//               for (var i = 0; i < rows.length; i++)
//                 _row(rows[i].$1, rows[i].$2, i, uri: rows[i].$3),
//             ],
//           ),
//         ),
//         if (cNote.isNotEmpty) ...[
//           _heading('Message from customer'),
//           _box(child: Text('"$cNote"', style: const TextStyle(height: 1.4))),
//         ],
//         _heading('Uploaded files (${r.files.length})'),
//         _files(r),
//         _heading('Internal note (not shown to customer)'),
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             TextField(
//               controller: _note,
//               maxLines: 3,
//               decoration: _dec(null, hint: 'Site visit details, reminders…'),
//             ),
//             const SizedBox(height: 8),
//             OutlinedButton(
//               onPressed: _saveNote,
//               child: const Text('Save note'),
//             ),
//           ],
//         ),
//         if (r.history.isNotEmpty) ...[_heading('Activity'), _timeline(r)],
//       ],
//     );
//   }

//   Widget _files(_Req r) {
//     if (r.files.isEmpty) {
//       return const Text(
//         'No files were attached to this request.',
//         style: TextStyle(color: _muted, fontStyle: FontStyle.italic),
//       );
//     }
//     return Wrap(
//       spacing: 10,
//       runSpacing: 10,
//       children: [
//         for (final f in r.files)
//           () {
//             final url = '${f['url'] ?? ''}';
//             final type = '${f['type'] ?? ''}';
//             final isImg = type == 'image';
//             return InkWell(
//               borderRadius: BorderRadius.circular(12),
//               onTap: () => isImg ? _viewImage(url) : _open(url),
//               child: Container(
//                 width: 96,
//                 height: 96,
//                 clipBehavior: Clip.antiAlias,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: _line),
//                 ),
//                 child: isImg
//                     ? Image.network(
//                         url,
//                         fit: BoxFit.cover,
//                         errorBuilder: (_, __, ___) => const Center(
//                           child: Icon(
//                             Icons.broken_image_outlined,
//                             color: _muted,
//                           ),
//                         ),
//                       )
//                     : Padding(
//                         padding: const EdgeInsets.all(8),
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(
//                               type == 'video'
//                                   ? Icons.play_circle_outline
//                                   : Icons.insert_drive_file_outlined,
//                               color: _orange,
//                               size: 28,
//                             ),
//                             const SizedBox(height: 6),
//                             Text(
//                               '${f['name'] ?? 'file'}',
//                               maxLines: 2,
//                               overflow: TextOverflow.ellipsis,
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(fontSize: 11),
//                             ),
//                           ],
//                         ),
//                       ),
//               ),
//             );
//           }(),
//       ],
//     );
//   }

//   void _viewImage(String url) => showDialog(
//     context: context,
//     builder: (ctx) => Dialog(
//       backgroundColor: Colors.black,
//       insetPadding: const EdgeInsets.all(12),
//       child: Stack(
//         children: [
//           InteractiveViewer(
//             child: Center(child: Image.network(url, fit: BoxFit.contain)),
//           ),
//           Positioned(
//             top: 4,
//             right: 4,
//             child: IconButton(
//               onPressed: () => Navigator.pop(ctx),
//               icon: const Icon(Icons.close, color: Colors.white),
//             ),
//           ),
//         ],
//       ),
//     ),
//   );

//   Widget _timeline(_Req r) => Column(
//     children: [
//       for (final h in r.history.reversed)
//         Padding(
//           padding: const EdgeInsets.symmetric(vertical: 4),
//           child: Row(
//             children: [
//               Container(
//                 width: 9,
//                 height: 9,
//                 decoration: BoxDecoration(
//                   color: _statuses['${h['status']}']?.color ?? _muted,
//                   shape: BoxShape.circle,
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Text(
//                 _statuses['${h['status']}']?.label ?? '${h['status']}',
//                 style: const TextStyle(fontWeight: FontWeight.w700),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   '${h['by'] == 'customer' ? 'Customer' : (h['by'] ?? '')}'
//                   '${h['at'] is Timestamp ? ' • ${_dt((h['at'] as Timestamp).toDate())}' : ''}'
//                   '${'${h['note'] ?? ''}'.isEmpty ? '' : ' • ${h['note']}'}',
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(color: _muted, fontSize: 12),
//                 ),
//               ),
//             ],
//           ),
//         ),
//     ],
//   );
// }

// // =============================================================
// // STATUS & QUOTE PANEL  (simple: status + amount + deposit)
// // =============================================================
// class _StatusPanel extends StatefulWidget {
//   const _StatusPanel({super.key, required this.r});
//   final _Req r;
//   @override
//   State<_StatusPanel> createState() => _StatusPanelState();
// }

// class _StatusPanelState extends State<_StatusPanel> {
//   final _amount = TextEditingController();
//   final _depositVal = TextEditingController(text: '20');
//   final _notes = TextEditingController();
//   String _depositType = 'percent'; // percent | fixed
//   DateTime _expires = DateTime.now().add(const Duration(days: 14));
//   String? _sel;
//   bool _busy = false;

//   _Req get r => widget.r;

//   @override
//   void initState() {
//     super.initState();
//     final q = r.quote;
//     if (r.quoteTotal > 0) _amount.text = _fmt(r.quoteTotal);
//     if (q['depositType'] != null) _depositType = '${q['depositType']}';
//     if (_num(q['depositValue']) > 0)
//       _depositVal.text = _fmt(_num(q['depositValue']));
//     if (q['expiresAt'] is Timestamp) {
//       _expires = (q['expiresAt'] as Timestamp).toDate();
//     }
//     _notes.text = '${q['notes'] ?? ''}';
//   }

//   @override
//   void dispose() {
//     _amount.dispose();
//     _depositVal.dispose();
//     _notes.dispose();
//     super.dispose();
//   }

//   // ── calculations ──
//   double get _total => _r2(_p(_amount));
//   double get _deposit => _depositType == 'percent'
//       ? _r2(_total * _p(_depositVal).clamp(0.0, 100.0) / 100)
//       : _r2(_p(_depositVal).clamp(0.0, _total).toDouble());
//   double get _balance => _r2(_total - _deposit);

//   Future<void> _updateStatus() async {
//     final s = _sel;
//     if (s == null) return;
//     setState(() => _busy = true);
//     try {
//       await _Api.setStatus(r, s);
//       _toast('Status: ${_statuses[s]?.label ?? s}');
//       _sel = null;
//     } catch (_) {
//       _toast('Could not update status. Check permissions.', error: true);
//     }
//     if (mounted) setState(() => _busy = false);
//   }

//   Future<void> _pickDate() async {
//     final now = DateTime.now();
//     final d = await showDatePicker(
//       context: context,
//       initialDate: _expires.isBefore(now) ? now : _expires,
//       firstDate: now,
//       lastDate: now.add(const Duration(days: 365)),
//     );
//     if (d != null) setState(() => _expires = d);
//   }

//   Future<void> _send() async {
//     if (_total <= 0) {
//       _toast('Enter the quoted amount', error: true);
//       return;
//     }
//     setState(() => _busy = true);
//     try {
//       final quotes = _Api.db.collection('quotes');
//       final isNew = r.quoteId == null;
//       final ref = isNew ? quotes.doc() : quotes.doc(r.quoteId);
//       final digits = r.number.replaceAll(RegExp(r'[^0-9]'), '');
//       final expiresAt = Timestamp.fromDate(
//         DateTime(_expires.year, _expires.month, _expires.day, 23, 59),
//       );
//       final pct = _total > 0 ? _r2(_deposit / _total * 100) : 0.0;

//       // 1) the quote the customer app reads (on the request itself)
//       final quote = {
//         'total': _total,
//         'deposit': _deposit,
//         'depositPct': pct,
//         'depositType': _depositType,
//         'depositValue': _p(_depositVal),
//         'notes': _notes.text.trim(),
//         'issuedAt': Timestamp.now(),
//         'expiresAt': expiresAt,
//       };

//       // 2) copy in `quotes` collection
//       await ref.set({
//         'id': ref.id,
//         'quoteNumber': 'QT-${digits.isEmpty ? r.id.substring(0, 6) : digits}',
//         'requestId': r.id,
//         'requestNumber': r.number,
//         'userId': r.s('userId'),
//         'customerName': r.name,
//         'email': r.s('email'),
//         'phone': r.s('phone'),
//         'service': r.service,
//         ...quote,
//         'balance': _balance,
//         'status': 'sent',
//         'createdBy': _Api.me,
//         'updatedAt': FieldValue.serverTimestamp(),
//         if (isNew) 'createdAt': FieldValue.serverTimestamp(),
//       }, SetOptions(merge: true));

//       // 3) update the request -> customer sees amount + deposit live
//       await _Api.req(r.id).update({
//         'status': 'quoted',
//         'quoteAmount': _total,
//         'quoteId': ref.id,
//         'quote': quote,
//         'updatedAt': FieldValue.serverTimestamp(),
//         'statusHistory': FieldValue.arrayUnion([
//           _Api.historyEntry('quoted', note: 'Quote ${_money(_total)}'),
//         ]),
//       });

//       await _Api.notify(
//         r,
//         isNew ? 'Quote received' : 'Quote updated',
//         'Your ${r.service} quote is ready: ${_money(_total)}. '
//             'Deposit due: ${_money(_deposit)}.',
//         'quote',
//         quoteId: ref.id,
//       );
//       _toast(isNew ? 'Quote sent to customer' : 'Quote updated and resent');
//     } on FirebaseException catch (e) {
//       _toast(e.message ?? 'Could not save quote', error: true);
//     } catch (_) {
//       _toast('Something went wrong. Please try again.', error: true);
//     }
//     if (mounted) setState(() => _busy = false);
//   }

//   Widget _label(String t) => Padding(
//     padding: const EdgeInsets.only(bottom: 6),
//     child: Text(
//       t,
//       style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
//     ),
//   );

//   @override
//   Widget build(BuildContext context) {
//     final items = [
//       ..._manualStatuses,
//       if (!_manualStatuses.contains(r.status)) r.status,
//     ];

//     return _box(
//       pad: const EdgeInsets.all(18),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Status & Quote',
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.w900,
//               color: _ink,
//             ),
//           ),
//           const SizedBox(height: 14),
//           _label('Current status'),
//           Align(alignment: Alignment.centerLeft, child: _chip(r.status)),
//           const SizedBox(height: 16),

//           // ── set status ──
//           _label('Set status'),
//           DropdownButtonFormField<String>(
//             value: _sel ?? r.status,
//             isExpanded: true,
//             decoration: _dec(null),
//             items: [
//               for (final k in items)
//                 DropdownMenuItem(
//                   value: k,
//                   child: Text(_statuses[k]?.label ?? k),
//                 ),
//             ],
//             onChanged: _busy ? null : (v) => setState(() => _sel = v),
//           ),
//           const SizedBox(height: 10),
//           OutlinedButton(
//             onPressed: (_busy || _sel == null || _sel == r.status)
//                 ? null
//                 : _updateStatus,
//             child: const Text('Update status'),
//           ),

//           const Divider(height: 34, color: _line),

//           // ── payment received info ──
//           if (r.paid) ...[
//             Container(
//               width: double.infinity,
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: _green.withValues(alpha: .1),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Row(
//                 children: [
//                   const Icon(Icons.verified_rounded, color: _green),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: Text(
//                       'Deposit paid'
//                       '${r.deposit > 0 ? ' · ${_money(r.deposit)}' : ''}'
//                       '${r.s('paymentMethod').isEmpty ? '' : ' · ${r.s('paymentMethod')}'}'
//                       '${r.s('paymentRef').isEmpty ? '' : '\nRef: ${r.s('paymentRef')}'}',
//                       style: const TextStyle(
//                         fontWeight: FontWeight.w700,
//                         height: 1.35,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 16),
//           ],

//           // ── quote ──
//           if (!r.canQuote)
//             Text(
//               r.quoteTotal > 0
//                   ? 'Quote: ${r.amountText}\n(Quote is locked after the customer responds.)'
//                   : 'A quote can be sent while the request is new, in review, or quoted.',
//               style: const TextStyle(color: _muted, height: 1.4),
//             )
//           else ...[
//             _label('Quoted amount (\$)'),
//             TextField(
//               controller: _amount,
//               keyboardType: const TextInputType.numberWithOptions(
//                 decimal: true,
//               ),
//               onChanged: (_) => setState(() {}),
//               decoration: _dec(null, hint: '0.00', prefix: '\$ '),
//             ),
//             const SizedBox(height: 14),
//             _label('Deposit (payable in advance)'),
//             Row(
//               children: [
//                 Expanded(
//                   flex: 5,
//                   child: DropdownButtonFormField<String>(
//                     value: _depositType,
//                     isExpanded: true,
//                     decoration: _dec(null),
//                     items: const [
//                       DropdownMenuItem(
//                         value: 'percent',
//                         child: Text('% of quote'),
//                       ),
//                       DropdownMenuItem(value: 'fixed', child: Text('Fixed \$')),
//                     ],
//                     onChanged: (v) => setState(() {
//                       _depositType = v!;
//                       _depositVal.text = v == 'percent' ? '20' : '';
//                     }),
//                   ),
//                 ),
//                 const SizedBox(width: 10),
//                 Expanded(
//                   flex: 4,
//                   child: TextField(
//                     controller: _depositVal,
//                     keyboardType: const TextInputType.numberWithOptions(
//                       decimal: true,
//                     ),
//                     onChanged: (_) => setState(() {}),
//                     decoration: _dec(null),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),

//             // live preview
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: _bg,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Column(
//                 children: [
//                   _sum('Total', _money(_total)),
//                   _sum(
//                     'Pay in advance',
//                     _money(_deposit),
//                     color: _orange,
//                     bold: true,
//                   ),
//                   _sum('After the job', _money(_balance)),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 14),
//             _label('Valid until'),
//             OutlinedButton.icon(
//               onPressed: _pickDate,
//               icon: const Icon(Icons.event, size: 18),
//               label: Text(_d(_expires)),
//             ),
//             const SizedBox(height: 14),
//             _label('Note for customer (optional)'),
//             TextField(
//               controller: _notes,
//               maxLines: 2,
//               decoration: _dec(
//                 null,
//                 hint: 'Scope, materials included, timeline…',
//               ),
//             ),
//             const SizedBox(height: 16),
//             SizedBox(
//               width: double.infinity,
//               height: 48,
//               child: ElevatedButton.icon(
//                 onPressed: _busy ? null : _send,
//                 icon: _busy
//                     ? const SizedBox(
//                         width: 16,
//                         height: 16,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                     : const Icon(Icons.send_rounded, size: 18),
//                 label: Text(
//                   r.quoteId == null
//                       ? 'Save & send quote to customer'
//                       : 'Update & resend quote',
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 style: ElevatedButton.styleFrom(
//                   elevation: 0,
//                   backgroundColor: const Color(0xFF2145E6),
//                   foregroundColor: Colors.white,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 10),
//             const Text(
//               'The customer is notified in the app and can review, approve and pay the deposit online.',
//               style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _sum(String k, String v, {Color? color, bool bold = false}) => Padding(
//     padding: const EdgeInsets.symmetric(vertical: 3),
//     child: Row(
//       children: [
//         Text(k, style: const TextStyle(color: _muted)),
//         const Spacer(),
//         Text(
//           v,
//           style: TextStyle(
//             fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
//             color: color ?? _ink,
//           ),
//         ),
//       ],
//     ),
//   );
// }

// // // =============================================================
// // // requests_page.dart — Admin: Quote Requests + Quote Builder
// // //
// // // Firestore:
// // //   quote_requests/{id}  (written by the customer app)
// // //   quotes/{id}          (written here when admin sends a quote)
// // //   notifications/{id}   (in-app notification for the customer)
// // // Storage: quotes/{requestId}/{quoteId}/{file}
// // //
// // // Extra packages: cloud_firestore, firebase_auth, firebase_storage,
// // //                 file_picker, url_launcher, get
// // // =============================================================
// // import 'dart:typed_data';

// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:file_picker/file_picker.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:firebase_storage/firebase_storage.dart';
// // import 'package:flutter/material.dart';
// // import 'package:get/get.dart';
// // // ignore: depend_on_referenced_packages
// // import 'package:url_launcher/url_launcher.dart';

// // import '../../widgets/widgets.dart';

// // // ── Tokens ──────────────────────────────────────────────────
// // const _orange = Color(0xFFFF7A00);
// // const _navy = Color(0xFF1B1464);
// // const _ink = Color(0xFF1F2430);
// // const _muted = Color(0xFF7A8194);
// // const _line = Color(0xFFE6E9F2);
// // const _bg = Color(0xFFF6F7FB);
// // const _red = Color(0xFFEB5757);
// // const _green = Color(0xFF22B573);

// // class _St {
// //   final String label;
// //   final Color color;
// //   const _St(this.label, this.color);
// // }

// // /// Status values match the customer app (QuoteStatus).
// // const _statuses = <String, _St>{
// //   'pending': _St('New', Color(0xFFFF7A00)),
// //   'reviewing': _St('In Review', Color(0xFF2D9CDB)),
// //   'quoted': _St('Quoted', Color(0xFF9B51E0)),
// //   'accepted': _St('Approved', Color(0xFF22B573)),
// //   'scheduled': _St('Scheduled', Color(0xFF00A3A3)),
// //   'completed': _St('Completed', Color(0xFF4F5D75)),
// //   'rejected': _St('Declined', Color(0xFFEB5757)),
// //   'cancelled': _St('Cancelled', Color(0xFF828282)),
// // };
// // const _manualStatuses = [
// //   'pending',
// //   'reviewing',
// //   'accepted',
// //   'scheduled',
// //   'completed',
// //   'rejected',
// //   'cancelled',
// // ];
// // const _filters = <String, List<String>>{
// //   'All': [],
// //   'New': ['pending'],
// //   'In Review': ['reviewing'],
// //   'Quoted': ['quoted'],
// //   'Approved': ['accepted'],
// //   'Scheduled': ['scheduled'],
// //   'Closed': ['completed', 'rejected', 'cancelled'],
// // };
// // const _svc = <String, (IconData, Color)>{
// //   'Painting': (Icons.format_paint_outlined, Color(0xFFEB5757)),
// //   'Moving': (Icons.local_shipping_outlined, Color(0xFF4F5D75)),
// //   'Cleaning': (Icons.cleaning_services_outlined, Color(0xFF27AE60)),
// //   'Assembly': (Icons.build_outlined, Color(0xFF9B51E0)),
// //   'Lawn Services': (Icons.grass_outlined, Color(0xFF6FCF97)),
// //   'Waste Disposal': (Icons.delete_outline, Color(0xFF828282)),
// //   'Pressure Washing': (Icons.water_drop_outlined, Color(0xFF56CCF2)),
// //   'General Handyman': (Icons.handyman_outlined, Color(0xFF2D9CDB)),
// // };
// // const _cats = [
// //   'Labor',
// //   'Materials',
// //   'Equipment',
// //   'Disposal fee',
// //   'Travel / service fee',
// //   'Other',
// // ];
// // const _defaultTerms =
// //     'This quote is valid until the expiration date. A deposit is required to '
// //     'schedule the job and the remaining balance is due on completion. Changes '
// //     'to the scope of work may change the final price.';

// // // ── Helpers ─────────────────────────────────────────────────
// // const _mon = [
// //   'Jan',
// //   'Feb',
// //   'Mar',
// //   'Apr',
// //   'May',
// //   'Jun',
// //   'Jul',
// //   'Aug',
// //   'Sep',
// //   'Oct',
// //   'Nov',
// //   'Dec',
// // ];

// // String _money(num v) {
// //   final p = v.toStringAsFixed(2).split('.');
// //   final i = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
// //   return '\$$i.${p[1]}';
// // }

// // String _d(DateTime d) => '${_mon[d.month - 1]} ${d.day}, ${d.year}';

// // String _dt(DateTime d) {
// //   final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
// //   final m = d.minute.toString().padLeft(2, '0');
// //   return '${_d(d)} • $h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
// // }

// // String _ago(DateTime d) {
// //   final x = DateTime.now().difference(d);
// //   if (x.inMinutes < 1) return 'just now';
// //   if (x.inMinutes < 60) return '${x.inMinutes}m ago';
// //   if (x.inHours < 24) return '${x.inHours}h ago';
// //   if (x.inDays < 7) return '${x.inDays}d ago';
// //   return _d(d);
// // }

// // double _r2(double v) => (v * 100).round() / 100;
// // String _n(num v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';
// // double _p(TextEditingController c) =>
// //     double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

// // String _ctype(String name) {
// //   final e = name.contains('.') ? name.split('.').last.toLowerCase() : '';
// //   const m = {
// //     'jpg': 'image/jpeg',
// //     'jpeg': 'image/jpeg',
// //     'png': 'image/png',
// //     'gif': 'image/gif',
// //     'webp': 'image/webp',
// //     'pdf': 'application/pdf',
// //     'doc': 'application/msword',
// //     'docx':
// //         'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
// //     'txt': 'text/plain',
// //     'mp4': 'video/mp4',
// //     'mov': 'video/quicktime',
// //   };
// //   return m[e] ?? 'application/octet-stream';
// // }

// // void _toast(String msg, {bool error = false}) => Get.snackbar(
// //   error ? 'Oops' : 'Done',
// //   msg,
// //   snackPosition: SnackPosition.BOTTOM,
// //   margin: const EdgeInsets.all(16),
// //   borderRadius: 14,
// //   backgroundColor: error ? _red : _green,
// //   colorText: Colors.white,
// // );

// // Future<void> _open(String url) async {
// //   final u = Uri.tryParse(url);
// //   if (u == null || !await launchUrl(u, mode: LaunchMode.externalApplication)) {
// //     _toast('Could not open link', error: true);
// //   }
// // }

// // OutlineInputBorder _ob(Color c, {double w = 1}) => OutlineInputBorder(
// //   borderRadius: BorderRadius.circular(12),
// //   borderSide: BorderSide(color: c, width: w),
// // );

// // InputDecoration _dec(
// //   String? label, {
// //   String? hint,
// //   IconData? icon,
// //   String? prefix,
// //   String? suffix,
// // }) => InputDecoration(
// //   labelText: label,
// //   hintText: hint,
// //   prefixText: prefix,
// //   suffixText: suffix,
// //   prefixIcon: icon == null ? null : Icon(icon, size: 20, color: _muted),
// //   isDense: true,
// //   filled: true,
// //   fillColor: Colors.white,
// //   contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
// //   border: _ob(_line),
// //   enabledBorder: _ob(_line),
// //   focusedBorder: _ob(_orange, w: 1.6),
// // );

// // Widget _chip(String status) {
// //   final m = _statuses[status] ?? _St(status, Colors.grey);
// //   return Container(
// //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
// //     decoration: BoxDecoration(
// //       color: m.color.withValues(alpha: .12),
// //       borderRadius: BorderRadius.circular(20),
// //     ),
// //     child: Text(
// //       m.label,
// //       style: TextStyle(
// //         color: m.color,
// //         fontWeight: FontWeight.w800,
// //         fontSize: 12,
// //       ),
// //     ),
// //   );
// // }

// // Widget _sec(String title, Widget child) => Padding(
// //   padding: const EdgeInsets.only(top: 22),
// //   child: Column(
// //     crossAxisAlignment: CrossAxisAlignment.start,
// //     children: [
// //       Text(
// //         title,
// //         style: const TextStyle(
// //           fontWeight: FontWeight.w800,
// //           fontSize: 14,
// //           color: _ink,
// //         ),
// //       ),
// //       const SizedBox(height: 8),
// //       child,
// //     ],
// //   ),
// // );

// // // ── Data ────────────────────────────────────────────────────
// // class _Req {
// //   _Req(this.id, this.m);
// //   final String id;
// //   final Map<String, dynamic> m;
// //   factory _Req.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
// //       _Req(d.id, d.data() ?? {});

// //   String s(String k) => (m[k] ?? '').toString();
// //   String get number => s('requestNumber').isEmpty ? id : s('requestNumber');
// //   String get name => s('customerName');
// //   String get service => s('service');
// //   String get status => s('status').isEmpty ? 'pending' : s('status');
// //   double get budget => (m['budget'] as num?)?.toDouble() ?? 0;
// //   double? get quoteAmount => (m['quoteAmount'] as num?)?.toDouble();
// //   DateTime? get preferred => (m['preferredDate'] as Timestamp?)?.toDate();
// //   DateTime? get created => (m['createdAt'] as Timestamp?)?.toDate();
// //   String? get quoteId => m['quoteId'] as String?;
// //   List<Map<String, dynamic>> get files => _list('attachments');
// //   List<Map<String, dynamic>> get history => _list('statusHistory');
// //   List<Map<String, dynamic>> _list(String k) => ((m[k] as List?) ?? [])
// //       .map((e) => Map<String, dynamic>.from(e as Map))
// //       .toList();
// // }

// // class _Api {
// //   static final db = FirebaseFirestore.instance;
// //   static DocumentReference<Map<String, dynamic>> req(String id) =>
// //       db.collection('quote_requests').doc(id);
// //   static String get me => FirebaseAuth.instance.currentUser?.email ?? 'admin';

// //   static Map<String, dynamic> historyEntry(String status) => {
// //     'status': status,
// //     'at': Timestamp.now(),
// //     'by': me,
// //   };

// //   static Future<void> setStatus(_Req r, String status) async {
// //     await req(r.id).update({
// //       'status': status,
// //       'updatedAt': FieldValue.serverTimestamp(),
// //       'statusHistory': FieldValue.arrayUnion([historyEntry(status)]),
// //     });
// //     await notify(
// //       r,
// //       'Request update',
// //       'Your ${r.service} request is now ${_statuses[status]?.label ?? status}.',
// //       'request',
// //     );
// //   }

// //   /// In-app notification doc (a Cloud Function can turn this into a push).
// //   static Future<void> notify(
// //     _Req r,
// //     String title,
// //     String body,
// //     String type, {
// //     String? quoteId,
// //   }) async {
// //     final uid = r.s('userId');
// //     if (uid.isEmpty) return;
// //     try {
// //       await db.collection('notifications').add({
// //         'userId': uid,
// //         'title': title,
// //         'body': body,
// //         'type': type,
// //         'requestId': r.id,
// //         'quoteId': quoteId,
// //         'read': false,
// //         'createdAt': FieldValue.serverTimestamp(),
// //       });
// //     } catch (_) {}
// //   }
// // }

// // // =============================================================
// // // PAGE
// // // =============================================================
// // class RequestsPage extends StatefulWidget {
// //   const RequestsPage({super.key});
// //   @override
// //   State<RequestsPage> createState() => _RequestsPageState();
// // }

// // class _RequestsPageState extends State<RequestsPage> {
// //   late final Stream<List<_Req>> _stream = FirebaseFirestore.instance
// //       .collection('quote_requests')
// //       .orderBy('createdAt', descending: true)
// //       .snapshots()
// //       .map((s) => s.docs.map(_Req.fromDoc).toList());

// //   String _filter = 'All';
// //   String _q = '';

// //   @override
// //   Widget build(BuildContext context) => PageScaffold(
// //     title: 'Quote Requests',
// //     subtitle: 'Review requests from the app and website, then send a quote',
// //     children: [
// //       StreamBuilder<List<_Req>>(
// //         stream: _stream,
// //         builder: (context, snap) {
// //           if (snap.hasError) {
// //             return Padding(
// //               padding: const EdgeInsets.all(24),
// //               child: SelectableText('Could not load requests.\n${snap.error}'),
// //             );
// //           }
// //           if (!snap.hasData) {
// //             return const Padding(
// //               padding: EdgeInsets.all(40),
// //               child: Center(child: CircularProgressIndicator()),
// //             );
// //           }
// //           final all = snap.data!;
// //           int count(String f) =>
// //               all.where((r) => _filters[f]!.contains(r.status)).length;
// //           final f = _filters[_filter]!;
// //           final q = _q.toLowerCase();
// //           final list = all
// //               .where(
// //                 (r) =>
// //                     (f.isEmpty || f.contains(r.status)) &&
// //                     (q.isEmpty ||
// //                         '${r.name} ${r.number} ${r.service} ${r.s('phone')} ${r.s('email')} ${r.s('address')}'
// //                             .toLowerCase()
// //                             .contains(q)),
// //               )
// //               .toList();

// //           return Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               _stats(count),
// //               const SizedBox(height: 16),
// //               TextField(
// //                 onChanged: (v) => setState(() => _q = v),
// //                 decoration: _dec(
// //                   null,
// //                   hint: 'Search name, request #, service, phone, address',
// //                   icon: Icons.search,
// //                 ),
// //               ),
// //               const SizedBox(height: 12),
// //               SingleChildScrollView(
// //                 scrollDirection: Axis.horizontal,
// //                 child: Row(
// //                   children: [
// //                     for (final k in _filters.keys)
// //                       Padding(
// //                         padding: const EdgeInsets.only(right: 8),
// //                         child: ChoiceChip(
// //                           showCheckmark: false,
// //                           label: Text(
// //                             '$k  ${k == 'All' ? all.length : count(k)}',
// //                           ),
// //                           selected: _filter == k,
// //                           selectedColor: _orange,
// //                           backgroundColor: Colors.white,
// //                           side: const BorderSide(color: _line),
// //                           labelStyle: TextStyle(
// //                             fontWeight: FontWeight.w700,
// //                             color: _filter == k ? Colors.white : _ink,
// //                           ),
// //                           onSelected: (_) => setState(() => _filter = k),
// //                         ),
// //                       ),
// //                   ],
// //                 ),
// //               ),
// //               const SizedBox(height: 14),
// //               if (list.isEmpty)
// //                 const Padding(
// //                   padding: EdgeInsets.symmetric(vertical: 48),
// //                   child: Center(
// //                     child: Text(
// //                       'No requests found',
// //                       style: TextStyle(color: _muted),
// //                     ),
// //                   ),
// //                 )
// //               else
// //                 for (final r in list) _tile(r),
// //             ],
// //           );
// //         },
// //       ),
// //     ],
// //   );

// //   Widget _stats(int Function(String) count) {
// //     const keys = ['New', 'In Review', 'Quoted', 'Approved'];
// //     const colors = [
// //       Color(0xFFFF7A00),
// //       Color(0xFF2D9CDB),
// //       Color(0xFF9B51E0),
// //       Color(0xFF22B573),
// //     ];
// //     return LayoutBuilder(
// //       builder: (_, b) {
// //         final cols = b.maxWidth > 700 ? 4 : 2;
// //         final w = (b.maxWidth - 12 * (cols - 1)) / cols;
// //         return Wrap(
// //           spacing: 12,
// //           runSpacing: 12,
// //           children: [
// //             for (var i = 0; i < keys.length; i++)
// //               SizedBox(
// //                 width: w,
// //                 child: Material(
// //                   color: Colors.white,
// //                   clipBehavior: Clip.antiAlias,
// //                   shape: RoundedRectangleBorder(
// //                     borderRadius: BorderRadius.circular(16),
// //                     side: BorderSide(
// //                       color: _filter == keys[i] ? colors[i] : _line,
// //                       width: _filter == keys[i] ? 1.8 : 1,
// //                     ),
// //                   ),
// //                   child: InkWell(
// //                     onTap: () => setState(() => _filter = keys[i]),
// //                     child: Padding(
// //                       padding: const EdgeInsets.all(16),
// //                       child: Row(
// //                         children: [
// //                           Container(
// //                             width: 6,
// //                             height: 38,
// //                             decoration: BoxDecoration(
// //                               color: colors[i],
// //                               borderRadius: BorderRadius.circular(4),
// //                             ),
// //                           ),
// //                           const SizedBox(width: 12),
// //                           Column(
// //                             crossAxisAlignment: CrossAxisAlignment.start,
// //                             children: [
// //                               Text(
// //                                 '${count(keys[i])}',
// //                                 style: const TextStyle(
// //                                   fontSize: 22,
// //                                   fontWeight: FontWeight.w900,
// //                                   color: _ink,
// //                                 ),
// //                               ),
// //                               Text(
// //                                 keys[i],
// //                                 style: const TextStyle(
// //                                   color: _muted,
// //                                   fontSize: 12.5,
// //                                 ),
// //                               ),
// //                             ],
// //                           ),
// //                         ],
// //                       ),
// //                     ),
// //                   ),
// //                 ),
// //               ),
// //           ],
// //         );
// //       },
// //     );
// //   }

// //   Widget _tile(_Req r) {
// //     final meta = _svc[r.service];
// //     final color = meta?.$2 ?? _orange;
// //     final icon = meta?.$1 ?? Icons.handyman_outlined;
// //     final leading = Container(
// //       width: 46,
// //       height: 46,
// //       decoration: BoxDecoration(
// //         color: color.withValues(alpha: .12),
// //         borderRadius: BorderRadius.circular(14),
// //       ),
// //       child: Icon(icon, color: color),
// //     );
// //     final info = Column(
// //       crossAxisAlignment: CrossAxisAlignment.start,
// //       children: [
// //         Text(
// //           r.name.isEmpty ? 'Customer' : r.name,
// //           maxLines: 1,
// //           overflow: TextOverflow.ellipsis,
// //           style: const TextStyle(
// //             fontWeight: FontWeight.w800,
// //             fontSize: 15,
// //             color: _ink,
// //           ),
// //         ),
// //         const SizedBox(height: 2),
// //         Text(
// //           '${r.number} • ${r.service}'
// //           '${r.created == null ? '' : ' • ${_ago(r.created!)}'}',
// //           maxLines: 1,
// //           overflow: TextOverflow.ellipsis,
// //           style: const TextStyle(color: _muted, fontSize: 12.5),
// //         ),
// //         Text(
// //           r.s('address'),
// //           maxLines: 1,
// //           overflow: TextOverflow.ellipsis,
// //           style: const TextStyle(color: _muted, fontSize: 12.5),
// //         ),
// //       ],
// //     );
// //     final budget = Text(
// //       'Budget ${_money(r.budget)}',
// //       style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
// //     );
// //     final pref = Text(
// //       r.preferred == null ? 'No date' : 'Prefers ${_d(r.preferred!)}',
// //       style: const TextStyle(color: _muted, fontSize: 12.5),
// //     );
// //     final files = r.files.isEmpty
// //         ? const SizedBox.shrink()
// //         : Row(
// //             mainAxisSize: MainAxisSize.min,
// //             children: [
// //               const Icon(Icons.attach_file, size: 16, color: _muted),
// //               Text(
// //                 '${r.files.length}',
// //                 style: const TextStyle(color: _muted, fontSize: 12.5),
// //               ),
// //             ],
// //           );

// //     return Padding(
// //       padding: const EdgeInsets.only(bottom: 10),
// //       child: Material(
// //         color: Colors.white,
// //         clipBehavior: Clip.antiAlias,
// //         shape: RoundedRectangleBorder(
// //           borderRadius: BorderRadius.circular(16),
// //           side: const BorderSide(color: _line),
// //         ),
// //         child: InkWell(
// //           onTap: () => openRequestById(context, r.id),
// //           child: Padding(
// //             padding: const EdgeInsets.all(14),
// //             child: LayoutBuilder(
// //               builder: (_, b) => b.maxWidth > 720
// //                   ? Row(
// //                       children: [
// //                         leading,
// //                         const SizedBox(width: 14),
// //                         Expanded(flex: 3, child: info),
// //                         Expanded(
// //                           flex: 2,
// //                           child: Column(
// //                             crossAxisAlignment: CrossAxisAlignment.start,
// //                             children: [budget, pref],
// //                           ),
// //                         ),
// //                         files,
// //                         const SizedBox(width: 14),
// //                         _chip(r.status),
// //                         const Icon(Icons.chevron_right, color: _muted),
// //                       ],
// //                     )
// //                   : Column(
// //                       crossAxisAlignment: CrossAxisAlignment.start,
// //                       children: [
// //                         Row(
// //                           children: [
// //                             leading,
// //                             const SizedBox(width: 12),
// //                             Expanded(child: info),
// //                             _chip(r.status),
// //                           ],
// //                         ),
// //                         const SizedBox(height: 10),
// //                         Wrap(
// //                           spacing: 14,
// //                           crossAxisAlignment: WrapCrossAlignment.center,
// //                           children: [budget, pref, files],
// //                         ),
// //                       ],
// //                     ),
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }

// // /// Public entry point (use from the dashboard etc.).
// // void openRequestById(BuildContext context, String id) => showDialog(
// //   context: context,
// //   builder: (_) => _RequestDialog(id: id),
// // );

// // // =============================================================
// // // REQUEST DETAIL DIALOG
// // // =============================================================
// // class _RequestDialog extends StatefulWidget {
// //   const _RequestDialog({required this.id});
// //   final String id;
// //   @override
// //   State<_RequestDialog> createState() => _RequestDialogState();
// // }

// // class _RequestDialogState extends State<_RequestDialog> {
// //   late final Stream<DocumentSnapshot<Map<String, dynamic>>> _s = _Api.req(
// //     widget.id,
// //   ).snapshots();
// //   final _note = TextEditingController();
// //   bool _noteInit = false;

// //   @override
// //   void dispose() {
// //     _note.dispose();
// //     super.dispose();
// //   }

// //   Future<void> _change(_Req r, String s) async {
// //     try {
// //       await _Api.setStatus(r, s);
// //       _toast('Status: ${_statuses[s]?.label ?? s}');
// //     } catch (_) {
// //       _toast('Could not update status. Check permissions.', error: true);
// //     }
// //   }

// //   Future<void> _decline(_Req r) async {
// //     final ok = await showDialog<bool>(
// //       context: context,
// //       builder: (ctx) => AlertDialog(
// //         title: const Text('Decline this request?'),
// //         content: const Text('The customer will be notified.'),
// //         actions: [
// //           TextButton(
// //             onPressed: () => Navigator.pop(ctx, false),
// //             child: const Text('Cancel'),
// //           ),
// //           TextButton(
// //             onPressed: () => Navigator.pop(ctx, true),
// //             child: const Text('Decline', style: TextStyle(color: _red)),
// //           ),
// //         ],
// //       ),
// //     );
// //     if (ok == true) _change(r, 'rejected');
// //   }

// //   Future<void> _saveNote() async {
// //     try {
// //       await _Api.req(widget.id).update({
// //         'adminNote': _note.text.trim(),
// //         'updatedAt': FieldValue.serverTimestamp(),
// //       });
// //       _toast('Note saved');
// //     } catch (_) {
// //       _toast('Could not save note', error: true);
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) => Dialog(
// //     backgroundColor: _bg,
// //     insetPadding: const EdgeInsets.all(16),
// //     clipBehavior: Clip.antiAlias,
// //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
// //     child: ConstrainedBox(
// //       constraints: BoxConstraints(
// //         maxWidth: 820,
// //         maxHeight: MediaQuery.of(context).size.height * .92,
// //       ),
// //       child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
// //         stream: _s,
// //         builder: (context, snap) {
// //           if (snap.hasError) {
// //             return Padding(
// //               padding: const EdgeInsets.all(24),
// //               child: SelectableText('${snap.error}'),
// //             );
// //           }
// //           if (!snap.hasData) {
// //             return const SizedBox(
// //               height: 220,
// //               child: Center(child: CircularProgressIndicator()),
// //             );
// //           }
// //           if (!snap.data!.exists) {
// //             return const Padding(
// //               padding: EdgeInsets.all(32),
// //               child: Text('Request not found'),
// //             );
// //           }
// //           final r = _Req.fromDoc(snap.data!);
// //           if (!_noteInit) {
// //             _note.text = r.s('adminNote');
// //             _noteInit = true;
// //           }
// //           return Column(
// //             mainAxisSize: MainAxisSize.min,
// //             children: [
// //               _header(r),
// //               Flexible(
// //                 child: SingleChildScrollView(
// //                   padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
// //                   child: _body(r),
// //                 ),
// //               ),
// //               _footer(r),
// //             ],
// //           );
// //         },
// //       ),
// //     ),
// //   );

// //   Widget _header(_Req r) => Container(
// //     color: Colors.white,
// //     padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
// //     child: Row(
// //       children: [
// //         Expanded(
// //           child: Column(
// //             crossAxisAlignment: CrossAxisAlignment.start,
// //             children: [
// //               Text(
// //                 r.number,
// //                 style: const TextStyle(color: _muted, fontSize: 12.5),
// //               ),
// //               Text(
// //                 r.service,
// //                 style: const TextStyle(
// //                   fontSize: 20,
// //                   fontWeight: FontWeight.w900,
// //                   color: _ink,
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //         _chip(r.status),
// //         IconButton(
// //           onPressed: () => Navigator.pop(context),
// //           icon: const Icon(Icons.close),
// //         ),
// //       ],
// //     ),
// //   );

// //   Widget _info(String label, String value, IconData icon) => ConstrainedBox(
// //     constraints: const BoxConstraints(minWidth: 170, maxWidth: 330),
// //     child: Container(
// //       padding: const EdgeInsets.all(12),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(14),
// //         border: Border.all(color: _line),
// //       ),
// //       child: Row(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           Icon(icon, size: 20, color: _orange),
// //           const SizedBox(width: 10),
// //           Flexible(
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Text(
// //                   label,
// //                   style: const TextStyle(color: _muted, fontSize: 11.5),
// //                 ),
// //                 Text(
// //                   value,
// //                   style: const TextStyle(
// //                     fontWeight: FontWeight.w800,
// //                     color: _ink,
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     ),
// //   );

// //   Widget _contact(IconData i, String t, {String? uri}) => Padding(
// //     padding: const EdgeInsets.symmetric(vertical: 3),
// //     child: Row(
// //       children: [
// //         Icon(i, size: 18, color: _muted),
// //         const SizedBox(width: 10),
// //         Expanded(child: SelectableText(t.isEmpty ? '—' : t)),
// //         if (uri != null && t.isNotEmpty)
// //           IconButton(
// //             visualDensity: VisualDensity.compact,
// //             onPressed: () => _open(uri),
// //             icon: const Icon(Icons.open_in_new, size: 18, color: _orange),
// //           ),
// //       ],
// //     ),
// //   );

// //   Widget _body(_Req r) {
// //     final pref = r.preferred == null ? '—' : _d(r.preferred!);
// //     final slot = r.s('preferredSlot');
// //     return Column(
// //       crossAxisAlignment: CrossAxisAlignment.start,
// //       children: [
// //         const SizedBox(height: 14),
// //         Wrap(
// //           spacing: 10,
// //           runSpacing: 10,
// //           children: [
// //             _info('Customer budget', _money(r.budget), Icons.payments_outlined),
// //             _info(
// //               'Preferred',
// //               slot.isEmpty ? pref : '$pref • $slot',
// //               Icons.event_outlined,
// //             ),
// //             _info(
// //               'Urgency',
// //               r.s('urgency').isEmpty ? '—' : r.s('urgency'),
// //               Icons.bolt_outlined,
// //             ),
// //             _info(
// //               'Quote',
// //               r.quoteAmount == null ? 'Not sent yet' : _money(r.quoteAmount!),
// //               Icons.request_quote_outlined,
// //             ),
// //           ],
// //         ),
// //         _sec(
// //           'Customer',
// //           Container(
// //             padding: const EdgeInsets.all(14),
// //             decoration: BoxDecoration(
// //               color: Colors.white,
// //               borderRadius: BorderRadius.circular(14),
// //               border: Border.all(color: _line),
// //             ),
// //             child: Column(
// //               children: [
// //                 _contact(Icons.person_outline, r.name),
// //                 _contact(
// //                   Icons.call_outlined,
// //                   r.s('phone'),
// //                   uri: 'tel:${r.s('phone')}',
// //                 ),
// //                 _contact(
// //                   Icons.mail_outline,
// //                   r.s('email'),
// //                   uri: 'mailto:${r.s('email')}',
// //                 ),
// //                 _contact(Icons.home_outlined, r.s('address')),
// //               ],
// //             ),
// //           ),
// //         ),
// //         _sec(
// //           'Description of work',
// //           Container(
// //             width: double.infinity,
// //             padding: const EdgeInsets.all(14),
// //             decoration: BoxDecoration(
// //               color: Colors.white,
// //               borderRadius: BorderRadius.circular(14),
// //               border: Border.all(color: _line),
// //             ),
// //             child: SelectableText(
// //               r.s('description').isEmpty ? '—' : r.s('description'),
// //               style: const TextStyle(height: 1.4),
// //             ),
// //           ),
// //         ),
// //         _sec('Photos, videos & documents (${r.files.length})', _files(r)),
// //         _sec(
// //           'Internal note (not shown to customer)',
// //           Column(
// //             crossAxisAlignment: CrossAxisAlignment.end,
// //             children: [
// //               TextField(
// //                 controller: _note,
// //                 maxLines: 3,
// //                 decoration: _dec(null, hint: 'Site visit details, reminders…'),
// //               ),
// //               const SizedBox(height: 8),
// //               OutlinedButton(
// //                 onPressed: _saveNote,
// //                 child: const Text('Save note'),
// //               ),
// //             ],
// //           ),
// //         ),
// //         if (r.history.isNotEmpty) _sec('Activity', _timeline(r)),
// //       ],
// //     );
// //   }

// //   Widget _files(_Req r) {
// //     if (r.files.isEmpty) {
// //       return const Text('No files uploaded', style: TextStyle(color: _muted));
// //     }
// //     return Wrap(
// //       spacing: 10,
// //       runSpacing: 10,
// //       children: [
// //         for (final f in r.files)
// //           () {
// //             final url = '${f['url'] ?? ''}';
// //             final type = '${f['type'] ?? ''}';
// //             final name = '${f['name'] ?? 'file'}';
// //             final isImg = type == 'image';
// //             return InkWell(
// //               borderRadius: BorderRadius.circular(14),
// //               onTap: () => isImg ? _viewImage(url) : _open(url),
// //               child: Container(
// //                 width: 104,
// //                 height: 104,
// //                 clipBehavior: Clip.antiAlias,
// //                 decoration: BoxDecoration(
// //                   color: Colors.white,
// //                   borderRadius: BorderRadius.circular(14),
// //                   border: Border.all(color: _line),
// //                 ),
// //                 child: isImg
// //                     ? Image.network(
// //                         url,
// //                         fit: BoxFit.cover,
// //                         errorBuilder: (_, __, ___) => const Center(
// //                           child: Icon(
// //                             Icons.broken_image_outlined,
// //                             color: _muted,
// //                           ),
// //                         ),
// //                         loadingBuilder: (_, child, p) => p == null
// //                             ? child
// //                             : const Center(
// //                                 child: SizedBox(
// //                                   width: 20,
// //                                   height: 20,
// //                                   child: CircularProgressIndicator(
// //                                     strokeWidth: 2,
// //                                   ),
// //                                 ),
// //                               ),
// //                       )
// //                     : Padding(
// //                         padding: const EdgeInsets.all(8),
// //                         child: Column(
// //                           mainAxisAlignment: MainAxisAlignment.center,
// //                           children: [
// //                             Icon(
// //                               type == 'video'
// //                                   ? Icons.play_circle_outline
// //                                   : Icons.insert_drive_file_outlined,
// //                               color: _orange,
// //                               size: 30,
// //                             ),
// //                             const SizedBox(height: 6),
// //                             Text(
// //                               name,
// //                               maxLines: 2,
// //                               overflow: TextOverflow.ellipsis,
// //                               textAlign: TextAlign.center,
// //                               style: const TextStyle(fontSize: 11),
// //                             ),
// //                           ],
// //                         ),
// //                       ),
// //               ),
// //             );
// //           }(),
// //       ],
// //     );
// //   }

// //   void _viewImage(String url) => showDialog(
// //     context: context,
// //     builder: (ctx) => Dialog(
// //       backgroundColor: Colors.black,
// //       insetPadding: const EdgeInsets.all(12),
// //       child: Stack(
// //         children: [
// //           InteractiveViewer(
// //             child: Center(child: Image.network(url, fit: BoxFit.contain)),
// //           ),
// //           Positioned(
// //             top: 4,
// //             right: 4,
// //             child: IconButton(
// //               onPressed: () => Navigator.pop(ctx),
// //               icon: const Icon(Icons.close, color: Colors.white),
// //             ),
// //           ),
// //         ],
// //       ),
// //     ),
// //   );

// //   Widget _timeline(_Req r) => Column(
// //     children: [
// //       for (final h in r.history.reversed)
// //         Padding(
// //           padding: const EdgeInsets.symmetric(vertical: 4),
// //           child: Row(
// //             children: [
// //               Container(
// //                 width: 9,
// //                 height: 9,
// //                 decoration: BoxDecoration(
// //                   color: _statuses['${h['status']}']?.color ?? _muted,
// //                   shape: BoxShape.circle,
// //                 ),
// //               ),
// //               const SizedBox(width: 10),
// //               Text(
// //                 _statuses['${h['status']}']?.label ?? '${h['status']}',
// //                 style: const TextStyle(fontWeight: FontWeight.w700),
// //               ),
// //               const SizedBox(width: 8),
// //               Expanded(
// //                 child: Text(
// //                   '${h['by'] ?? ''}'
// //                   '${h['at'] is Timestamp ? ' • ${_dt((h['at'] as Timestamp).toDate())}' : ''}',
// //                   overflow: TextOverflow.ellipsis,
// //                   style: const TextStyle(color: _muted, fontSize: 12),
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //     ],
// //   );

// //   Widget _footer(_Req r) {
// //     final canQuote = const [
// //       'pending',
// //       'reviewing',
// //       'quoted',
// //     ].contains(r.status);
// //     return Container(
// //       width: double.infinity,
// //       padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
// //       decoration: const BoxDecoration(
// //         color: Colors.white,
// //         border: Border(top: BorderSide(color: _line)),
// //       ),
// //       child: Wrap(
// //         spacing: 10,
// //         runSpacing: 8,
// //         alignment: WrapAlignment.end,
// //         crossAxisAlignment: WrapCrossAlignment.center,
// //         children: [
// //           PopupMenuButton<String>(
// //             tooltip: 'Change status',
// //             onSelected: (s) => _change(r, s),
// //             itemBuilder: (_) => [
// //               for (final k in _manualStatuses)
// //                 if (k != r.status)
// //                   PopupMenuItem(value: k, child: Text(_statuses[k]!.label)),
// //             ],
// //             child: Container(
// //               padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
// //               decoration: BoxDecoration(
// //                 borderRadius: BorderRadius.circular(12),
// //                 border: Border.all(color: _line),
// //               ),
// //               child: const Row(
// //                 mainAxisSize: MainAxisSize.min,
// //                 children: [
// //                   Text(
// //                     'Change status',
// //                     style: TextStyle(fontWeight: FontWeight.w700),
// //                   ),
// //                   Icon(Icons.arrow_drop_down),
// //                 ],
// //               ),
// //             ),
// //           ),
// //           if (r.status == 'pending')
// //             OutlinedButton(
// //               onPressed: () => _change(r, 'reviewing'),
// //               child: const Text('Mark In Review'),
// //             ),
// //           if (canQuote)
// //             TextButton(
// //               onPressed: () => _decline(r),
// //               child: const Text('Decline', style: TextStyle(color: _red)),
// //             ),
// //           if (canQuote)
// //             ElevatedButton.icon(
// //               onPressed: () => showDialog(
// //                 context: context,
// //                 barrierDismissible: false,
// //                 builder: (_) => _QuoteDialog(req: r),
// //               ),
// //               icon: const Icon(Icons.request_quote),
// //               label: Text(r.quoteId == null ? 'CREATE QUOTE' : 'EDIT QUOTE'),
// //             ),
// //         ],
// //       ),
// //     );
// //   }
// // }

// // // =============================================================
// // // QUOTE BUILDER
// // // =============================================================
// // class _Line {
// //   _Line(this.cat);
// //   String cat;
// //   final desc = TextEditingController();
// //   final qty = TextEditingController(text: '1');
// //   final price = TextEditingController();
// //   double get total => _p(qty) * _p(price);
// //   void dispose() {
// //     desc.dispose();
// //     qty.dispose();
// //     price.dispose();
// //   }
// // }

// // class _PF {
// //   _PF(this.name, this.bytes);
// //   final String name;
// //   final Uint8List bytes;
// // }

// // class _QuoteDialog extends StatefulWidget {
// //   const _QuoteDialog({required this.req});
// //   final _Req req;
// //   @override
// //   State<_QuoteDialog> createState() => _QuoteDialogState();
// // }

// // class _QuoteDialogState extends State<_QuoteDialog> {
// //   final _lines = <_Line>[_Line('Labor')];
// //   final _trash = <_Line>[];
// //   final _discount = TextEditingController(text: '0');
// //   final _tax = TextEditingController(text: '0');
// //   final _depositVal = TextEditingController(text: '50');
// //   final _terms = TextEditingController(text: _defaultTerms);
// //   final _notes = TextEditingController();
// //   String _depositType = 'percent';
// //   DateTime _expires = DateTime.now().add(const Duration(days: 14));
// //   final _newFiles = <_PF>[];
// //   List<Map<String, dynamic>> _kept = [];
// //   bool _saving = false;
// //   bool _loading = false;
// //   String? _quoteId;
// //   String? _quoteNumber;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _quoteId = widget.req.quoteId;
// //     if (_quoteId != null) _load();
// //   }

// //   @override
// //   void dispose() {
// //     for (final l in [..._lines, ..._trash]) {
// //       l.dispose();
// //     }
// //     for (final c in [_discount, _tax, _depositVal, _terms, _notes]) {
// //       c.dispose();
// //     }
// //     super.dispose();
// //   }

// //   Future<void> _load() async {
// //     setState(() => _loading = true);
// //     try {
// //       final d = await _Api.db.collection('quotes').doc(_quoteId).get();
// //       final m = d.data();
// //       if (m != null && mounted) {
// //         final items = (m['items'] as List?) ?? [];
// //         _trash.addAll(_lines);
// //         _lines.clear();
// //         for (final it in items) {
// //           final x = Map<String, dynamic>.from(it as Map);
// //           final l = _Line('${x['category'] ?? 'Other'}');
// //           if (!_cats.contains(l.cat)) l.cat = 'Other';
// //           l.desc.text = '${x['description'] ?? ''}';
// //           l.qty.text = _n((x['qty'] as num?) ?? 1);
// //           l.price.text = _n((x['unitPrice'] as num?) ?? 0);
// //           _lines.add(l);
// //         }
// //         if (_lines.isEmpty) _lines.add(_Line('Labor'));
// //         _discount.text = _n((m['discount'] as num?) ?? 0);
// //         _tax.text = _n((m['taxRate'] as num?) ?? 0);
// //         _depositType = '${m['depositType'] ?? 'percent'}';
// //         _depositVal.text = _n((m['depositValue'] as num?) ?? 50);
// //         _expires = (m['expiresAt'] as Timestamp?)?.toDate() ?? _expires;
// //         _terms.text = '${m['terms'] ?? _defaultTerms}';
// //         _notes.text = '${m['notes'] ?? ''}';
// //         _kept = ((m['attachments'] as List?) ?? [])
// //             .map((e) => Map<String, dynamic>.from(e as Map))
// //             .toList();
// //         _quoteNumber = m['quoteNumber'] as String?;
// //       }
// //     } catch (_) {
// //       _toast('Could not load the existing quote', error: true);
// //     }
// //     if (mounted) setState(() => _loading = false);
// //   }

// //   // ── calculations ──
// //   double get _subtotal => _lines.fold(0.0, (a, l) => a + l.total);
// //   double get _disc => _r2(_p(_discount).clamp(0, _subtotal).toDouble());
// //   double get _taxAmt => _r2((_subtotal - _disc) * _p(_tax) / 100);
// //   double get _total => _r2(_subtotal - _disc + _taxAmt);
// //   double get _deposit => _depositType == 'percent'
// //       ? _r2(_total * _p(_depositVal).clamp(0, 100) / 100)
// //       : _r2(_p(_depositVal).clamp(0, _total).toDouble());
// //   double get _balance => _r2(_total - _deposit);

// //   Future<void> _pickDate() async {
// //     final now = DateTime.now();
// //     final d = await showDatePicker(
// //       context: context,
// //       initialDate: _expires.isBefore(now) ? now : _expires,
// //       firstDate: now,
// //       lastDate: now.add(const Duration(days: 365)),
// //     );
// //     if (d != null) setState(() => _expires = d);
// //   }

// //   Future<void> _pick() async {
// //     try {
// //       final picked = await FilePicker.pickFiles(type: FileType.any);
// //       if (picked.isEmpty) return;
// //       var skipped = 0;
// //       for (final f in picked) {
// //         if (_kept.length + _newFiles.length >= 5) break;
// //         final bytes = await f.readAsBytes();
// //         if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
// //           skipped++;
// //           continue;
// //         }
// //         _newFiles.add(_PF(f.name, bytes));
// //       }
// //       if (mounted) setState(() {});
// //       if (skipped > 0)
// //         _toast('$skipped file(s) skipped (empty or > 20 MB)', error: true);
// //     } catch (_) {
// //       _toast('Could not open file picker', error: true);
// //     }
// //   }

// //   Future<void> _save() async {
// //     final r = widget.req;
// //     final items = [
// //       for (final l in _lines)
// //         if (l.desc.text.trim().isNotEmpty)
// //           {
// //             'category': l.cat,
// //             'description': l.desc.text.trim(),
// //             'qty': _p(l.qty),
// //             'unitPrice': _p(l.price),
// //             'total': _r2(l.total),
// //           },
// //     ];
// //     if (items.isEmpty) {
// //       _toast('Add at least one line item with a description', error: true);
// //       return;
// //     }
// //     if (_total <= 0) {
// //       _toast('Quote total must be greater than zero', error: true);
// //       return;
// //     }
// //     setState(() => _saving = true);
// //     try {
// //       final ref = _Api.db.collection('quotes').doc(_quoteId);
// //       final digits = r.number.replaceAll(RegExp(r'[^0-9]'), '');
// //       final number =
// //           _quoteNumber ??
// //           'QT-${digits.isEmpty ? (r.id.length > 6 ? r.id.substring(0, 6) : r.id) : digits}';

// //       final att = [..._kept];
// //       for (var i = 0; i < _newFiles.length; i++) {
// //         final f = _newFiles[i];
// //         final sref = FirebaseStorage.instance.ref(
// //           'quotes/${r.id}/${ref.id}/${i}_${f.name}',
// //         );
// //         await sref.putData(
// //           f.bytes,
// //           SettableMetadata(contentType: _ctype(f.name)),
// //         );
// //         att.add({'name': f.name, 'url': await sref.getDownloadURL()});
// //       }

// //       await ref.set({
// //         'id': ref.id,
// //         'quoteNumber': number,
// //         'requestId': r.id,
// //         'requestNumber': r.number,
// //         'userId': r.s('userId'),
// //         'customerName': r.name,
// //         'email': r.s('email'),
// //         'phone': r.s('phone'),
// //         'address': r.s('address'),
// //         'service': r.service,
// //         'items': items,
// //         'subtotal': _r2(_subtotal),
// //         'discount': _disc,
// //         'taxRate': _p(_tax),
// //         'tax': _taxAmt,
// //         'total': _total,
// //         'depositType': _depositType,
// //         'depositValue': _p(_depositVal),
// //         'deposit': _deposit,
// //         'balance': _balance,
// //         'expiresAt': Timestamp.fromDate(
// //           DateTime(_expires.year, _expires.month, _expires.day, 23, 59),
// //         ),
// //         'terms': _terms.text.trim(),
// //         'notes': _notes.text.trim(),
// //         'attachments': att,
// //         'status':
// //             'sent', // customer sets: accepted | declined | changes_requested
// //         'createdBy': _Api.me,
// //         'updatedAt': FieldValue.serverTimestamp(),
// //         if (_quoteId == null) 'createdAt': FieldValue.serverTimestamp(),
// //       }, SetOptions(merge: true));

// //       await _Api.req(r.id).update({
// //         'status': 'quoted',
// //         'quoteAmount': _total,
// //         'quoteId': ref.id,
// //         'updatedAt': FieldValue.serverTimestamp(),
// //         'statusHistory': FieldValue.arrayUnion([_Api.historyEntry('quoted')]),
// //       });
// //       await _Api.notify(
// //         r,
// //         _quoteId == null ? 'Quote received' : 'Quote updated',
// //         'Your ${r.service} quote is ready: ${_money(_total)}. '
// //             'Deposit due: ${_money(_deposit)}.',
// //         'quote',
// //         quoteId: ref.id,
// //       );

// //       if (!mounted) return;
// //       Navigator.pop(context);
// //       _toast('Quote sent to customer');
// //     } on FirebaseException catch (e) {
// //       _toast(e.message ?? 'Could not save quote', error: true);
// //     } catch (_) {
// //       _toast('Something went wrong. Please try again.', error: true);
// //     } finally {
// //       if (mounted) setState(() => _saving = false);
// //     }
// //   }

// //   // ── UI ──
// //   @override
// //   Widget build(BuildContext context) {
// //     final r = widget.req;
// //     return Dialog(
// //       backgroundColor: _bg,
// //       insetPadding: const EdgeInsets.all(16),
// //       clipBehavior: Clip.antiAlias,
// //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
// //       child: ConstrainedBox(
// //         constraints: BoxConstraints(
// //           maxWidth: 860,
// //           maxHeight: MediaQuery.of(context).size.height * .94,
// //         ),
// //         child: Column(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             Container(
// //               color: Colors.white,
// //               padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
// //               child: Row(
// //                 children: [
// //                   Expanded(
// //                     child: Column(
// //                       crossAxisAlignment: CrossAxisAlignment.start,
// //                       children: [
// //                         Text(
// //                           _quoteId == null ? 'Create quote' : 'Edit quote',
// //                           style: const TextStyle(
// //                             fontSize: 20,
// //                             fontWeight: FontWeight.w900,
// //                             color: _ink,
// //                           ),
// //                         ),
// //                         Text(
// //                           '${r.name} • ${r.service} • customer budget ${_money(r.budget)}',
// //                           style: const TextStyle(color: _muted, fontSize: 12.5),
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                   IconButton(
// //                     onPressed: _saving ? null : () => Navigator.pop(context),
// //                     icon: const Icon(Icons.close),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //             if (_loading)
// //               const Padding(
// //                 padding: EdgeInsets.all(48),
// //                 child: CircularProgressIndicator(),
// //               )
// //             else
// //               Flexible(
// //                 child: SingleChildScrollView(
// //                   padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       _sec('Line items', _itemsSection()),
// //                       _sec('Discount & tax', _adjustments()),
// //                       _sec('Deposit', _depositSection()),
// //                       const SizedBox(height: 16),
// //                       _totals(),
// //                       _sec(
// //                         'Expiration date',
// //                         Align(
// //                           alignment: Alignment.centerLeft,
// //                           child: OutlinedButton.icon(
// //                             onPressed: _pickDate,
// //                             icon: const Icon(Icons.event, size: 18),
// //                             label: Text(_d(_expires)),
// //                           ),
// //                         ),
// //                       ),
// //                       _sec(
// //                         'Terms & conditions',
// //                         TextField(
// //                           controller: _terms,
// //                           maxLines: 4,
// //                           decoration: _dec(null),
// //                         ),
// //                       ),
// //                       _sec(
// //                         'Notes for the customer',
// //                         TextField(
// //                           controller: _notes,
// //                           maxLines: 3,
// //                           decoration: _dec(
// //                             null,
// //                             hint: 'Scope, materials included, timeline…',
// //                           ),
// //                         ),
// //                       ),
// //                       _sec('Attachments (optional)', _attachments()),
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //             Container(
// //               width: double.infinity,
// //               padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
// //               decoration: const BoxDecoration(
// //                 color: Colors.white,
// //                 border: Border(top: BorderSide(color: _line)),
// //               ),
// //               child: Wrap(
// //                 alignment: WrapAlignment.end,
// //                 spacing: 10,
// //                 runSpacing: 8,
// //                 crossAxisAlignment: WrapCrossAlignment.center,
// //                 children: [
// //                   Text(
// //                     'Total ${_money(_total)}  •  Deposit ${_money(_deposit)}',
// //                     style: const TextStyle(
// //                       fontWeight: FontWeight.w800,
// //                       color: _navy,
// //                     ),
// //                   ),
// //                   TextButton(
// //                     onPressed: _saving ? null : () => Navigator.pop(context),
// //                     child: const Text('Cancel'),
// //                   ),
// //                   ElevatedButton.icon(
// //                     onPressed: (_saving || _loading) ? null : _save,
// //                     icon: _saving
// //                         ? const SizedBox(
// //                             width: 16,
// //                             height: 16,
// //                             child: CircularProgressIndicator(strokeWidth: 2),
// //                           )
// //                         : const Icon(Icons.send),
// //                     label: Text(
// //                       _quoteId == null ? 'SEND QUOTE' : 'UPDATE & RESEND',
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }

// //   Widget _itemsSection() => Column(
// //     crossAxisAlignment: CrossAxisAlignment.start,
// //     children: [
// //       for (var i = 0; i < _lines.length; i++) _lineRow(i),
// //       TextButton.icon(
// //         onPressed: () => setState(() => _lines.add(_Line('Materials'))),
// //         icon: const Icon(Icons.add),
// //         label: const Text('Add line'),
// //       ),
// //     ],
// //   );

// //   Widget _lineRow(int i) {
// //     final l = _lines[i];
// //     return Container(
// //       key: ObjectKey(l),
// //       margin: const EdgeInsets.only(bottom: 10),
// //       padding: const EdgeInsets.all(12),
// //       decoration: BoxDecoration(
// //         color: Colors.white,
// //         borderRadius: BorderRadius.circular(14),
// //         border: Border.all(color: _line),
// //       ),
// //       child: LayoutBuilder(
// //         builder: (_, b) {
// //           final wide = b.maxWidth > 600;
// //           final cat = DropdownButtonFormField<String>(
// //             value: l.cat,
// //             isExpanded: true,
// //             decoration: _dec('Type'),
// //             items: [
// //               for (final c in _cats)
// //                 DropdownMenuItem(
// //                   value: c,
// //                   child: Text(c, overflow: TextOverflow.ellipsis),
// //                 ),
// //             ],
// //             onChanged: (v) => setState(() => l.cat = v!),
// //           );
// //           final desc = TextField(
// //             controller: l.desc,
// //             decoration: _dec(
// //               'Description',
// //               hint: 'e.g. Interior painting, 2 coats',
// //             ),
// //           );
// //           final qty = TextField(
// //             controller: l.qty,
// //             keyboardType: const TextInputType.numberWithOptions(decimal: true),
// //             onChanged: (_) => setState(() {}),
// //             decoration: _dec('Qty'),
// //           );
// //           final price = TextField(
// //             controller: l.price,
// //             keyboardType: const TextInputType.numberWithOptions(decimal: true),
// //             onChanged: (_) => setState(() {}),
// //             decoration: _dec('Unit price', prefix: '\$ '),
// //           );
// //           final tot = Text(
// //             _money(l.total),
// //             style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
// //           );
// //           final del = IconButton(
// //             onPressed: _lines.length == 1
// //                 ? null
// //                 : () => setState(() => _trash.add(_lines.removeAt(i))),
// //             icon: const Icon(Icons.delete_outline, color: _red),
// //           );
// //           if (wide) {
// //             return Row(
// //               children: [
// //                 SizedBox(width: 170, child: cat),
// //                 const SizedBox(width: 8),
// //                 Expanded(child: desc),
// //                 const SizedBox(width: 8),
// //                 SizedBox(width: 70, child: qty),
// //                 const SizedBox(width: 8),
// //                 SizedBox(width: 110, child: price),
// //                 SizedBox(
// //                   width: 96,
// //                   child: Align(alignment: Alignment.centerRight, child: tot),
// //                 ),
// //                 del,
// //               ],
// //             );
// //           }
// //           return Column(
// //             children: [
// //               cat,
// //               const SizedBox(height: 8),
// //               desc,
// //               const SizedBox(height: 8),
// //               Row(
// //                 children: [
// //                   Expanded(child: qty),
// //                   const SizedBox(width: 8),
// //                   Expanded(flex: 2, child: price),
// //                 ],
// //               ),
// //               Row(
// //                 children: [
// //                   const Text('Line total', style: TextStyle(color: _muted)),
// //                   const Spacer(),
// //                   tot,
// //                   del,
// //                 ],
// //               ),
// //             ],
// //           );
// //         },
// //       ),
// //     );
// //   }

// //   Widget _adjustments() => Row(
// //     children: [
// //       Expanded(
// //         child: TextField(
// //           controller: _discount,
// //           keyboardType: const TextInputType.numberWithOptions(decimal: true),
// //           onChanged: (_) => setState(() {}),
// //           decoration: _dec('Discount', prefix: '\$ '),
// //         ),
// //       ),
// //       const SizedBox(width: 12),
// //       Expanded(
// //         child: TextField(
// //           controller: _tax,
// //           keyboardType: const TextInputType.numberWithOptions(decimal: true),
// //           onChanged: (_) => setState(() {}),
// //           decoration: _dec('Tax rate (if applicable)', suffix: '%'),
// //         ),
// //       ),
// //     ],
// //   );

// //   Widget _depositSection() => Wrap(
// //     spacing: 12,
// //     runSpacing: 10,
// //     crossAxisAlignment: WrapCrossAlignment.center,
// //     children: [
// //       SegmentedButton<String>(
// //         showSelectedIcon: false,
// //         segments: const [
// //           ButtonSegment(value: 'percent', label: Text('Percent')),
// //           ButtonSegment(value: 'fixed', label: Text('Fixed \$')),
// //         ],
// //         selected: {_depositType},
// //         onSelectionChanged: (s) => setState(() {
// //           _depositType = s.first;
// //           _depositVal.text = _depositType == 'percent' ? '50' : '';
// //         }),
// //       ),
// //       SizedBox(
// //         width: 150,
// //         child: TextField(
// //           controller: _depositVal,
// //           keyboardType: const TextInputType.numberWithOptions(decimal: true),
// //           onChanged: (_) => setState(() {}),
// //           decoration: _depositType == 'percent'
// //               ? _dec('Deposit', suffix: '%')
// //               : _dec('Deposit', prefix: '\$ '),
// //         ),
// //       ),
// //       Text(
// //         '= ${_money(_deposit)}',
// //         style: const TextStyle(fontWeight: FontWeight.w800, color: _navy),
// //       ),
// //     ],
// //   );

// //   Widget _trow(String label, String value, {bool bold = false, Color? color}) =>
// //       Padding(
// //         padding: const EdgeInsets.symmetric(vertical: 4),
// //         child: Row(
// //           children: [
// //             Text(
// //               label,
// //               style: TextStyle(
// //                 color: bold ? _ink : _muted,
// //                 fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
// //               ),
// //             ),
// //             const Spacer(),
// //             Text(
// //               value,
// //               style: TextStyle(
// //                 fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
// //                 fontSize: bold ? 17 : 14,
// //                 color: color ?? _ink,
// //               ),
// //             ),
// //           ],
// //         ),
// //       );

// //   Widget _totals() => Container(
// //     padding: const EdgeInsets.all(16),
// //     decoration: BoxDecoration(
// //       color: Colors.white,
// //       borderRadius: BorderRadius.circular(16),
// //       border: Border.all(color: _line),
// //     ),
// //     child: Column(
// //       children: [
// //         _trow('Subtotal', _money(_subtotal)),
// //         _trow('Discount', '- ${_money(_disc)}'),
// //         _trow('Tax (${_n(_p(_tax))}%)', _money(_taxAmt)),
// //         const Divider(height: 18),
// //         _trow('Project total', _money(_total), bold: true),
// //         _trow(
// //           _depositType == 'percent'
// //               ? 'Required deposit (${_n(_p(_depositVal))}%)'
// //               : 'Required deposit',
// //           _money(_deposit),
// //           color: _orange,
// //         ),
// //         _trow('Remaining balance', _money(_balance)),
// //       ],
// //     ),
// //   );

// //   Widget _attachments() => Column(
// //     crossAxisAlignment: CrossAxisAlignment.start,
// //     children: [
// //       Wrap(
// //         spacing: 8,
// //         runSpacing: 8,
// //         children: [
// //           for (var i = 0; i < _kept.length; i++)
// //             InputChip(
// //               avatar: const Icon(Icons.attach_file, size: 16),
// //               label: Text('${_kept[i]['name']}'),
// //               onPressed: () => _open('${_kept[i]['url']}'),
// //               onDeleted: () => setState(() => _kept.removeAt(i)),
// //             ),
// //           for (var i = 0; i < _newFiles.length; i++)
// //             InputChip(
// //               avatar: const Icon(Icons.upload_file, size: 16),
// //               label: Text(_newFiles[i].name),
// //               onDeleted: () => setState(() => _newFiles.removeAt(i)),
// //             ),
// //         ],
// //       ),
// //       TextButton.icon(
// //         onPressed: _pick,
// //         icon: const Icon(Icons.add),
// //         label: const Text('Add file (max 5, 20 MB each)'),
// //       ),
// //     ],
// //   );
// // }

// // // import 'package:flutter/material.dart';
// // // import 'package:get/get.dart';

// // // import '../../controllers/app_controller.dart';
// // // import '../../core/core.dart';
// // // import '../../models/models.dart';
// // // import '../../widgets/widgets.dart';
// // // import '../quotes/quote_builder.dart';

// // // class RequestsPage extends StatelessWidget {
// // //   const RequestsPage({super.key});
// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final c = Get.find<AppController>();
// // //     return PageScaffold(
// // //       title: 'Quote Requests',
// // //       subtitle: 'Requests submitted from the mobile app and website',
// // //       children: [
// // //         FilterBar(const ['All', 'New', 'In Review', 'Quoted'], c.reqFilter),
// // //         const SizedBox(height: 14),
// // //         Obx(() {
// // //           final f = c.reqFilter.value;
// // //           final list = c.requests
// // //               .where((r) => f == 'All' || r.status == f)
// // //               .toList();
// // //           return ResponsiveTable(
// // //             headers: const [
// // //               'Request',
// // //               'Service',
// // //               'Preferred Date',
// // //               'Budget',
// // //               'Media',
// // //               'Status',
// // //             ],
// // //             rows: [
// // //               for (final r in list)
// // //                 [
// // //                   sub(r.customer, r.id),
// // //                   plain(r.service),
// // //                   plain('${fmtDate(r.date)} • ${r.time}'),
// // //                   bold(money(r.budget)),
// // //                   plain('${r.photos} photos, ${r.videos} video'),
// // //                   Chip2(r.status),
// // //                 ],
// // //             ],
// // //             onTap: (i) => openRequest(context, list[i]),
// // //           );
// // //         }),
// // //       ],
// // //     );
// // //   }
// // // }

// // // void openRequest(BuildContext context, QuoteRequest r) {
// // //   final c = Get.find<AppController>();
// // //   showDetail(
// // //     context,
// // //     title: '${r.id} • ${r.service}',
// // //     actions: [
// // //       OutlinedButton(
// // //         onPressed: () {
// // //           r.status = 'In Review';
// // //           c.requests.refresh();
// // //           Navigator.pop(context);
// // //         },
// // //         child: const Text('Mark In Review'),
// // //       ),
// // //       OutlinedButton.icon(
// // //         onPressed: () {
// // //           Navigator.pop(context);
// // //           c.page.value = 8;
// // //         },
// // //         icon: const Icon(Icons.chat),
// // //         label: const Text('Message'),
// // //       ),
// // //       ElevatedButton.icon(
// // //         onPressed: () {
// // //           Navigator.pop(context);
// // //           openQuoteBuilder(context, request: r);
// // //         },
// // //         icon: const Icon(Icons.request_quote),
// // //         label: const Text('CREATE QUOTE'),
// // //       ),
// // //     ],
// // //     body: Column(
// // //       crossAxisAlignment: CrossAxisAlignment.start,
// // //       children: [
// // //         Row(
// // //           children: [
// // //             Chip2(r.status),
// // //             const Spacer(),
// // //             Text(
// // //               'Budget ${money(r.budget)}',
// // //               style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
// // //             ),
// // //           ],
// // //         ),
// // //         const SizedBox(height: 14),
// // //         KV('Customer', r.customer),
// // //         KV('Phone', r.phone),
// // //         KV('Email', r.email),
// // //         KV('Address', r.address),
// // //         KV('Preferred', '${fmtDate(r.date)} • ${r.time}'),
// // //         const Divider(height: 26),
// // //         const Text(
// // //           'Description of work',
// // //           style: TextStyle(fontWeight: FontWeight.w900),
// // //         ),
// // //         const SizedBox(height: 6),
// // //         Text(r.description),
// // //         const SizedBox(height: 18),
// // //         Text(
// // //           'Uploads (${r.photos} photos, ${r.videos} video)',
// // //           style: const TextStyle(fontWeight: FontWeight.w900),
// // //         ),
// // //         const SizedBox(height: 8),
// // //         Wrap(
// // //           spacing: 8,
// // //           runSpacing: 8,
// // //           children: [
// // //             for (int i = 0; i < r.photos; i++)
// // //               Container(
// // //                 width: 78,
// // //                 height: 78,
// // //                 color: C.line,
// // //                 child: const Icon(Icons.image, color: C.muted),
// // //               ),
// // //             for (int i = 0; i < r.videos; i++)
// // //               Container(
// // //                 width: 78,
// // //                 height: 78,
// // //                 color: C.navy,
// // //                 child: const Icon(Icons.play_circle, color: C.yellow),
// // //               ),
// // //           ],
// // //         ),
// // //       ],
// // //     ),
// // //   );
// // // }
