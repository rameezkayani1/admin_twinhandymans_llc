// =============================================================
// quotes_page.dart — Admin: Quotes overview (single file, live)
//
// Firestore (read only)
//   quotes/{id}          one doc per quote sent (created by Requests page)
//   quote_requests/{id}  joined by requestId to get the LIVE outcome:
//                        quoted -> Sent, changes_requested, accepted
//                        (+advancePaid), scheduled, completed, rejected
//
// How a quote is created: open a request in Requests page ->
// "Start review" -> enter total + advance -> "Send quote".
// It appears here instantly. Tap any quote to see details or jump
// to its request.
//
// Packages: cloud_firestore
// =============================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/widgets.dart';
// Adjust the path if your requests page lives elsewhere.
import '../requests/requests_page.dart' show openRequestById;

// ── Tokens ──────────────────────────────────────────────────
const _orange = Color(0xFFFF7A00);
const _navy = Color(0xFF1B1464);
const _ink = Color(0xFF1F2430);
const _muted = Color(0xFF7A8194);
const _line = Color(0xFFE6E9F2);
const _bg = Color(0xFFF6F7FB);
const _green = Color(0xFF22B573);

class _St {
  final String label;
  final Color color;
  const _St(this.label, this.color);
}

const _statuses = <String, _St>{
  'sent': _St('Sent', Color(0xFFC99700)),
  'changes': _St('Changes Requested', Color(0xFFE67E22)),
  'approved': _St('Approved', Color(0xFF1F8A5B)),
  'paid': _St('Deposit Paid', Color(0xFF22B573)),
  'scheduled': _St('Scheduled', Color(0xFF1B1464)),
  'completed': _St('Completed', Color(0xFF4F5D75)),
  'declined': _St('Declined', Color(0xFFD63638)),
  'expired': _St('Expired', Color(0xFF828282)),
};

/// Filter chips -> statuses they include.
const _filters = <String, List<String>>{
  'All': [],
  'Awaiting': ['sent'],
  'Changes': ['changes'],
  'Approved': ['approved', 'paid', 'scheduled', 'completed'],
  'Declined / Expired': ['declined', 'expired'],
};

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

// ── Helpers ─────────────────────────────────────────────────
String _money(num v) {
  final p = v.toStringAsFixed(2).split('.');
  final i = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '\$$i.${p[1]}';
}

String _d(DateTime d) => '${_mon[d.month - 1]} ${d.day}, ${d.year}';

String _ago(DateTime d) {
  final x = DateTime.now().difference(d);
  if (x.inMinutes < 1) return 'just now';
  if (x.inMinutes < 60) return '${x.inMinutes}m ago';
  if (x.inHours < 24) return '${x.inHours}h ago';
  if (x.inDays < 7) return '${x.inDays}d ago';
  return _d(d);
}

double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
}

DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

Widget _chip(String status, {bool small = false}) {
  final m = _statuses[status] ?? _St(status, Colors.grey);
  return Container(
    padding: EdgeInsets.symmetric(horizontal: small ? 9 : 12, vertical: 5),
    decoration: BoxDecoration(
      color: m.color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      m.label,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: small ? 11 : 12,
      ),
    ),
  );
}

// ── Model ───────────────────────────────────────────────────
class _Q {
  _Q(this.id, this.m, this.req);
  final String id;
  final Map<String, dynamic> m;
  final Map<String, dynamic>? req; // linked quote_requests doc (live)

  String s(String k) => (m[k] ?? '').toString();
  String get number => s('quoteNumber').isEmpty ? id : s('quoteNumber');
  String get requestId => s('requestId');
  String get requestNumber => s('requestNumber');
  String get customer =>
      s('customerName').isEmpty ? 'Customer' : s('customerName');
  String get service => s('service');

  double get total => _num(m['total']);
  double get deposit => _num(m['deposit']);
  double get balance => m['balance'] != null
      ? _num(m['balance'])
      : (total - deposit < 0 ? 0 : total - deposit);
  double get depositPct => total > 0 ? deposit / total * 100 : 0;

  DateTime? get issued => _ts(m['issuedAt']) ?? _ts(m['createdAt']);
  DateTime? get expires => _ts(m['expiresAt']);

  bool get advancePaid =>
      req?['advancePaid'] == true || req?['depositPaid'] == true;
  bool get balancePaid => req?['balancePaid'] == true;

  /// Live status, derived from the request (falls back to the quote doc).
  String get status {
    final rs = '${req?['status'] ?? ''}';
    var st = 'sent';
    if (rs.isEmpty) {
      switch (s('status')) {
        case 'accepted':
          st = 'approved';
        case 'declined':
          st = 'declined';
        case 'changes_requested':
          st = 'changes';
      }
    } else {
      switch (rs) {
        case 'changes_requested':
          st = 'changes';
        case 'accepted':
          st = advancePaid ? 'paid' : 'approved';
        case 'scheduled':
          st = 'scheduled';
        case 'completed':
          st = 'completed';
        case 'rejected':
        case 'cancelled':
          st = 'declined';
      }
    }
    if (st == 'sent' && expires != null && expires!.isBefore(DateTime.now())) {
      return 'expired';
    }
    return st;
  }

  /// Money actually collected so far.
  double get collected =>
      (advancePaid ? deposit : 0) + (balancePaid ? balance : 0);
}

// =============================================================
// PAGE
// =============================================================
class QuotesPage extends StatefulWidget {
  const QuotesPage({super.key});
  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> {
  final _db = FirebaseFirestore.instance;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _quotes = _db
      .collection('quotes')
      .orderBy('createdAt', descending: true)
      .snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _reqs = _db
      .collection('quote_requests')
      .snapshots();

  String _filter = 'All';
  String _q = '';

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Quotes',
    subtitle: 'Live overview of every quote sent to customers',
    children: [
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _quotes,
        builder: (context, qs) {
          if (qs.hasError) return _msg('Could not load quotes.\n${qs.error}');
          if (!qs.hasData) return _loading();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _reqs,
            builder: (context, rs) {
              final byId = <String, Map<String, dynamic>>{
                for (final d in rs.data?.docs ?? []) d.id: d.data(),
              };
              final all = [
                for (final d in qs.data!.docs)
                  _Q(d.id, d.data(), byId[d.data()['requestId']]),
              ];
              return _content(all);
            },
          );
        },
      ),
    ],
  );

  Widget _loading() => const Padding(
    padding: EdgeInsets.all(40),
    child: Center(child: CircularProgressIndicator()),
  );

  Widget _msg(String t) =>
      Padding(padding: const EdgeInsets.all(24), child: SelectableText(t));

  Widget _content(List<_Q> all) {
    final f = _filters[_filter]!;
    final q = _q.toLowerCase();
    int count(String k) => k == 'All'
        ? all.length
        : all.where((x) => _filters[k]!.contains(x.status)).length;

    final list = all.where((x) {
      if (f.isNotEmpty && !f.contains(x.status)) return false;
      if (q.isEmpty) return true;
      return '${x.customer} ${x.number} ${x.requestNumber} ${x.service} ${x.s('email')} ${x.s('phone')}'
          .toLowerCase()
          .contains(q);
    }).toList();

    final awaiting = all.where(
      (x) => x.status == 'sent' || x.status == 'changes',
    );
    final approved = all.where((x) => _filters['Approved']!.contains(x.status));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stats([
          _Stat(
            'Total quoted',
            _money(all.fold(0.0, (a, x) => a + x.total)),
            '${all.length} quotes',
            _navy,
          ),
          _Stat(
            'Awaiting response',
            _money(awaiting.fold(0.0, (a, x) => a + x.total)),
            '${awaiting.length} quotes',
            const Color(0xFFC99700),
          ),
          _Stat(
            'Approved value',
            _money(approved.fold(0.0, (a, x) => a + x.total)),
            '${approved.length} quotes',
            const Color(0xFF1F8A5B),
          ),
          _Stat(
            'Collected',
            _money(all.fold(0.0, (a, x) => a + x.collected)),
            'advance + balance',
            _green,
          ),
        ]),
        const SizedBox(height: 20),
        TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Search customer, quote #, request #, service',
            prefixIcon: const Icon(Icons.search, size: 20, color: _muted),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: _ob(_line),
            enabledBorder: _ob(_line),
            focusedBorder: _ob(_orange, 1.6),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final k in _filters.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: Text('$k  ${count(k)}'),
                    selected: _filter == k,
                    selectedColor: _orange,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: _line),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _filter == k ? Colors.white : _ink,
                    ),
                    onSelected: (_) => setState(() => _filter = k),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (all.isEmpty)
          _empty()
        else if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text('No quotes match', style: TextStyle(color: _muted)),
            ),
          )
        else
          LayoutBuilder(
            builder: (_, b) => b.maxWidth >= 860 ? _table(list) : _cards(list),
          ),
      ],
    );
  }

  OutlineInputBorder _ob(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: c, width: w),
  );

  // ── empty state with example flow ──
  Widget _empty() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'No quotes yet',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Quotes are created from customer requests. Example:\n\n'
          '1. Customer submits "Painting – 2 bedrooms" in the app.\n'
          '2. Open it in Requests → Start review.\n'
          '3. Enter Total \$1,200 and Advance 30% (\$360) → Send quote.\n'
          '4. It shows up here as "Sent" and updates live when the '
          'customer approves, pays the advance or asks for changes.',
          style: TextStyle(color: _muted, height: 1.5),
        ),
      ],
    ),
  );

  // ── stat cards ──
  Widget _stats(List<_Stat> items) => LayoutBuilder(
    builder: (_, b) {
      final cols = b.maxWidth >= 900 ? 4 : 2;
      const gap = 10.0;
      final w = ((b.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final s in items) SizedBox(width: w, child: _StatCard(s)),
        ],
      );
    },
  );

  // ── wide: table ──
  Widget _table(List<_Q> list) {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                cell(3, const Text('Customer / Quote', style: head)),
                cell(2, const Text('Service', style: head)),
                cell(2, const Text('Total', style: head)),
                cell(2, const Text('Advance', style: head)),
                cell(2, const Text('Balance', style: head)),
                cell(2, const Text('Expires', style: head)),
                cell(2, const Text('Status', style: head)),
                const SizedBox(width: 24),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          for (var i = 0; i < list.length; i++)
            InkWell(
              onTap: () => _openQuote(context, list[i]),
              child: Container(
                color: i.isOdd ? _bg : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    cell(
                      3,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            list[i].customer,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          Text(
                            list[i].number,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    cell(
                      2,
                      Text(list[i].service, overflow: TextOverflow.ellipsis),
                    ),
                    cell(
                      2,
                      Text(
                        _money(list[i].total),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    cell(
                      2,
                      Text(
                        '${_money(list[i].deposit)} (${list[i].depositPct.toStringAsFixed(0)}%)',
                        style: TextStyle(
                          color: list[i].advancePaid ? _green : _ink,
                          fontWeight: list[i].advancePaid
                              ? FontWeight.w700
                              : null,
                        ),
                      ),
                    ),
                    cell(2, Text(_money(list[i].balance))),
                    cell(
                      2,
                      Text(
                        list[i].expires == null ? '—' : _d(list[i].expires!),
                        style: const TextStyle(color: _muted),
                      ),
                    ),
                    cell(
                      2,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _chip(list[i].status),
                      ),
                    ),
                    const SizedBox(
                      width: 24,
                      child: Icon(Icons.chevron_right, color: _muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── narrow: cards ──
  Widget _cards(List<_Q> list) =>
      Column(children: [for (final x in list) _tile(x)]);

  Widget _tile(_Q x) {
    final color = _statuses[x.status]?.color ?? _orange;
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
          onTap: () => _openQuote(context, x),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            x.customer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _ink,
                            ),
                          ),
                          Text(
                            '${x.number} • ${x.service}',
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
                    _chip(x.status, small: true),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _kv('Total', _money(x.total), bold: true),
                    _kv(
                      'Advance',
                      _money(x.deposit),
                      color: x.advancePaid ? _green : null,
                    ),
                    _kv('Balance', _money(x.balance)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (x.issued != null) 'Sent ${_ago(x.issued!)}',
                    if (x.expires != null) 'Expires ${_d(x.expires!)}',
                  ].join(' • '),
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false, Color? color}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: _muted, fontSize: 11.5)),
        const SizedBox(height: 2),
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

// ── Stat card ───────────────────────────────────────────────
class _Stat {
  const _Stat(this.label, this.value, this.sub, this.color);
  final String label, value, sub;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.s);
  final _Stat s;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _line),
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        children: [
          Container(width: 5, color: s.color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      s.value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _navy,
                      ),
                    ),
                  ),
                  Text(
                    s.sub,
                    style: const TextStyle(color: _muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// =============================================================
// QUOTE DETAIL
// =============================================================
void _openQuote(BuildContext context, _Q q) {
  final narrow = MediaQuery.of(context).size.width < 700;
  showDialog(
    context: context,
    builder: (ctx) {
      final body = _QuoteDetail(q: q);
      return narrow
          ? Dialog.fullscreen(
              backgroundColor: _bg,
              child: SafeArea(child: body),
            )
          : Dialog(
              backgroundColor: _bg,
              insetPadding: const EdgeInsets.all(16),
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.of(context).size.height * .92,
                ),
                child: body,
              ),
            );
    },
  );
}

class _QuoteDetail extends StatelessWidget {
  const _QuoteDetail({required this.q});
  final _Q q;

  Widget _row(String k, String v, {Color? color, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(color: _muted)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            v.isEmpty ? '—' : v,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              fontSize: bold ? 16 : 14,
              color: color ?? _ink,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _card(String title, List<Widget> children) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            color: _ink,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final note = q.s('notes').isNotEmpty ? q.s('notes') : q.s('paymentNote');
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.number,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    Text(
                      '${q.customer} • ${q.service}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              _chip(q.status, small: true),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _card('Amounts', [
                  _row('Total quote', _money(q.total), bold: true),
                  _row(
                    'Advance (${q.depositPct.toStringAsFixed(0)}%)',
                    '${_money(q.deposit)}${q.advancePaid ? '  ✓ paid' : ''}',
                    color: q.advancePaid ? _green : _orange,
                    bold: true,
                  ),
                  _row(
                    'Balance after job',
                    '${_money(q.balance)}${q.balancePaid ? '  ✓ paid' : ''}',
                    color: q.balancePaid ? _green : null,
                  ),
                  const Divider(height: 20, color: _line),
                  _row('Collected so far', _money(q.collected)),
                ]),
                _card('Customer', [
                  _row('Name', q.customer),
                  _row('Phone', q.s('phone')),
                  _row('Email', q.s('email')),
                ]),
                _card('Dates & links', [
                  _row('Request', q.requestNumber),
                  _row('Sent', q.issued == null ? '' : _d(q.issued!)),
                  _row('Valid until', q.expires == null ? '' : _d(q.expires!)),
                ]),
                if (note.isNotEmpty)
                  _card('Note to customer', [
                    Text(note, style: const TextStyle(height: 1.45)),
                  ]),
              ],
            ),
          ),
        ),
        if (q.requestId.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            width: double.infinity,
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  openRequestById(context, q.requestId);
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open request / manage'),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
