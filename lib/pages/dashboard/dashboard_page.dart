// =============================================================
// dashboard_page.dart — ADMIN dashboard, 100% live Firebase data
//
// Reads (read-only, real-time):
//   quote_requests   -> every number, list and chart on this page
//   reviews          -> optional, field `rating` (num). If the
//                       collection is missing/empty the card shows "—"
//
// Field names it understands (same as the customer app):
//   status, quoteTotal / quoteAmount / quote{total}, depositNow,
//   depositLater, invoice{total,advance,balance,paidAt},
//   advancePaid / depositPaid, advancePaidAt / depositPaidAt,
//   paymentMethod, paymentRef, preferredDate, preferredSlot,
//   customerName, service, userId, assignedTo, createdAt
//
// Optional fields the ADMIN side may write (used when present):
//   scheduledDate   Timestamp  day the job happens (falls back to
//                              preferredDate)
//   balancePaid     bool       final payment received
//   balancePaidAt   Timestamp
//   assignedTo      string     crew / worker name
//
// Needs Firestore rules that let the admin read quote_requests.
// =============================================================
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../core/core.dart';
import '../../widgets/widgets.dart';
import '../quotes/quote_builder.dart';

// ---------------------------------------------------------
// helpers
// ---------------------------------------------------------
const _monthShort = [
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
const _dayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

double _n(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
}

double _pick(Map m, List<String> keys) {
  for (final k in keys) {
    final v = _n(m[k]);
    if (v > 0) return v;
  }
  return 0;
}

DateTime? _dt(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

bool _sameDay(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month && a.day == b.day;

bool _sameMonth(DateTime? a, DateTime b) =>
    a != null && a.year == b.year && a.month == b.month;

String _cap(String s) {
  final t = s.replaceAll('_', ' ').trim();
  return t.isEmpty ? '—' : t[0].toUpperCase() + t.substring(1);
}

// ---------------------------------------------------------
// MODELS
// ---------------------------------------------------------
class _Req {
  final String id, number, service, customer, userId, status;
  final String slot, address, crew, method, ref;
  final double budget, total, advance, balance;
  final bool advancePaid, balancePaid;
  final DateTime? createdAt, preferredDate, scheduledFor;
  final DateTime? advancePaidAt, balancePaidAt;

  const _Req({
    required this.id,
    required this.number,
    required this.service,
    required this.customer,
    required this.userId,
    required this.status,
    required this.slot,
    required this.address,
    required this.crew,
    required this.method,
    required this.ref,
    required this.budget,
    required this.total,
    required this.advance,
    required this.balance,
    required this.advancePaid,
    required this.balancePaid,
    this.createdAt,
    this.preferredDate,
    this.scheduledFor,
    this.advancePaidAt,
    this.balancePaidAt,
  });

  factory _Req.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    String s(String k) => (d[k] ?? '').toString();

    final qRaw = d['quote'];
    final q = qRaw is Map
        ? Map<String, dynamic>.from(qRaw)
        : <String, dynamic>{};
    final iRaw = d['invoice'];
    final inv = iRaw is Map
        ? Map<String, dynamic>.from(iRaw)
        : <String, dynamic>{};

    // ---- amounts: invoice snapshot wins, then quote map, then top level
    var total = _pick(inv, ['total']);
    if (total <= 0)
      total = _pick(q, ['total', 'amount', 'quoteTotal', 'price']);
    if (total <= 0)
      total = _pick(d, ['quoteTotal', 'quoteAmount', 'quotedAmount']);

    var advance = inv.containsKey('advance') ? _n(inv['advance']) : 0.0;
    if (advance <= 0)
      advance = _pick(q, ['depositNow', 'deposit', 'advance', 'payNow']);
    if (advance <= 0)
      advance = _pick(d, ['depositNow', 'advanceAmount', 'payNow']);
    if (advance <= 0 && total > 0) {
      final later = _pick(d, ['depositLater', 'payLater']);
      advance = (later > 0 && later < total) ? total - later : total * 0.30;
    }
    if (advance > total) advance = total;

    final balance = inv.containsKey('balance')
        ? _n(inv['balance'])
        : (total - advance).clamp(0.0, double.infinity).toDouble();

    final advPaid =
        d['advancePaid'] == true ||
        d['depositPaid'] == true ||
        s('paymentStatus') == 'paid' ||
        inv['status'] == 'advance_paid';

    final num = d['requestNumber'] != null
        ? s('requestNumber')
        : doc.id
              .substring(0, doc.id.length < 6 ? doc.id.length : 6)
              .toUpperCase();

    return _Req(
      id: doc.id,
      number: num,
      service: d['service'] != null ? s('service') : 'Service',
      customer: s('customerName').isEmpty ? 'Customer' : s('customerName'),
      userId: s('userId'),
      status: d['status'] == null ? 'pending' : s('status'),
      slot: s('preferredSlot'),
      address: s('address'),
      crew: s('assignedTo'),
      method: s('paymentMethod'),
      ref: s('paymentRef'),
      budget: _n(d['budget']),
      total: total,
      advance: advance,
      balance: balance,
      advancePaid: advPaid,
      balancePaid: d['balancePaid'] == true,
      createdAt: _dt(d['createdAt']),
      preferredDate: _dt(d['preferredDate']),
      scheduledFor: _dt(d['scheduledDate']),
      advancePaidAt:
          _dt(d['depositPaidAt']) ??
          _dt(d['advancePaidAt']) ??
          _dt(inv['paidAt']) ??
          _dt(d['updatedAt']),
      balancePaidAt: _dt(d['balancePaidAt']) ?? _dt(d['updatedAt']),
    );
  }

  static const invoicedStates = [
    'accepted',
    'scheduled',
    'in_progress',
    'completed',
  ];

  bool get invoiced => invoicedStates.contains(status);
  bool get isOpenRequest =>
      const ['pending', 'reviewing', 'changes_requested'].contains(status);
  DateTime? get jobDay => scheduledFor ?? preferredDate;

  /// Money still owed to us on this job.
  double get outstanding {
    if (!invoiced) return 0;
    var due = advancePaid ? 0.0 : advance;
    if (status == 'completed' && !balancePaid) due += balance;
    return due;
  }
}

class _Payment {
  final String customer, method, ref, kind;
  final double amount;
  final DateTime date;
  const _Payment(
    this.customer,
    this.method,
    this.ref,
    this.kind,
    this.amount,
    this.date,
  );
}

// ---------------------------------------------------------
// CONTROLLER (live streams + derived metrics)
// ---------------------------------------------------------
class DashboardController extends GetxController {
  final _db = FirebaseFirestore.instance;
  final reqs = <_Req>[].obs;
  final ratings = <double>[].obs;
  final loading = true.obs;
  final error = ''.obs;
  StreamSubscription? _reqSub, _revSub;

  @override
  void onInit() {
    super.onInit();
    _reqSub = _db
        .collection('quote_requests')
        .snapshots()
        .listen(
          (snap) {
            reqs.assignAll(snap.docs.map(_Req.fromDoc));
            loading.value = false;
            error.value = '';
          },
          onError: (_) {
            loading.value = false;
            error.value =
                'Could not load live data. Check your connection and Firestore rules.';
          },
        );
    // Optional collection: failures are ignored on purpose.
    _revSub = _db
        .collection('reviews')
        .snapshots()
        .listen(
          (snap) => ratings.assignAll(
            snap.docs.map((d) => _n(d.data()['rating'])).where((r) => r > 0),
          ),
          onError: (_) => ratings.clear(),
        );
  }

  @override
  void onClose() {
    _reqSub?.cancel();
    _revSub?.cancel();
    super.onClose();
  }

  // ----- counts -----
  int count(bool Function(_Req r) test) => reqs.where(test).length;

  int get openRequests => count((r) => r.isOpenRequest);
  int get quotesSent => count((r) => r.status == 'quoted');
  int get approvedQuotes => count((r) => r.invoiced);
  int get awaitingDeposit =>
      count((r) => r.status == 'accepted' && !r.advancePaid);
  int get scheduled => count((r) => r.status == 'scheduled');
  int get inProgress => count((r) => r.status == 'in_progress');
  int get finalDue =>
      count((r) => r.status == 'completed' && !r.balancePaid && r.balance > 0);

  List<_Req> jobsOn(DateTime day) =>
      reqs
          .where(
            (r) =>
                (r.status == 'scheduled' || r.status == 'in_progress') &&
                _sameDay(r.jobDay, day),
          )
          .toList()
        ..sort((a, b) => a.slot.compareTo(b.slot));

  List<_Req> get newRequests =>
      reqs.where((r) => r.status == 'pending').toList()..sort(
        (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
          a.createdAt ?? DateTime(2000),
        ),
      );

  // ----- money -----
  double get outstanding => reqs.fold(0.0, (s, r) => s + r.outstanding);

  List<_Payment> get payments {
    final out = <_Payment>[];
    for (final r in reqs) {
      if (r.advancePaid && r.advance > 0) {
        out.add(
          _Payment(
            r.customer,
            r.method,
            r.ref,
            'Deposit',
            r.advance,
            r.advancePaidAt ?? r.createdAt ?? DateTime.now(),
          ),
        );
      }
      if (r.balancePaid && r.balance > 0) {
        out.add(
          _Payment(
            r.customer,
            r.method,
            r.ref,
            'Final',
            r.balance,
            r.balancePaidAt ?? r.createdAt ?? DateTime.now(),
          ),
        );
      }
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  double get collected => payments.fold(0.0, (s, p) => s + p.amount);

  double revenueIn(DateTime month) => payments
      .where((p) => _sameMonth(p.date, month))
      .fold(0.0, (s, p) => s + p.amount);

  /// Oldest -> newest, 6 entries ending with the current month.
  List<MapEntry<String, double>> get last6Months {
    final now = DateTime.now();
    return [
      for (var i = 5; i >= 0; i--)
        () {
          final m = DateTime(now.year, now.month - i, 1);
          return MapEntry(_monthShort[m.month - 1], revenueIn(m));
        }(),
    ];
  }

  // ----- customers / reviews -----
  int get newCustomers {
    final now = DateTime.now();
    final first = <String, DateTime>{};
    for (final r in reqs) {
      if (r.userId.isEmpty || r.createdAt == null) continue;
      final cur = first[r.userId];
      if (cur == null || r.createdAt!.isBefore(cur))
        first[r.userId] = r.createdAt!;
    }
    return first.values.where((d) => _sameMonth(d, now)).length;
  }

  double get avgRating =>
      ratings.isEmpty ? 0 : ratings.reduce((a, b) => a + b) / ratings.length;
}

// ---------------------------------------------------------
// PAGE
// ---------------------------------------------------------
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppController>(); // navigation (c.page) only
    final d = Get.put(DashboardController());

    return Obx(() {
      final now = DateTime.now();
      final name = (FirebaseAuth.instance.currentUser?.displayName ?? '')
          .trim();
      final subtitle =
          '${_dayLong[now.weekday - 1]}, ${_monthShort[now.month - 1]} ${now.day}, ${now.year}'
          '${name.isEmpty ? '' : ' • Welcome back, ${name.split(' ').first}'}';

      final actions = <Widget>[
        OutlinedButton.icon(
          onPressed: () => c.page.value = 2,
          icon: const Icon(Icons.inbox),
          label: Text(
            d.openRequests > 0
                ? 'Quote Requests (${d.openRequests})'
                : 'Quote Requests',
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => openQuoteBuilder(context),
          icon: const Icon(Icons.add),
          label: const Text('NEW QUOTE'),
        ),
      ];

      if (d.loading.value) {
        return PageScaffold(
          title: 'Business Overview',
          subtitle: subtitle,
          actions: actions,
          children: const [
            SizedBox(
              height: 320,
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      }

      final today = d.jobsOn(now);
      final months = d.last6Months;
      final maxRev = months
          .map((e) => e.value)
          .fold(0.0, (a, b) => a > b ? a : b);
      final thisMonth = d.revenueIn(now);
      final lastMonth = d.revenueIn(DateTime(now.year, now.month - 1, 1));
      final delta = lastMonth > 0
          ? (thisMonth - lastMonth) / lastMonth * 100
          : null;
      final payments = d.payments;

      return PageScaffold(
        title: 'Business Overview',
        subtitle: subtitle,
        actions: actions,
        children: [
          if (d.error.value.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              color: C.red.withValues(alpha: .1),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: C.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(d.error.value)),
                ],
              ),
            ),
          Grid(
            minWidth: 250,
            children: [
              Stat(
                "Today's Jobs",
                '${today.length}',
                Icons.construction,
                onTap: () => c.page.value = 4,
              ),
              Stat(
                'Pending Quotes',
                '${d.quotesSent}',
                Icons.hourglass_bottom,
                color: C.orange,
                hint: 'Waiting for customer',
                onTap: () => c.page.value = 3,
              ),
              Stat(
                'Approved Quotes',
                '${d.approvedQuotes}',
                Icons.check_circle_outline,
                color: C.green,
                onTap: () => c.page.value = 3,
              ),
              Stat(
                'Outstanding Invoices',
                money(d.outstanding),
                Icons.receipt_long,
                color: C.red,
                hint: 'Unpaid deposits + final balances',
                onTap: () => c.page.value = 6,
              ),
              Stat(
                'Monthly Revenue',
                money(thisMonth),
                Icons.trending_up,
                color: C.green,
                hint: delta == null
                    ? 'Collected this month'
                    : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}% vs last month',
              ),
              Stat(
                'Payments Received',
                money(d.collected),
                Icons.payments,
                color: C.blue,
                hint:
                    '${payments.length} payment${payments.length == 1 ? '' : 's'}',
                onTap: () => c.page.value = 7,
              ),
              Stat(
                'New Customers',
                '${d.newCustomers}',
                Icons.person_add_alt,
                hint: 'This month',
              ),
              Stat(
                'Reviews',
                d.ratings.isEmpty ? '—' : '${d.avgRating.toStringAsFixed(1)} ★',
                Icons.star,
                color: C.yellow,
                hint: '${d.ratings.length} reviews',
                onTap: () => c.page.value = 10,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final two = box.maxWidth >= 900;

              final left = Column(
                children: [
                  Panel(
                    title: 'Revenue (last 6 months)',
                    child: SizedBox(
                      height: 220,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < months.length; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      months[i].value >= 1000
                                          ? '\$${(months[i].value / 1000).toStringAsFixed(1)}k'
                                          : '\$${months[i].value.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: maxRev <= 0
                                          ? 2
                                          : (150 * months[i].value / maxRev)
                                                .clamp(2.0, 150.0),
                                      color: i == months.length - 1
                                          ? C.yellow
                                          : C.navy,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      months[i].key,
                                      style: const TextStyle(
                                        color: C.muted,
                                        fontSize: 12,
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
                  const SizedBox(height: 16),
                  Panel(
                    title: "Today's Jobs",
                    trailing: TextButton(
                      onPressed: () => c.page.value = 5,
                      child: const Text('Open calendar'),
                    ),
                    child: today.isEmpty
                        ? const _EmptyRow('No jobs scheduled for today.')
                        : Column(
                            children: [
                              for (final j in today)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    width: 64,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    color: C.navy,
                                    child: Text(
                                      j.slot.isEmpty
                                          ? 'TBD'
                                          : j.slot.split(' (').first,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: C.yellow,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    '${j.service} • ${j.customer}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${j.address.isEmpty ? '—' : j.address}\n'
                                    '${j.crew.isEmpty ? 'Unassigned' : j.crew}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Chip2(_cap(j.status)),
                                  onTap: () => c.page.value = 4,
                                ),
                            ],
                          ),
                  ),
                ],
              );

              final pipeline = <List<dynamic>>[
                ['Quote Requests', d.openRequests, C.orange],
                ['Quotes Sent', d.quotesSent, C.blue],
                ['Awaiting Deposit', d.awaitingDeposit, C.yellow],
                ['Scheduled', d.scheduled, C.navy],
                ['In Progress', d.inProgress, C.green],
                ['Final Payment Due', d.finalDue, C.red],
              ];

              final fresh = d.newRequests.take(3).toList();

              final right = Column(
                children: [
                  Panel(
                    title: 'Job Pipeline',
                    child: Column(
                      children: [
                        for (final g in pipeline)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  color: g[2] as Color,
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(g[0] as String)),
                                Text(
                                  '${g[1]}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    title: 'New Quote Requests',
                    trailing: TextButton(
                      onPressed: () => c.page.value = 2,
                      child: const Text('View all'),
                    ),
                    child: fresh.isEmpty
                        ? const _EmptyRow('No new requests.')
                        : Column(
                            children: [
                              for (final r in fresh)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${r.service} • ${r.customer}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Budget ${money(r.budget)} • '
                                    '${r.createdAt == null ? '—' : fmtDate(r.createdAt!)}',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => c.page.value = 2,
                                ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    title: 'Recent Payments',
                    child: payments.isEmpty
                        ? const _EmptyRow('No payments yet.')
                        : Column(
                            children: [
                              for (final p in payments.take(4))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    p.customer,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${p.kind} • ${_cap(p.method)} • ${fmtDate(p.date)}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        money(p.amount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const Chip2('Paid'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                ],
              );

              return two
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: left),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: right),
                      ],
                    )
                  : Column(children: [left, const SizedBox(height: 16), right]);
            },
          ),
        ],
      );
    });
  }
}

class _EmptyRow extends StatelessWidget {
  final String text;
  const _EmptyRow(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: Text(text, style: const TextStyle(color: C.muted)),
    ),
  );
}
// import 'package:admin_twinhandymans_llc/old/models/job.dart';
// import 'package:admin_twinhandymans_llc/old/pages/jobs/jobs_page.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// import '../../controllers/app_controller.dart';
// import '../../core/core.dart';
// import '../../widgets/widgets.dart';
// import '../jobs/jobs_page.dart';
// import '../quotes/quote_builder.dart';
// import '../requests/requests_page.dart';

// class DashboardPage extends StatelessWidget {
//   const DashboardPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final c = Get.find<AppController>();
//     return Obx(() {
//       final today = c.jobsOn(DateTime(2026, 10, 4));
//       final pending = c.quotes.where((q) => q.status == 'Sent').length;
//       final approved = c.quotes.where((q) => q.status == 'Approved').length;
//       final maxRev = c.monthlyRevenue.values.reduce((a, b) => a > b ? a : b);
//       return PageScaffold(
//         title: 'Business Overview',
//         subtitle: 'Sunday, Oct 4, 2026 • Welcome back, Mathew',
//         actions: [
//           OutlinedButton.icon(
//             onPressed: () => c.page.value = 2,
//             icon: const Icon(Icons.inbox),
//             label: const Text('Quote Requests'),
//           ),
//           ElevatedButton.icon(
//             onPressed: () => openQuoteBuilder(context),
//             icon: const Icon(Icons.add),
//             label: const Text('NEW QUOTE'),
//           ),
//         ],
//         children: [
//           Grid(
//             minWidth: 250,
//             children: [
//               Stat(
//                 "Today's Jobs",
//                 '${today.length}',
//                 Icons.construction,
//                 onTap: () => c.page.value = 4,
//               ),
//               Stat(
//                 'Pending Quotes',
//                 '$pending',
//                 Icons.hourglass_bottom,
//                 color: C.orange,
//                 onTap: () => c.page.value = 3,
//               ),
//               Stat(
//                 'Approved Quotes',
//                 '$approved',
//                 Icons.check_circle_outline,
//                 color: C.green,
//                 onTap: () => c.page.value = 3,
//               ),
//               Stat(
//                 'Outstanding Invoices',
//                 money(c.outstanding),
//                 Icons.receipt_long,
//                 color: C.red,
//                 onTap: () => c.page.value = 6,
//               ),
//               Stat(
//                 'Monthly Revenue',
//                 money(12420),
//                 Icons.trending_up,
//                 color: C.green,
//                 hint: '+8.4% vs last month',
//               ),
//               Stat(
//                 'Payments Received',
//                 money(c.collected),
//                 Icons.payments,
//                 color: C.blue,
//                 onTap: () => c.page.value = 7,
//               ),
//               Stat(
//                 'New Customers',
//                 '6',
//                 Icons.person_add_alt,
//                 hint: 'This month',
//               ),
//               Stat(
//                 'Reviews',
//                 '${c.avgRating.toStringAsFixed(1)} ★',
//                 Icons.star,
//                 color: C.yellow,
//                 hint: '${c.reviews.length} reviews',
//                 onTap: () => c.page.value = 10,
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           LayoutBuilder(
//             builder: (context, box) {
//               final two = box.maxWidth >= 900;
//               final left = Column(
//                 children: [
//                   Panel(
//                     title: 'Revenue (last 6 months)',
//                     child: SizedBox(
//                       height: 220,
//                       child: Row(
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           for (final e in c.monthlyRevenue.entries)
//                             Expanded(
//                               child: Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 6,
//                                 ),
//                                 child: Column(
//                                   mainAxisAlignment: MainAxisAlignment.end,
//                                   children: [
//                                     Text(
//                                       '\$${(e.value / 1000).toStringAsFixed(1)}k',
//                                       style: const TextStyle(
//                                         fontSize: 11,
//                                         fontWeight: FontWeight.w700,
//                                       ),
//                                     ),
//                                     const SizedBox(height: 4),
//                                     Container(
//                                       height: 150 * e.value / maxRev,
//                                       color: e.key == 'Oct' ? C.yellow : C.navy,
//                                     ),
//                                     const SizedBox(height: 6),
//                                     Text(
//                                       e.key,
//                                       style: const TextStyle(
//                                         color: C.muted,
//                                         fontSize: 12,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Panel(
//                     title: "Today's Jobs",
//                     trailing: TextButton(
//                       onPressed: () => c.page.value = 5,
//                       child: const Text('Open calendar'),
//                     ),
//                     child: Column(
//                       children: [
//                         for (final j in today)
//                           ListTile(
//                             contentPadding: EdgeInsets.zero,
//                             leading: Container(
//                               width: 64,
//                               padding: const EdgeInsets.symmetric(vertical: 8),
//                               color: C.navy,
//                               child: Text(
//                                 j.time,
//                                 textAlign: TextAlign.center,
//                                 style: const TextStyle(
//                                   color: C.yellow,
//                                   fontWeight: FontWeight.w800,
//                                   fontSize: 12,
//                                 ),
//                               ),
//                             ),
//                             title: Text(
//                               '${j.service} • ${j.customer}',
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                             subtitle: Text('${j.address}\n${j.crew}'),
//                             isThreeLine: true,
//                             trailing: Chip2(jobStages[j.stage]),
//                             onTap: () => openJob(context, j as Job),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               );
//               final right = Column(
//                 children: [
//                   Panel(
//                     title: 'Job Pipeline',
//                     child: Column(
//                       children: [
//                         for (final g in [
//                           [
//                             'Quote Requests',
//                             c.requests
//                                 .where(
//                                   (r) =>
//                                       r.status == 'New' ||
//                                       r.status == 'In Review',
//                                 )
//                                 .length,
//                             C.orange,
//                           ],
//                           ['Quotes Sent', pending, C.blue],
//                           [
//                             'Awaiting Deposit',
//                             c.quotes
//                                 .where((q) => q.status == 'Approved')
//                                 .length,
//                             C.yellow,
//                           ],
//                           [
//                             'Scheduled',
//                             c.jobs
//                                 .where((j) => j.stage >= 4 && j.stage < 6)
//                                 .length,
//                             C.navy,
//                           ],
//                           [
//                             'In Progress',
//                             c.jobs
//                                 .where((j) => j.stage >= 6 && j.stage < 8)
//                                 .length,
//                             C.green,
//                           ],
//                           [
//                             'Final Payment Due',
//                             c.jobs
//                                 .where((j) => j.stage >= 8 && j.stage < 10)
//                                 .length,
//                             C.red,
//                           ],
//                         ])
//                           Padding(
//                             padding: const EdgeInsets.symmetric(vertical: 7),
//                             child: Row(
//                               children: [
//                                 Container(
//                                   width: 10,
//                                   height: 10,
//                                   color: g[2] as Color,
//                                 ),
//                                 const SizedBox(width: 10),
//                                 Expanded(child: Text(g[0] as String)),
//                                 Text(
//                                   '${g[1]}',
//                                   style: const TextStyle(
//                                     fontWeight: FontWeight.w900,
//                                     fontSize: 16,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Panel(
//                     title: 'New Quote Requests',
//                     trailing: TextButton(
//                       onPressed: () => c.page.value = 2,
//                       child: const Text('View all'),
//                     ),
//                     child: Column(
//                       children: [
//                         for (final r
//                             in c.requests
//                                 .where((r) => r.status == 'New')
//                                 .take(3))
//                           ListTile(
//                             contentPadding: EdgeInsets.zero,
//                             title: Text(
//                               '${r.service} • ${r.customer}',
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                             subtitle: Text(
//                               'Budget ${money(r.budget)} • ${fmtDate(r.date)}',
//                             ),
//                             trailing: const Icon(Icons.chevron_right),
//                             onTap: () => RequestsPage(),
//                           ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Panel(
//                     title: 'Recent Payments',
//                     child: Column(
//                       children: [
//                         for (final p in c.payments.take(4))
//                           ListTile(
//                             contentPadding: EdgeInsets.zero,
//                             title: Text(
//                               p.customer,
//                               style: const TextStyle(
//                                 fontWeight: FontWeight.w700,
//                               ),
//                             ),
//                             subtitle: Text('${p.method} • ${fmtDate(p.date)}'),
//                             trailing: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               crossAxisAlignment: CrossAxisAlignment.end,
//                               children: [
//                                 Text(
//                                   money(p.amount),
//                                   style: const TextStyle(
//                                     fontWeight: FontWeight.w900,
//                                   ),
//                                 ),
//                                 Chip2(p.status),
//                               ],
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               );
//               return two
//                   ? Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Expanded(flex: 3, child: left),
//                         const SizedBox(width: 16),
//                         Expanded(flex: 2, child: right),
//                       ],
//                     )
//                   : Column(children: [left, const SizedBox(height: 16), right]);
//             },
//           ),
//         ],
//       );
//     });
//   }
// }
