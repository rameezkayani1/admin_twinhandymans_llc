import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

// =============================================================
// INVOICES PAGE (admin) — live from Firestore: quote_requests
// Shows every invoice created when a customer approves a quote.
// Reads:  invoice{number,total,advance,balance,issuedAt,paidAt},
//         advancePaid / depositPaid, balancePaid, paymentMethod ...
// Writes: "Mark deposit paid" / "Mark balance paid" (admin).
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
class _Inv {
  final String id, number, requestNo, customer, phone, email, address, service;
  final String method, ref;
  final double total, advance, balance;
  final bool advancePaid, balancePaid;
  final DateTime? issuedAt, advancePaidAt, balancePaidAt;

  const _Inv({
    required this.id,
    required this.number,
    required this.requestNo,
    required this.customer,
    required this.phone,
    required this.email,
    required this.address,
    required this.service,
    required this.method,
    required this.ref,
    required this.total,
    required this.advance,
    required this.balance,
    required this.advancePaid,
    required this.balancePaid,
    this.issuedAt,
    this.advancePaidAt,
    this.balancePaidAt,
  });

  double get paid => (advancePaid ? advance : 0) + (balancePaid ? balance : 0);
  double get outstanding {
    final o = total - paid;
    return o < 0.005 ? 0 : o;
  }

  /// Paid | Partial | Unpaid
  String get status {
    if (outstanding <= 0) return 'Paid';
    if (advancePaid && advance > 0) return 'Partial';
    return 'Unpaid';
  }

  Color get color =>
      status == 'Paid' ? _K.green : (status == 'Partial' ? _K.blue : _K.amber);

  static _Inv? from(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    if (d == null) return null;
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
    if (total <= 0) return null;

    var adv = inv.containsKey('advance')
        ? _n(inv['advance'])
        : (_n(q['depositNow']) > 0 ? _n(q['depositNow']) : _n(d['depositNow']));
    if (adv > total) adv = total;
    final bal = inv.containsKey('balance')
        ? _n(inv['balance'])
        : (((total - adv) * 100).round() / 100);

    final advPaid =
        d['advancePaid'] == true ||
        d['depositPaid'] == true ||
        d['paymentStatus'] == 'paid' ||
        inv['status'] == 'advance_paid' ||
        inv['status'] == 'paid';

    final id = doc.id;
    final reqNo = d['requestNumber'] != null
        ? '${d['requestNumber']}'
        : id.substring(0, id.length < 6 ? id.length : 6).toUpperCase();

    String s(String k) => (d[k] ?? '').toString();

    return _Inv(
      id: id,
      number: inv['number'] != null ? '${inv['number']}' : 'INV-$reqNo',
      requestNo: reqNo,
      customer: s('customerName').isEmpty ? 'Customer' : s('customerName'),
      phone: s('phone'),
      email: s('email'),
      address: s('address'),
      service: d['service'] != null ? s('service') : 'Service',
      method: s('paymentMethod'),
      ref: s('paymentRef'),
      total: total,
      advance: adv,
      balance: bal,
      advancePaid: advPaid,
      balancePaid: d['balancePaid'] == true || inv['status'] == 'paid',
      issuedAt:
          _dt(inv['issuedAt']) ?? _dt(d['acceptedAt']) ?? _dt(d['updatedAt']),
      advancePaidAt:
          _dt(inv['paidAt']) ??
          _dt(d['depositPaidAt']) ??
          _dt(d['advancePaidAt']),
      balancePaidAt: _dt(d['balancePaidAt']),
    );
  }
}

// ---------------------------------------------------------
// PAGE
// ---------------------------------------------------------
class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});
  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  static const _filters = ['All', 'Unpaid', 'Partial', 'Paid'];

  StreamSubscription? _sub;
  List<_Inv> _all = [];
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
            final list = <_Inv>[];
            for (final doc in snap.docs) {
              final i = _Inv.from(doc);
              if (i != null) list.add(i);
            }
            final epoch = DateTime.fromMillisecondsSinceEpoch(0);
            list.sort(
              (a, b) => (b.issuedAt ?? epoch).compareTo(a.issuedAt ?? epoch),
            );
            if (!mounted) return;
            setState(() {
              _all = list;
              _loading = false;
              _error = null;
            });
          },
          onError: (e) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error =
                  'Could not load invoices. Check your connection and permissions.';
            });
          },
        );
  }

  List<_Inv> get _visible {
    final s = _search.trim().toLowerCase();
    return _all.where((i) {
      if (_filter != 'All' && i.status != _filter) return false;
      if (s.isEmpty) return true;
      return i.number.toLowerCase().contains(s) ||
          i.customer.toLowerCase().contains(s) ||
          i.service.toLowerCase().contains(s) ||
          i.requestNo.toLowerCase().contains(s);
    }).toList();
  }

  int _count(String f) =>
      f == 'All' ? _all.length : _all.where((i) => i.status == f).length;

  void _snack(String msg) => Get.find<AppController>().snack(msg);

  // ----- export (CSV copied to clipboard) -----
  Future<void> _export() async {
    final list = _visible;
    if (list.isEmpty) {
      _snack('Nothing to export');
      return;
    }
    String e(String v) => '"${v.replaceAll('"', '""')}"';
    final b = StringBuffer(
      'Invoice,Request,Customer,Service,Total,Paid,Balance,Status,Issued\n',
    );
    for (final i in list) {
      b.writeln(
        [
          e(i.number),
          e(i.requestNo),
          e(i.customer),
          e(i.service),
          i.total.toStringAsFixed(2),
          i.paid.toStringAsFixed(2),
          i.outstanding.toStringAsFixed(2),
          e(i.status),
          e(_d(i.issuedAt)),
        ].join(','),
      );
    }
    await Clipboard.setData(ClipboardData(text: b.toString()));
    _snack('${list.length} invoices copied as CSV');
  }

  // ----- mark paid -----
  Future<void> _markPaid(_Inv i, {required bool balance}) async {
    final method = await showDialog<String>(
      context: context,
      builder: (dctx) => SimpleDialog(
        title: Text(
          balance ? 'Balance received via…' : 'Deposit received via…',
        ),
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
        .doc(i.id);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final cur = snap.exists ? _Inv.from(snap) : null;
        if (cur == null) throw StateError('missing');
        final amount = balance ? cur.balance : cur.advance;
        if (balance ? cur.balancePaid : cur.advancePaid) return;
        final note =
            '${balance ? 'Balance' : 'Deposit'} received (${_m(amount)}) · ${_cap(method)}';
        final history = FieldValue.arrayUnion([
          {
            'status': (snap.data()?['status'] ?? 'accepted'),
            'type': 'payment',
            'at': Timestamp.now(),
            'by': 'admin',
            'note': note,
          },
        ]);
        if (balance) {
          tx.update(ref, {
            'balancePaid': true,
            'balancePaidAt': FieldValue.serverTimestamp(),
            'balanceMethod': method,
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
            'paymentRef': 'ADMIN-${DateTime.now().millisecondsSinceEpoch}',
            'invoice.status': 'advance_paid',
            'invoice.paidAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'statusHistory': history,
          });
        }
      });
      _snack('${i.number} updated');
    } catch (e) {
      _snack('Could not update invoice. Check permissions.');
    }
  }

  void _open(_Inv i) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sctx) => _InvoiceSheet(
        inv: i,
        onCopy: () {
          Clipboard.setData(ClipboardData(text: _summary(i)));
          _snack('Invoice summary copied');
        },
        onMark: (balance) {
          Navigator.pop(sctx);
          _markPaid(i, balance: balance);
        },
      ),
    );
  }

  String _summary(_Inv i) =>
      'Invoice ${i.number}\n'
      'Customer: ${i.customer}\n'
      'Service: ${i.service} (${i.requestNo})\n'
      'Total: ${_m(i.total)}\n'
      'Deposit: ${_m(i.advance)} (${i.advancePaid ? 'PAID' : 'UNPAID'})\n'
      'Balance: ${_m(i.balance)} (${i.balancePaid ? 'PAID' : 'PENDING'})\n'
      'Status: ${i.status}';

  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final totalInvoiced = _all.fold<double>(0, (s, i) => s + i.total);
    final collected = _all.fold<double>(0, (s, i) => s + i.paid);
    final outstanding = _all.fold<double>(0, (s, i) => s + i.outstanding);
    final awaiting = _all.where((i) => !i.advancePaid).length;

    return PageScaffold(
      title: 'Invoices',
      subtitle: 'Live · auto-generated from approved quotes',
      actions: [
        OutlinedButton.icon(
          onPressed: _export,
          icon: const Icon(Icons.file_download),
          label: const Text('Export'),
        ),
      ],
      children: [
        _stats(totalInvoiced, collected, outstanding, awaiting),
        const SizedBox(height: 16),
        _toolbar(),
        const SizedBox(height: 14),
        _body(),
      ],
    );
  }

  Widget _stats(double total, double collected, double out, int awaiting) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final cols = w >= 900 ? 4 : (w >= 300 ? 2 : 1);
        const gap = 12.0;
        final iw = (w - gap * (cols - 1)) / cols;
        Widget card(
          String l,
          String v,
          IconData ic,
          Color c, [
          String sub = '',
        ]) => SizedBox(
          width: iw,
          child: _StatCard(label: l, value: v, icon: ic, color: c, sub: sub),
        );
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            card(
              'Total invoiced',
              _m(total),
              Icons.receipt_long,
              _K.ink,
              '${_all.length} invoices',
            ),
            card('Collected', _m(collected), Icons.check_circle, _K.green),
            card('Outstanding', _m(out), Icons.pending_actions, _K.red),
            card(
              'Awaiting deposit',
              '$awaiting',
              Icons.hourglass_top_rounded,
              _K.amber,
              'not paid yet',
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
            hintText: 'Search invoice, customer or service',
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
        icon: Icons.receipt_long_rounded,
        text: _all.isEmpty
            ? 'No invoices yet.\nThey appear when customers approve quotes.'
            : 'No invoices match your filter.',
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 900) return _table(list);
        return Column(
          children: [
            for (final i in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _InvoiceCard(inv: i, onTap: () => _open(i)),
              ),
          ],
        );
      },
    );
  }

  // ----- wide layout: table -----
  Widget _table(List<_Inv> list) {
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
                h('Invoice', 3),
                h('Service', 2),
                h('Total', 2, TextAlign.right),
                h('Paid', 2, TextAlign.right),
                h('Balance', 2, TextAlign.right),
                h('Issued', 2),
                h('Status', 2),
              ],
            ),
          ),
          for (var k = 0; k < list.length; k++) ...[
            InkWell(
              onTap: () => _open(list[k]),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            list[k].number,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _K.ink,
                            ),
                          ),
                          Text(
                            list[k].customer,
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
                        list[k].service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _m(list[k].total),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _m(list[k].paid),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _K.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _m(list[k].outstanding),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: list[k].outstanding > 0 ? _K.red : _K.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(flex: 2, child: Text(_d(list[k].issuedAt))),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _Badge(list[k].status, list[k].color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (k != list.length - 1) const Divider(height: 1, color: _K.line),
          ],
        ],
      ),
    );
  }
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
class _InvoiceCard extends StatelessWidget {
  final _Inv inv;
  final VoidCallback onTap;
  const _InvoiceCard({required this.inv, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget col(String l, String v, Color c) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: const TextStyle(color: _K.muted, fontSize: 11.5)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              v,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: _K.line),
            borderRadius: BorderRadius.circular(18),
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
                          inv.number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15.5,
                            color: _K.ink,
                          ),
                        ),
                        Text(
                          '${inv.customer} · ${inv.service}',
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
                  const SizedBox(width: 8),
                  _Badge(inv.status, inv.color),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  col('Total', _m(inv.total), _K.ink),
                  col('Paid', _m(inv.paid), _K.green),
                  col(
                    'Balance',
                    _m(inv.outstanding),
                    inv.outstanding > 0 ? _K.red : _K.muted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Issued ${_d(inv.issuedAt)}',
                style: const TextStyle(color: _K.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// DETAIL SHEET
// ---------------------------------------------------------
class _InvoiceSheet extends StatelessWidget {
  final _Inv inv;
  final VoidCallback onCopy;
  final void Function(bool balance) onMark;
  const _InvoiceSheet({
    required this.inv,
    required this.onCopy,
    required this.onMark,
  });

  Widget _kv(String k, String v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            k,
            style: TextStyle(
              color: bold ? _K.ink : _K.muted,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: color ?? _K.ink,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
              fontSize: bold ? 17 : 14,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _section(String title, List<Widget> children, {Color? tint}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tint ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _K.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                color: _K.ink,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _K.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: _K.line,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Invoice ${inv.number}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _K.ink,
                          ),
                        ),
                      ),
                      _Badge(inv.status, inv.color),
                      IconButton(
                        tooltip: 'Copy summary',
                        onPressed: onCopy,
                        icon: const Icon(Icons.copy_all_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _section('Customer', [
                    _kv('Name', inv.customer),
                    if (inv.phone.isNotEmpty) _kv('Phone', inv.phone),
                    if (inv.email.isNotEmpty) _kv('Email', inv.email),
                    if (inv.address.isNotEmpty) _kv('Address', inv.address),
                  ]),
                  _section('Job', [
                    _kv('Service', inv.service),
                    _kv('Request', inv.requestNo),
                    _kv('Issued', _d(inv.issuedAt)),
                  ]),
                  _section('Payment schedule', [
                    _kv('Total', _m(inv.total), bold: true),
                    const Divider(height: 18),
                    _kv('Deposit now', _m(inv.advance)),
                    _kv(
                      'Deposit status',
                      inv.advancePaid
                          ? 'Paid · ${_d(inv.advancePaidAt)}'
                          : 'Unpaid',
                      color: inv.advancePaid ? _K.green : _K.amber,
                    ),
                    const Divider(height: 18),
                    _kv('Balance (after job)', _m(inv.balance)),
                    _kv(
                      'Balance status',
                      inv.balancePaid
                          ? 'Paid · ${_d(inv.balancePaidAt)}'
                          : 'Pending',
                      color: inv.balancePaid ? _K.green : _K.muted,
                    ),
                    const Divider(height: 18),
                    _kv(
                      'Outstanding',
                      _m(inv.outstanding),
                      bold: true,
                      color: inv.outstanding > 0 ? _K.red : _K.green,
                    ),
                  ]),
                  if (inv.advancePaid)
                    _section('Deposit payment', [
                      _kv('Method', _cap(inv.method)),
                      _kv('Reference', inv.ref.isEmpty ? '—' : inv.ref),
                    ], tint: _K.green.withValues(alpha: .06)),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _K.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: _K.ink,
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  if (inv.outstanding > 0) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => onMark(inv.advancePaid),
                        icon: const Icon(Icons.payments_rounded, size: 18),
                        label: Text(
                          inv.advancePaid
                              ? 'MARK BALANCE PAID'
                              : 'MARK DEPOSIT PAID',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: _K.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Kept so other admin pages that call openInvoice(context, Invoice) still compile.
void openInvoice(BuildContext context, Invoice i) {
  final c = Get.find<AppController>();
  showDetail(
    context,
    title: 'Invoice ${i.id}',
    actions: [
      OutlinedButton.icon(
        onPressed: () => c.snack('Invoice PDF downloaded'),
        icon: const Icon(Icons.download),
        label: const Text('PDF'),
      ),
    ],
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KV('Bill to', i.customer),
        KV('Job', i.job),
        KV('Total', money(i.total), boldV: true),
        KV('Balance due', money(i.balance), boldV: true),
      ],
    ),
  );
}
