import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../widgets/widgets.dart';

// =============================================================
// PAYMENTS PAGE (admin) — live from Firestore: quote_requests
// Every invoice produces up to two payment rows:
//   Deposit  -> advancePaid / depositPaidAt / paymentMethod / paymentRef
//   Balance  -> balancePaid / balancePaidAt / balanceMethod
// Statuses: Paid | Pending | Refunded
// Writes:  "Mark received" and "Refund" (admin).
// Admin account must be allowed to update quote_requests in rules.
// =============================================================

class _K {
  static const orange = Color(0xFFFF7A00);
  static const ink = Color(0xFF1B1F2A);
  static const bg = Color(0xFFF5F3EF);
  static const muted = Color(0xFF787F90);
  static const line = Color(0xFFE9E5DD);
  static const green = Color(0xFF1FAE6B);
  static const red = Color(0xFFE4513F);
  static const blue = Color(0xFF2D8CDB);
  static const amber = Color(0xFFF2994A);
}

const _months = [
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

String _d(DateTime? d) =>
    d == null ? '—' : '${_months[d.month - 1]} ${d.day}, ${d.year}';

String _m(num v) {
  final p = v.toStringAsFixed(2).split('.');
  final w = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '\$$w.${p[1]}';
}

double _n(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
}

DateTime? _dt(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String _cap(String s) => s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1);

// ---------------------------------------------------------
// MODEL
// ---------------------------------------------------------
class _Pay {
  final String docId, kind; // kind: 'deposit' | 'balance'
  final String customer, invoiceNo, service, method, ref, status;
  final double amount;
  final DateTime? date;

  const _Pay({
    required this.docId,
    required this.kind,
    required this.customer,
    required this.invoiceNo,
    required this.service,
    required this.method,
    required this.ref,
    required this.status,
    required this.amount,
    this.date,
  });

  bool get isBalance => kind == 'balance';
  String get id => '$docId-$kind';
  String get label => isBalance ? 'Balance' : 'Deposit';

  Color get color =>
      status == 'Paid' ? _K.green : (status == 'Refunded' ? _K.red : _K.amber);

  /// Estimated card fee (2.9% + $0.30). Only for paid card payments.
  double get estFee => (status == 'Paid' && method.toLowerCase() == 'card')
      ? amount * 0.029 + 0.30
      : 0;

  /// One invoice document -> 0..2 payment rows.
  static List<_Pay> fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return const [];
    final raw = d['invoice'];
    final inv = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final qRaw = d['quote'];
    final q = qRaw is Map
        ? Map<String, dynamic>.from(qRaw)
        : <String, dynamic>{};

    var total = _n(inv['total']);
    if (total <= 0) total = _n(q['total']);
    if (total <= 0) total = _n(d['quoteTotal']);
    if (total <= 0) return const [];

    var adv = inv.containsKey('advance')
        ? _n(inv['advance'])
        : (_n(q['depositNow']) > 0 ? _n(q['depositNow']) : _n(d['depositNow']));
    if (adv > total) adv = total;
    final bal = inv.containsKey('balance')
        ? _n(inv['balance'])
        : (((total - adv) * 100).round() / 100);

    final id = doc.id;
    final reqNo = d['requestNumber'] != null
        ? '${d['requestNumber']}'
        : id.substring(0, id.length < 6 ? id.length : 6).toUpperCase();
    String s(String k) => (d[k] ?? '').toString();

    final invNo = inv['number'] != null ? '${inv['number']}' : 'INV-$reqNo';
    final customer = s('customerName').isEmpty ? 'Customer' : s('customerName');
    final service = d['service'] != null ? s('service') : 'Service';
    final jobStatus = s('status');

    final advPaid =
        d['advancePaid'] == true ||
        d['depositPaid'] == true ||
        d['paymentStatus'] == 'paid' ||
        inv['status'] == 'advance_paid' ||
        inv['status'] == 'paid';
    final balPaid = d['balancePaid'] == true || inv['status'] == 'paid';

    final out = <_Pay>[];

    if (adv > 0) {
      out.add(
        _Pay(
          docId: id,
          kind: 'deposit',
          customer: customer,
          invoiceNo: invNo,
          service: service,
          method: s('paymentMethod'),
          ref: s('paymentRef'),
          amount: adv,
          status: d['depositRefunded'] == true
              ? 'Refunded'
              : (advPaid ? 'Paid' : 'Pending'),
          date: advPaid
              ? (_dt(d['depositPaidAt']) ??
                    _dt(d['advancePaidAt']) ??
                    _dt(inv['paidAt']))
              : (_dt(inv['issuedAt']) ?? _dt(d['acceptedAt'])),
        ),
      );
    }

    // Balance row: once paid, or when the job is done and it is still due.
    if (bal > 0 && (balPaid || jobStatus == 'completed')) {
      out.add(
        _Pay(
          docId: id,
          kind: 'balance',
          customer: customer,
          invoiceNo: invNo,
          service: service,
          method: s('balanceMethod'),
          ref: s('balanceRef'),
          amount: bal,
          status: d['balanceRefunded'] == true
              ? 'Refunded'
              : (balPaid ? 'Paid' : 'Pending'),
          date: balPaid ? _dt(d['balancePaidAt']) : _dt(d['updatedAt']),
        ),
      );
    }
    return out;
  }
}

// ---------------------------------------------------------
// PAGE
// ---------------------------------------------------------
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});
  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  static const _filters = ['All', 'Paid', 'Pending', 'Refunded'];

  StreamSubscription? _sub;
  List<_Pay> _all = [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    _sub?.cancel();
    setState(() {
      _loading = true;
      _error = null;
    });
    _sub = FirebaseFirestore.instance
        .collection('quote_requests')
        .where('status', whereIn: ['accepted', 'scheduled', 'completed'])
        .snapshots()
        .listen(
          (snap) {
            final list = <_Pay>[];
            for (final doc in snap.docs) {
              list.addAll(_Pay.fromDoc(doc));
            }
            final epoch = DateTime.fromMillisecondsSinceEpoch(0);
            list.sort((a, b) => (b.date ?? epoch).compareTo(a.date ?? epoch));
            if (!mounted) return;
            setState(() {
              _all = list;
              _loading = false;
              _error = null;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error =
                  'Could not load payments. Check your connection and permissions.';
            });
          },
        );
  }

  List<_Pay> get _visible {
    final s = _search.trim().toLowerCase();
    return _all.where((p) {
      if (_filter != 'All' && p.status != _filter) return false;
      if (s.isEmpty) return true;
      return p.customer.toLowerCase().contains(s) ||
          p.invoiceNo.toLowerCase().contains(s) ||
          p.ref.toLowerCase().contains(s) ||
          p.service.toLowerCase().contains(s);
    }).toList();
  }

  int _count(String f) =>
      f == 'All' ? _all.length : _all.where((p) => p.status == f).length;

  void _snack(String msg) => Get.find<AppController>().snack(msg);

  // ----- actions -----
  Future<void> _markReceived(_Pay p) async {
    final method = await showDialog<String>(
      context: context,
      builder: (dctx) => SimpleDialog(
        title: Text('${p.label} received via…'),
        children: [
          for (final e in ['Cash', 'Zelle', 'Check', 'Card', 'Bank'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dctx, e.toLowerCase()),
              child: Text(e),
            ),
        ],
      ),
    );
    if (method == null || !mounted) return;

    final ref = FirebaseFirestore.instance
        .collection('quote_requests')
        .doc(p.docId);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('missing');
        final cur = _Pay.fromDoc(snap).where((x) => x.kind == p.kind).toList();
        if (cur.isEmpty || cur.first.status != 'Pending')
          return; // already handled
        final amount = cur.first.amount;
        final history = FieldValue.arrayUnion([
          {
            'status': (snap.data()?['status'] ?? 'accepted'),
            'type': 'payment',
            'at': Timestamp.now(),
            'by': 'admin',
            'note': '${p.label} received (${_m(amount)}) · ${_cap(method)}',
          },
        ]);
        final stamp = DateTime.now().millisecondsSinceEpoch;
        if (p.isBalance) {
          tx.update(ref, {
            'balancePaid': true,
            'balancePaidAt': FieldValue.serverTimestamp(),
            'balanceMethod': method,
            'balanceRef': 'ADMIN-$stamp',
            'invoice.status': 'paid',
            'updatedAt': FieldValue.serverTimestamp(),
            'statusHistory': history,
          });
        } else {
          tx.update(ref, {
            'depositPaid': true,
            'advancePaid': true,
            'paymentStatus': 'paid',
            'depositAmount': amount,
            'depositPaidAt': FieldValue.serverTimestamp(),
            'advancePaidAt': FieldValue.serverTimestamp(),
            'paymentMethod': method,
            'paymentRef': 'ADMIN-$stamp',
            'invoice.status': 'advance_paid',
            'invoice.paidAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'statusHistory': history,
          });
        }
      });
      _snack('${p.label} for ${p.customer} marked as received');
    } catch (_) {
      _snack('Could not update payment. Check permissions.');
    }
  }

  Future<void> _refund(_Pay p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Refund payment?'),
        content: Text(
          'Mark ${_m(p.amount)} (${p.label.toLowerCase()}) as refunded to ${p.customer}?\n\n'
          'This only records the refund here. Send the money back through '
          'Stripe or your bank separately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Refund', style: TextStyle(color: _K.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final ref = FirebaseFirestore.instance
        .collection('quote_requests')
        .doc(p.docId);
    final pre = p.isBalance ? 'balance' : 'deposit';
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('missing');
        if (snap.data()?['${pre}Refunded'] == true) return;
        tx.update(ref, {
          '${pre}Refunded': true,
          '${pre}RefundedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'statusHistory': FieldValue.arrayUnion([
            {
              'status': (snap.data()?['status'] ?? 'accepted'),
              'type': 'payment',
              'at': Timestamp.now(),
              'by': 'admin',
              'note': '${p.label} refunded (${_m(p.amount)})',
            },
          ]),
        });
      });
      _snack('${_m(p.amount)} refunded to ${p.customer}');
    } catch (_) {
      _snack('Could not refund. Check permissions.');
    }
  }

  Future<void> _copyRef(_Pay p) async {
    if (p.ref.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: p.ref));
    _snack('Reference copied');
  }

  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    double sum(bool Function(_Pay) t, double Function(_Pay) f) =>
        _all.where(t).fold(0.0, (s, p) => s + f(p));

    final collected = sum((p) => p.status == 'Paid', (p) => p.amount);
    final fees = sum((p) => p.status == 'Paid', (p) => p.estFee);
    final pendingAmt = sum((p) => p.status == 'Pending', (p) => p.amount);
    final refunded = sum((p) => p.status == 'Refunded', (p) => p.amount);

    return PageScaffold(
      title: 'Payments',
      subtitle: 'Live · deposits and balances from customer invoices',
      children: [
        _stats(collected, fees, pendingAmt, refunded),
        const SizedBox(height: 16),
        _toolbar(),
        const SizedBox(height: 14),
        _body(),
        const SizedBox(height: 16),
        _zellePanel(),
      ],
    );
  }

  Widget _stats(
    double collected,
    double fees,
    double pending,
    double refunded,
  ) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final cols = w >= 900 ? 4 : (w >= 300 ? 2 : 1);
        const gap = 12.0;
        final iw = (w - gap * (cols - 1)) / cols;
        Widget card(String l, String v, IconData ic, Color c, String sub) =>
            SizedBox(
              width: iw,
              child: _StatCard(
                label: l,
                value: v,
                icon: ic,
                color: c,
                sub: sub,
              ),
            );
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            card(
              'Collected',
              _m(collected),
              Icons.account_balance_wallet,
              _K.green,
              '${_count('Paid')} payments',
            ),
            card(
              'Est. card fees',
              _m(fees),
              Icons.percent,
              _K.orange,
              '2.9% + \$0.30 on cards',
            ),
            card(
              'Pending',
              _m(pending),
              Icons.hourglass_top,
              _K.blue,
              '${_count('Pending')} awaiting',
            ),
            card(
              'Refunded',
              _m(refunded),
              Icons.undo_rounded,
              _K.red,
              '${_count('Refunded')} refunds',
            ),
          ],
        );
      },
    );
  }

  Widget _toolbar() {
    return LayoutBuilder(
      builder: (context, box) {
        final search = TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search customer, invoice or reference',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _K.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _K.line),
            ),
          ),
        );
        final chips = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _filters)
              ChoiceChip(
                label: Text('$f · ${_count(f)}'),
                selected: _filter == f,
                onSelected: (_) => setState(() => _filter = f),
                selectedColor: _K.ink,
                backgroundColor: Colors.white,
                side: const BorderSide(color: _K.line),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _filter == f ? Colors.white : _K.ink,
                ),
                showCheckmark: false,
              ),
          ],
        );
        if (box.maxWidth >= 900) {
          return Row(
            children: [
              SizedBox(width: 340, child: search),
              const SizedBox(width: 16),
              Expanded(child: chips),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [search, const SizedBox(height: 10), chips],
        );
      },
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: _K.orange)),
      );
    }
    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        text: _error!,
        action: TextButton(onPressed: _listen, child: const Text('Retry')),
      );
    }
    final list = _visible;
    if (list.isEmpty) {
      return _Message(
        icon: Icons.payments_rounded,
        text: _all.isEmpty
            ? 'No payments yet.\nThey appear when customers approve quotes.'
            : 'No payments match your filter.',
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 900) return _table(list);
        return Column(
          children: [
            for (final p in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PayCard(
                  p: p,
                  action: _action(p),
                  onCopyRef: () => _copyRef(p),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _action(_Pay p) {
    switch (p.status) {
      case 'Pending':
        return TextButton.icon(
          onPressed: () => _markReceived(p),
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Mark received'),
          style: TextButton.styleFrom(foregroundColor: _K.green),
        );
      case 'Paid':
        return TextButton.icon(
          onPressed: () => _refund(p),
          icon: const Icon(Icons.undo_rounded, size: 18),
          label: const Text('Refund'),
          style: TextButton.styleFrom(foregroundColor: _K.red),
        );
      default:
        return const Text('—', style: TextStyle(color: _K.muted));
    }
  }

  // ----- wide layout: table -----
  Widget _table(List<_Pay> list) {
    const hs = TextStyle(
      color: _K.muted,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: .4,
    );
    Widget h(String t, int flex, [TextAlign a = TextAlign.left]) => Expanded(
      flex: flex,
      child: Text(t.toUpperCase(), textAlign: a, style: hs),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _K.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: _K.bg,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                h('Payment', 3),
                h('Invoice', 2),
                h('Amount', 2, TextAlign.right),
                h('Method', 2),
                h('Date', 2),
                h('Status', 2),
                h('Action', 3),
              ],
            ),
          ),
          for (var k = 0; k < list.length; k++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list[k].customer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _K.ink,
                          ),
                        ),
                        Text(
                          '${list[k].label} · ${list[k].service}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _K.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      list[k].invoiceNo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _m(list[k].amount),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      list[k].status == 'Pending' ? '—' : _cap(list[k].method),
                    ),
                  ),
                  Expanded(flex: 2, child: Text(_d(list[k].date))),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _Badge(list[k].status, list[k].color),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _action(list[k]),
                    ),
                  ),
                ],
              ),
            ),
            if (k != list.length - 1) const Divider(height: 1, color: _K.line),
          ],
        ],
      ),
    );
  }

  Widget _zellePanel() => Panel(
    title: 'Zelle Instructions (shown to customers)',
    child: Obx(() {
      final c = Get.find<AppController>();
      return Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: C.navy,
            title: const Text('Enable "Pay with Zelle"'),
            subtitle: const Text(
              'Customer pays via their bank app, then you mark it received.',
            ),
            value: c.zelleEnabled.value,
            onChanged: (v) => c.zelleEnabled.value = v,
          ),
          if (c.zelleEnabled.value)
            const KV('Zelle email', 'admin@twinshandymanllc.com'),
        ],
      );
    }),
  );
}

// ---------------------------------------------------------
// SMALL WIDGETS
// ---------------------------------------------------------
class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sub = '',
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _K.line),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _K.muted, fontSize: 12.5),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: _K.ink,
                  ),
                ),
              ),
              if (sub.isNotEmpty)
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _K.muted, fontSize: 11.5),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
    ),
  );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _K.orange.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _K.orange, size: 38),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _K.muted, height: 1.4),
          ),
          if (action != null) action!,
        ],
      ),
    ),
  );
}

/// Compact card for phones / tablets.
class _PayCard extends StatelessWidget {
  final _Pay p;
  final Widget action;
  final VoidCallback onCopyRef;
  const _PayCard({
    required this.p,
    required this.action,
    required this.onCopyRef,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _K.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: _K.ink,
                      ),
                    ),
                    Text(
                      '${p.label} · ${p.invoiceNo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _K.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _m(p.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: _K.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _Badge(p.status, p.color),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _meta(Icons.event_rounded, _d(p.date)),
              if (p.status != 'Pending')
                _meta(Icons.credit_card_rounded, _cap(p.method)),
              if (p.ref.isNotEmpty)
                InkWell(
                  onTap: onCopyRef,
                  child: _meta(Icons.tag_rounded, p.ref),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }

  Widget _meta(IconData i, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: 14, color: _K.muted),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          t,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _K.muted, fontSize: 12),
        ),
      ),
    ],
  );
}
