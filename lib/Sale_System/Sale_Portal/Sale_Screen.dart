// Save as: lib/Admin/pages/sales/sales_portal_page.dart
//
// Navigate here after a successful, APPROVED login:
//     Get.offAll(() => const SalesPortalPage());
import 'dart:async';
import 'dart:typed_data';

import 'package:admin_twinhandymans_llc/Admin/widgets/widgets.dart'; // Logo()
import 'package:admin_twinhandymans_llc/Sale_System/Registration_form.dart';
import 'package:admin_twinhandymans_llc/Sale_System/Sale_Portal/Sale_Service.dart';
import 'package:admin_twinhandymans_llc/Sale_System/Sale_Portal/Sale_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

const _bg = Color(0xFF070F24);
const _bg2 = Color(0xFF0B1735);
const _accent = Color(0xFF4F8CFF);
const _accent2 = Color(0xFF7C5CFF);
const _green = Color(0xFF34D399);
const _amber = Color(0xFFFFC857);
const _cyan = Color(0xFF22D3EE);

const _defaultRate = 0.10;

// =========================================================
// CONTROLLER
// =========================================================
class PortalController extends GetxController {
  final svc = SalesService.instance;
  final uid = FirebaseAuth.instance.currentUser!.uid;

  final section = 0.obs;
  final ready = false.obs;
  final denied = RxnString();
  String? deniedReason;

  final rep = Rxn<Map<String, dynamic>>();
  final leads = <Lead>[].obs;
  final commissions = <CommissionRec>[].obs;
  final notifs = <AppNotification>[].obs;
  final promos = <Map<String, dynamic>>[].obs;

  final _subs = <StreamSubscription>[];

  String get repName => (rep.value?['name'] as String?) ?? '';
  String get repId => (rep.value?['repId'] as String?) ?? 'Pending';
  double get rate {
    final r = rep.value?['commissionRate'];
    return r is num ? r.toDouble() : _defaultRate;
  }

  int get unread => notifs.where((n) => !n.read).length;

  // Dashboard numbers
  int get wonCount => leads.where((l) => LeadStatus.isWon(l.status)).length;
  int get completedCount =>
      leads.where((l) => l.status == LeadStatus.completed).length;
  int get openCount => leads.where((l) => LeadStatus.isOpen(l.status)).length;
  double get wonValue => leads
      .where((l) => LeadStatus.isWon(l.status))
      .fold(0.0, (a, l) => a + l.contractValue);
  double get awaiting =>
      commissions.fold(0.0, (a, c) => a + c.awaitingCustomer);
  double get review => commissions.fold(0.0, (a, c) => a + c.underReview);
  double get ready2pay => commissions.fold(0.0, (a, c) => a + c.readyToPay);
  double get paid => commissions.fold(0.0, (a, c) => a + c.paidAmount);
  double get totalEarned => commissions.fold(0.0, (a, c) => a + c.total);
  double get conversion => leads.isEmpty ? 0 : wonCount / leads.length;

  @override
  void onInit() {
    super.onInit();
    _start();
  }

  Future<void> _start() async {
    try {
      final access = await fetchRepAccess(uid);
      if (!access.approved) {
        deniedReason = access.reason;
        denied.value = access.status;
        return;
      }
      void onErr(Object e) => debugPrint('❌ portal stream error: $e');
      _subs.addAll([
        svc.repStream(uid).listen((d) {
          rep.value = d;
          final st = ((d?['status'] as String?) ?? 'pending').toLowerCase();
          if (st != 'approved' && denied.value == null) denied.value = st;
        }, onError: onErr),
        svc.leads(uid).listen(leads.assignAll, onError: onErr),
        svc.commissions(uid).listen(commissions.assignAll, onError: onErr),
        svc.notifications(uid).listen(notifs.assignAll, onError: onErr),
        svc.promos().listen(promos.assignAll, onError: onErr),
      ]);
      ready.value = true;
      final prefs = rep.value?['prefs'];
      if (prefs is Map && prefs['push'] == false) return;
      svc.registerPush(uid);
    } catch (e) {
      debugPrint('❌ portal init: $e');
      denied.value = 'pending';
    }
  }

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.onClose();
  }
}

// =========================================================
// SHELL
// =========================================================
const _nav = <(IconData, String)>[
  (Icons.dashboard_outlined, 'Dashboard'),
  (Icons.people_alt_outlined, 'My leads'),
  (Icons.add_circle_outline, 'Submit a lead'),
  (Icons.payments_outlined, 'Commissions'),
  (Icons.menu_book_outlined, 'Resources & promos'),
  (Icons.person_outline, 'Profile'),
];

class SalesPortalPage extends StatefulWidget {
  const SalesPortalPage({super.key});
  @override
  State<SalesPortalPage> createState() => _SalesPortalPageState();
}

class _SalesPortalPageState extends State<SalesPortalPage> {
  late final PortalController c;
  Worker? _w;

  @override
  void initState() {
    super.initState();
    Get.delete<PortalController>(force: true);
    c = Get.put(PortalController());
    _w = ever<String?>(c.denied, (s) async {
      if (s == null || !mounted) return;
      await showApprovalDialog(context, s, reason: c.deniedReason);
      await FirebaseAuth.instance.signOut(); // AuthGate returns to login
    });
  }

  @override
  void dispose() {
    _w?.dispose();
    Get.delete<PortalController>(force: true);
    super.dispose();
  }

  Widget _body() {
    switch (c.section.value) {
      case 1:
        return _LeadsView(c);
      case 2:
        return _SubmitLeadView(c);
      case 3:
        return _CommissionsView(c);
      case 4:
        return _ResourcesView(c);
      case 5:
        return _ProfileView(c);
      default:
        return _DashboardView(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: _bg,
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: _bg2,
              child: SafeArea(child: _Sidebar(c, closeOnTap: true)),
            ),
      appBar: AppBar(
        backgroundColor: _bg2,
        elevation: 0,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !wide,
        title: Obx(
          () => Text(
            _nav[c.section.value].$2,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Notifications',
              onPressed: () => _showNotifications(context, c),
              icon: Badge(
                isLabelVisible: c.unread > 0,
                label: Text('${c.unread}'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: wide
          ? null
          : Obx(
              () => c.section.value == 2
                  ? const SizedBox.shrink()
                  : FloatingActionButton.extended(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      onPressed: () => c.section.value = 2,
                      icon: const Icon(Icons.add),
                      label: const Text('New lead'),
                    ),
            ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF070F24), Color(0xFF0E1F46), Color(0xFF1B1646)],
          ),
        ),
        child: Row(
          children: [
            if (wide) SizedBox(width: 260, child: _Sidebar(c)),
            Expanded(
              child: Obx(() {
                if (!c.ready.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: SingleChildScrollView(
                      key: ValueKey(c.section.value),
                      padding: EdgeInsets.all(wide ? 28 : 14),
                      child: _body(),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar(this.c, {this.closeOnTap = false});
  final PortalController c;
  final bool closeOnTap;

  @override
  Widget build(BuildContext context) => Container(
    color: _bg2,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(child: Logo()),
        ),
        const SizedBox(height: 18),
        Obx(
          () => _Card(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _accent,
                  child: Text(
                    c.repName.isEmpty ? '?' : c.repName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.repName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Rep ID: ${c.repId}',
                        style: const TextStyle(color: _cyan, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < _nav.length; i++)
          Obx(() {
            final sel = c.section.value == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: sel ? _accent.withOpacity(0.22) : null,
                leading: Icon(
                  _nav[i].$1,
                  color: sel ? Colors.white : Colors.white60,
                ),
                title: Text(
                  _nav[i].$2,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.white70,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                onTap: () {
                  c.section.value = i;
                  if (closeOnTap) Navigator.of(context).pop();
                },
              ),
            );
          }),
        const Spacer(),
        TextButton.icon(
          onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout, color: Colors.white60),
          label: const Text(
            'Sign out',
            style: TextStyle(color: Colors.white60),
          ),
        ),
      ],
    ),
  );
}

// =========================================================
// SHARED WIDGETS
// =========================================================
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(0.12)),
    ),
    child: child,
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon, this.color, {this.sub});
  final String label, value;
  final String? sub;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => _Card(
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 12.5),
              ),
              if (sub != null)
                Text(sub!, style: TextStyle(color: color, fontSize: 11.5)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StatGrid extends StatelessWidget {
  const _StatGrid(this.items);
  final List<Widget> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, b) {
      final cols = b.maxWidth >= 900 ? 4 : (b.maxWidth >= 520 ? 2 : 1);
      final w = (b.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final i in items) SizedBox(width: w, child: i)],
      );
    },
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.16),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => _Card(
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.white38),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
        ],
      ),
    ),
  );
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onTap,
    this.loading = false,
    this.icon,
  });
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: loading ? 0.7 : 1,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(colors: [_accent, _accent2]),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: loading ? null : onTap,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}

InputDecoration _dec(
  String label,
  IconData icon, {
  String? prefix,
  String? hint,
}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix,
    prefixStyle: const TextStyle(color: Colors.white),
    hintStyle: const TextStyle(color: Colors.white38),
    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
    floatingLabelStyle: const TextStyle(color: Colors.white),
    prefixIcon: Icon(icon, color: Colors.white70),
    filled: true,
    fillColor: Colors.white.withOpacity(0.08),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
    enabledBorder: b(Colors.white.withOpacity(0.18)),
    border: b(Colors.white.withOpacity(0.18)),
    focusedBorder: b(_accent, 1.6),
  );
}

const _white = TextStyle(color: Colors.white);

// =========================================================
// 0 · DASHBOARD
// =========================================================
class _DashboardView extends StatelessWidget {
  const _DashboardView(this.c);
  final PortalController c;

  @override
  Widget build(BuildContext context) => Obx(() {
    final now = DateTime.now();
    final months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i, 1),
    );
    final submitted = <int>[];
    final won = <int>[];
    for (final m in months) {
      final inM = c.leads.where(
        (l) => l.createdAt.year == m.year && l.createdAt.month == m.month,
      );
      submitted.add(inM.length);
      won.add(inM.where((l) => LeadStatus.isWon(l.status)).length);
    }
    final yearLeads = c.leads.where((l) => l.createdAt.year == now.year);
    final yearWon = yearLeads.where((l) => LeadStatus.isWon(l.status)).length;
    final stageCounts = [
      for (final s in LeadStatus.flow)
        MapEntry(s, c.leads.where((l) => l.status == s).length),
    ];
    final maxStage = stageCounts.fold<int>(
      1,
      (a, e) => e.value > a ? e.value : a,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, ${c.repName.split(' ').first}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Commission rate ${(c.rate * 100).toStringAsFixed(c.rate * 100 % 1 == 0 ? 0 : 1)}%  •  Rep ID ${c.repId}',
          style: const TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 18),
        _StatGrid([
          _StatCard(
            'Total leads',
            '${c.leads.length}',
            Icons.people_alt_outlined,
            _accent,
            sub: '${c.openCount} open',
          ),
          _StatCard(
            'Jobs won',
            '${c.wonCount}',
            Icons.emoji_events_outlined,
            _cyan,
            sub: '${(c.conversion * 100).toStringAsFixed(0)}% conversion',
          ),
          _StatCard(
            'Completed',
            '${c.completedCount}',
            Icons.verified_outlined,
            _green,
          ),
          _StatCard(
            'Won contract value',
            money(c.wonValue, cents: false),
            Icons.handshake_outlined,
            _amber,
          ),
        ]),
        const _SectionTitle('Earnings'),
        _StatGrid([
          _StatCard(
            'Awaiting customer payment',
            money(c.awaiting),
            Icons.hourglass_top_rounded,
            Colors.white70,
          ),
          _StatCard(
            'Under review',
            money(c.review),
            Icons.fact_check_outlined,
            _amber,
          ),
          _StatCard(
            'Approved – ready to pay',
            money(c.ready2pay),
            Icons.account_balance_wallet_outlined,
            _cyan,
          ),
          _StatCard(
            'Paid to date',
            money(c.paid),
            Icons.savings_outlined,
            _green,
          ),
        ]),
        const _SectionTitle('Last 6 months'),
        _Card(
          child: Column(
            children: [
              SizedBox(
                height: 170,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < months.length; i++)
                      Expanded(
                        child: _MonthBars(
                          label: monthName(months[i]),
                          a: submitted[i],
                          b: won[i],
                          max: submitted.fold<int>(1, (x, y) => y > x ? y : x),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Legend(_accent, 'Leads submitted'),
                  SizedBox(width: 18),
                  _Legend(_green, 'Won'),
                ],
              ),
              const Divider(color: Colors.white12, height: 28),
              Text(
                '${now.year} so far:  ${yearLeads.length} leads  •  $yearWon won',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const _SectionTitle('Pipeline'),
        _Card(
          child: Column(
            children: [
              for (final e in stageCounts)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          LeadStatus.label(e.key),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: e.value / maxStage,
                            minHeight: 10,
                            backgroundColor: Colors.white10,
                            color: LeadStatus.color(e.key),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '${e.value}',
                          textAlign: TextAlign.right,
                          style: _white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        _SectionTitle(
          'Recent leads',
          trailing: TextButton(
            onPressed: () => c.section.value = 1,
            child: const Text('View all'),
          ),
        ),
        if (c.leads.isEmpty)
          const _Empty(
            Icons.rocket_launch_outlined,
            'No leads yet. Submit your first lead to start earning.',
          )
        else
          for (final l in c.leads.take(5)) _LeadTile(l),
      ],
    );
  });
}

class _MonthBars extends StatelessWidget {
  const _MonthBars({
    required this.label,
    required this.a,
    required this.b,
    required this.max,
  });
  final String label;
  final int a, b, max;
  @override
  Widget build(BuildContext context) {
    double h(int v) => max == 0 ? 0 : (v / max) * 110;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Bar(h(a), _accent, a),
            const SizedBox(width: 4),
            _Bar(h(b), _green, b),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.height, this.color, this.value);
  final double height;
  final Color color;
  final int value;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$value',
        style: const TextStyle(color: Colors.white54, fontSize: 10),
      ),
      Container(
        width: 14,
        height: height < 3 ? 3 : height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ],
  );
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.text);
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: Colors.white60, fontSize: 12)),
    ],
  );
}

// =========================================================
// 1 · LEADS
// =========================================================
class _LeadTile extends StatelessWidget {
  const _LeadTile(this.l);
  final Lead l;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => showLeadDetail(context, l),
      child: _Card(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.customerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${l.service}  •  ${l.budgetLabel}',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  Text(
                    'Submitted ${fmtDate(l.createdAt)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusChip(
                  LeadStatus.label(l.status),
                  LeadStatus.color(l.status),
                ),
                if (l.contractValue > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    money(l.contractValue, cents: false),
                    style: const TextStyle(
                      color: _cyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _LeadsView extends StatefulWidget {
  const _LeadsView(this.c);
  final PortalController c;
  @override
  State<_LeadsView> createState() => _LeadsViewState();
}

class _LeadsViewState extends State<_LeadsView> {
  String _q = '';
  String _f = 'all';

  static const _filters = {
    'all': 'All',
    'open': 'Open',
    'won': 'Won',
    'completed': 'Completed',
    'closed': 'Closed',
  };

  bool _match(Lead l) {
    final okF = switch (_f) {
      'open' => LeadStatus.isOpen(l.status),
      'won' => LeadStatus.isWon(l.status) && l.status != LeadStatus.completed,
      'completed' => l.status == LeadStatus.completed,
      'closed' => LeadStatus.isClosed(l.status),
      _ => true,
    };
    if (!okF) return false;
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return l.customerName.toLowerCase().contains(q) ||
        l.service.toLowerCase().contains(q) ||
        l.address.toLowerCase().contains(q) ||
        l.phone.contains(q);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        style: _white,
        cursorColor: Colors.white,
        onChanged: (v) => setState(() => _q = v.trim()),
        decoration: _dec('Search name, service, address, phone', Icons.search),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final e in _filters.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: _f == e.key,
                  onSelected: (_) => setState(() => _f = e.key),
                  selectedColor: _accent,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  labelStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: _f == e.key ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Obx(() {
        final list = widget.c.leads.where(_match).toList();
        if (list.isEmpty) {
          return const _Empty(Icons.search_off, 'No leads match.');
        }
        return Column(children: [for (final l in list) _LeadTile(l)]);
      }),
    ],
  );
}

/// Bottom sheet with full lead details, progress tracker and history.
void showLeadDetail(BuildContext context, Lead l) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: _bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.customerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatusChip(
                  LeadStatus.label(l.status),
                  LeadStatus.color(l.status),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _Tracker(l.status),
            if (l.status == LeadStatus.lost || l.status == LeadStatus.rejected)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _Card(
                  child: Text(
                    l.lostReason.isEmpty
                        ? 'This lead was closed.'
                        : 'Closed: ${l.lostReason}',
                    style: const TextStyle(color: Color(0xFFFFB4B4)),
                  ),
                ),
              ),
            const _SectionTitle('Customer'),
            _Card(
              child: Column(
                children: [
                  _Row('Phone', l.phone),
                  _Row('Email', l.email.isEmpty ? '—' : l.email),
                  _Row('Address', l.address),
                ],
              ),
            ),
            const _SectionTitle('Job'),
            _Card(
              child: Column(
                children: [
                  _Row('Service', l.service),
                  _Row('Budget', l.budgetLabel),
                  _Row('Submitted', fmtDate(l.createdAt)),
                  _Row(
                    'Assigned to',
                    l.assignedToName.isEmpty
                        ? 'Not yet assigned'
                        : l.assignedToName,
                  ),
                  if (l.description.isNotEmpty) ...[
                    const Divider(color: Colors.white12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.description,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (l.contractValue > 0) ...[
              const _SectionTitle('Contract'),
              _Card(
                child: Column(
                  children: [
                    _Row('Contract value', money(l.contractValue)),
                    _Row('Customer paid (verified)', money(l.amountPaid)),
                  ],
                ),
              ),
            ],
            if (l.photos.isNotEmpty) ...[
              const _SectionTitle('Photos'),
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final u in l.photos)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            u,
                            width: 140,
                            height: 110,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const _SectionTitle('Activity'),
            StreamBuilder<List<HistoryEntry>>(
              stream: SalesService.instance.history(l.id),
              builder: (_, snap) {
                final items = snap.data ?? const <HistoryEntry>[];
                if (items.isEmpty) {
                  return const Text(
                    'No activity yet.',
                    style: TextStyle(color: Colors.white54),
                  );
                }
                return Column(
                  children: [
                    for (final h in items)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.circle,
                          size: 10,
                          color: _accent,
                        ),
                        title: Text(h.message, style: _white),
                        subtitle: Text(
                          '${fmtDate(h.at)}  •  ${timeAgo(h.at)}',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v);
  final String k, v;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            k,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        Expanded(child: Text(v, style: _white)),
      ],
    ),
  );
}

class _Tracker extends StatelessWidget {
  const _Tracker(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final idx = LeadStatus.flow.indexOf(status);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < LeadStatus.flow.length; i++) ...[
            Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= idx ? _green : Colors.white12,
                  ),
                  child: Icon(
                    i <= idx ? Icons.check : Icons.circle,
                    size: i <= idx ? 16 : 6,
                    color: i <= idx ? _bg : Colors.white38,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 74,
                  child: Text(
                    LeadStatus.label(LeadStatus.flow[i]),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: i <= idx ? Colors.white : Colors.white38,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            if (i < LeadStatus.flow.length - 1)
              Container(
                width: 18,
                height: 2,
                margin: const EdgeInsets.only(bottom: 26),
                color: i < idx ? _green : Colors.white12,
              ),
          ],
        ],
      ),
    );
  }
}

// =========================================================
// 2 · SUBMIT A LEAD
// =========================================================
class _SubmitLeadView extends StatefulWidget {
  const _SubmitLeadView(this.c);
  final PortalController c;
  @override
  State<_SubmitLeadView> createState() => _SubmitLeadViewState();
}

class _SubmitLeadViewState extends State<_SubmitLeadView> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _desc = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  String _service = kServices.first;
  final _photos = <Uint8List>[];
  bool _consent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final t in [_name, _phone, _email, _address, _desc, _min, _max]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final files = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        imageQuality: 80,
      );
      for (final f in files) {
        if (_photos.length >= 6) break;
        _photos.add(await f.readAsBytes());
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('pick error: $e');
    }
  }

  bool _validPhone(String p) {
    if (!RegExp(r'^\+?[0-9\s\-\(\)]+$').hasMatch(p)) return false;
    final d = p.replaceAll(RegExp(r'[^0-9]'), '');
    return d.length >= 7 && d.length <= 15;
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final address = _address.text.trim();
    final min = double.tryParse(_min.text.replaceAll(',', '').trim());
    final max = double.tryParse(_max.text.replaceAll(',', '').trim());

    String? p;
    if (name.isEmpty || phone.isEmpty || address.isEmpty) {
      p = 'Customer name, phone and property address are required.';
    } else if (!_validPhone(phone)) {
      p = 'Enter a valid customer phone number.';
    } else if (email.isNotEmpty && !GetUtils.isEmail(email)) {
      p = 'Enter a valid customer email or leave it empty.';
    } else if (min == null || max == null || min <= 0 || max < min) {
      p = 'Enter the customer\'s budget range (min and max).';
    } else if (!_consent) {
      p = 'Confirm the customer agreed to be contacted.';
    }
    if (p != null) {
      setState(() => _error = p);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.c.svc.submitLead(
        repUid: widget.c.uid,
        repId: widget.c.repId,
        repName: widget.c.repName,
        customerName: name,
        phone: phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''),
        email: email,
        address: address,
        service: _service,
        description: _desc.text.trim(),
        budgetMin: min!,
        budgetMax: max!,
        photos: List.of(_photos),
      );
      if (!mounted) return;
      for (final t in [_name, _phone, _email, _address, _desc, _min, _max]) {
        t.clear();
      }
      setState(() {
        _photos.clear();
        _consent = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lead submitted. We will follow up with the customer.'),
        ),
      );
      widget.c.section.value = 1;
    } on DuplicateLeadException {
      setState(
        () => _error =
            'A lead for this customer / property and service already exists, so it can\'t be submitted again.',
      );
    } on FirebaseException catch (e) {
      setState(
        () => _error = e.code == 'permission-denied'
            ? 'You do not have permission to submit leads.'
            : 'Could not submit the lead (${e.code}). Please try again.',
      );
    } catch (e) {
      setState(() => _error = 'Could not submit the lead. Please try again.');
      debugPrint('submit lead error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _tf(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? type,
    int lines = 1,
    String? prefix,
    TextCapitalization cap = TextCapitalization.none,
  }) => TextField(
    controller: c,
    enabled: !_busy,
    style: _white,
    cursorColor: Colors.white,
    keyboardType: type,
    minLines: lines,
    maxLines: lines,
    textCapitalization: cap,
    decoration: _dec(label, icon, prefix: prefix),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, b) {
      final two = b.maxWidth >= 640;
      Widget pair(Widget x, Widget y) => two
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: x),
                const SizedBox(width: 12),
                Expanded(child: y),
              ],
            )
          : Column(children: [x, const SizedBox(height: 14), y]);

      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Submit a secured job',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Only submit customers who agreed to be contacted. Duplicates are blocked automatically.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 20),
            pair(
              _tf(
                _name,
                'Customer name',
                Icons.person_outline,
                cap: TextCapitalization.words,
              ),
              _tf(
                _phone,
                'Customer phone',
                Icons.call_outlined,
                type: TextInputType.phone,
              ),
            ),
            const SizedBox(height: 14),
            pair(
              _tf(
                _email,
                'Customer email (optional)',
                Icons.mail_outline,
                type: TextInputType.emailAddress,
              ),
              DropdownButtonFormField<String>(
                value: _service,
                dropdownColor: _bg2,
                style: _white,
                iconEnabledColor: Colors.white70,
                decoration: _dec('Service requested', Icons.handyman_outlined),
                items: [
                  for (final s in kServices)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _service = v ?? _service),
              ),
            ),
            const SizedBox(height: 14),
            _tf(
              _address,
              'Property address',
              Icons.home_outlined,
              cap: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            pair(
              _tf(
                _min,
                'Budget – minimum',
                Icons.attach_money,
                type: TextInputType.number,
              ),
              _tf(
                _max,
                'Budget – maximum',
                Icons.attach_money,
                type: TextInputType.number,
              ),
            ),
            const SizedBox(height: 14),
            _tf(
              _desc,
              'Job description / notes',
              Icons.notes_outlined,
              lines: 4,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _photos[i],
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: InkWell(
                          onTap: () => setState(() => _photos.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                if (_photos.length < 6)
                  InkWell(
                    onTap: _busy ? null : _pick,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                        color: Colors.white.withOpacity(0.05),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            color: Colors.white70,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Photos',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _consent,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _consent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: _accent,
              title: const Text(
                'The customer agreed to be contacted by Twins Handyman LLC about this job.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFFB4B4),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _GradientButton(
              label: 'SUBMIT LEAD',
              icon: Icons.send_rounded,
              loading: _busy,
              onTap: _submit,
            ),
          ],
        ),
      );
    },
  );
}

// =========================================================
// 3 · COMMISSIONS
// =========================================================
class _CommissionsView extends StatelessWidget {
  const _CommissionsView(this.c);
  final PortalController c;

  @override
  Widget build(BuildContext context) => Obx(() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatGrid([
          _StatCard(
            'Outstanding balance',
            money(c.totalEarned - c.paid),
            Icons.account_balance_outlined,
            _amber,
            sub: 'Total earned ${money(c.totalEarned)}',
          ),
          _StatCard(
            'Approved – ready to pay',
            money(c.ready2pay),
            Icons.account_balance_wallet_outlined,
            _cyan,
          ),
          _StatCard(
            'Paid to date',
            money(c.paid),
            Icons.savings_outlined,
            _green,
          ),
          _StatCard(
            'Awaiting customer payment',
            money(c.awaiting),
            Icons.hourglass_top_rounded,
            Colors.white70,
            sub: 'Under review ${money(c.review)}',
          ),
        ]),
        const SizedBox(height: 12),
        _Card(
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: _accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your rate is ${(c.rate * 100).toStringAsFixed(c.rate * 100 % 1 == 0 ? 0 : 1)}% of the approved contract value. '
                  'Commission is released only as the customer\'s payments are received and verified, then approved by an admin.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const _SectionTitle('Commission history'),
        if (c.commissions.isEmpty)
          const _Empty(
            Icons.payments_outlined,
            'No commissions yet. They appear when one of your leads becomes an approved contract.',
          )
        else
          for (final m in c.commissions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Card(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.customerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                ),
                              ),
                              Text(
                                m.service,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusChip(m.statusLabel, m.statusColor),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 22),
                    _Row('Contract value', money(m.contractValue)),
                    _Row(
                      'Rate',
                      '${(m.rate * 100).toStringAsFixed(m.rate * 100 % 1 == 0 ? 0 : 1)}%',
                    ),
                    _Row('Total commission', money(m.total)),
                    _Row('Released (customer paid)', money(m.releasable)),
                    _Row('Paid to you', money(m.paidAmount)),
                    if (m.paidAt != null)
                      _Row(
                        'Paid on',
                        '${fmtDate(m.paidAt!)}${m.paymentMethod.isEmpty ? '' : '  •  ${m.paymentMethod}'}',
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  });
}

// =========================================================
// 4 · RESOURCES & PROMOS
// =========================================================
class _ResourcesView extends StatelessWidget {
  const _ResourcesView(this.c);
  final PortalController c;

  static const _doorScript =
      'Hi, my name is [NAME] and I\'m with Twins Handyman LLC, a local home-repair company. '
      'We\'re helping neighbors in this area with small repairs and home projects. '
      'Is there anything around the house you\'ve been meaning to get fixed – painting, plumbing, drywall, flooring, anything like that?\n\n'
      'If yes: Great! May I take your name, best phone number and a rough budget? '
      'Someone from our team will call to give you a free estimate – there\'s no obligation.\n\n'
      'If no: No problem at all – thanks for your time, have a great day!';

  static const _phoneScript =
      'Hello, may I speak with [NAME]? This is [REP] from Twins Handyman LLC. '
      'I\'m calling neighbors in [AREA] about free estimates for home repairs and projects. '
      'Do you have a project in mind – even a small one – that you\'d like a quote on?\n\n'
      'Collect: name, phone, email, address, service, budget range.\n'
      'Close: "Thank you – our team will contact you within one business day."';

  static const _rules = [
    'Only submit customers who agreed to be contacted.',
    'Never quote prices, promise dates or sign anything for the company.',
    'Be polite, honest and professional – you represent Twins Handyman LLC.',
    'Respect "No Soliciting" signs, local permit rules and call-time limits.',
    'Work in pairs or notify a parent / guardian of where you are if you are under 18.',
    'Commission is paid only after the customer has paid and an admin approves it.',
  ];

  Widget _script(String title, String body) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              onPressed: () => Clipboard.setData(ClipboardData(text: body)),
              icon: const Icon(
                Icons.copy_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ],
        ),
        Text(
          body,
          style: const TextStyle(
            color: Colors.white70,
            height: 1.45,
            fontSize: 13.5,
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Obx(
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Promotions & announcements'),
        if (c.promos.isEmpty)
          const _Empty(
            Icons.campaign_outlined,
            'No active promotions right now.',
          )
        else
          for (final p in c.promos)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _Card(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.local_offer_outlined, color: _amber),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p['title'] ?? ''}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p['body'] ?? ''}',
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const _SectionTitle('Scripts'),
        _script('Door-to-door script', _doorScript),
        const SizedBox(height: 10),
        _script('Phone script', _phoneScript),
        const _SectionTitle('Program rules'),
        _Card(
          child: Column(
            children: [
              for (final r in _rules)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: _green,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

// =========================================================
// 5 · PROFILE
// =========================================================
class _ProfileView extends StatelessWidget {
  const _ProfileView(this.c);
  final PortalController c;

  @override
  Widget build(BuildContext context) => Obx(() {
    final r = c.rep.value ?? {};
    final prefs = (r['prefs'] is Map) ? r['prefs'] as Map : {};
    final emailOn = prefs['email'] != false;
    final pushOn = prefs['push'] != false;
    final since = r['createdAt'] is Timestamp
        ? (r['createdAt'] as Timestamp).toDate()
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: Column(
            children: [
              _Row('Name', c.repName),
              _Row('Representative ID', c.repId),
              _Row('Email', '${r['email'] ?? ''}'),
              _Row('Phone', '${r['phone'] ?? ''}'),
              _Row(
                'Commission rate',
                '${(c.rate * 100).toStringAsFixed(c.rate * 100 % 1 == 0 ? 0 : 1)}%',
              ),
              _Row('Status', 'Approved'),
              if (since != null) _Row('Member since', fmtDate(since)),
              _Row('Agreement version', '${r['agreementVersion'] ?? '—'}'),
            ],
          ),
        ),
        const _SectionTitle('Notifications'),
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            children: [
              SwitchListTile(
                value: pushOn,
                activeColor: _accent,
                title: const Text('Push notifications', style: _white),
                subtitle: const Text(
                  'Lead updates, payments and promotions',
                  style: TextStyle(color: Colors.white54, fontSize: 12.5),
                ),
                onChanged: (v) => c.svc.setPrefs(c.uid, push: v),
              ),
              SwitchListTile(
                value: emailOn,
                activeColor: _accent,
                title: const Text('Email notifications', style: _white),
                subtitle: const Text(
                  'Lead updates, commission statements and promos',
                  style: TextStyle(color: Colors.white54, fontSize: 12.5),
                ),
                onChanged: (v) => c.svc.setPrefs(c.uid, email: v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white30),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          ),
        ),
      ],
    );
  });
}

// =========================================================
// NOTIFICATIONS SHEET
// =========================================================
void _showNotifications(BuildContext context, PortalController c) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: _bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Obx(
          () => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(18),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (c.unread > 0)
                    TextButton(
                      onPressed: () => c.svc.markAllRead(c.notifs),
                      child: const Text('Mark all read'),
                    ),
                ],
              ),
              if (c.notifs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: _Empty(
                    Icons.notifications_none,
                    'You are all caught up.',
                  ),
                ),
              for (final n in c.notifs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: (n.read
                        ? Colors.white12
                        : _accent.withOpacity(0.25)),
                    child: Icon(
                      switch (n.type) {
                        'commission' => Icons.payments_outlined,
                        'promo' => Icons.local_offer_outlined,
                        'lead' => Icons.assignment_outlined,
                        _ => Icons.notifications_none,
                      },
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: n.read ? FontWeight.w500 : FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    '${n.body}\n${timeAgo(n.createdAt)}',
                    style: const TextStyle(color: Colors.white54, height: 1.3),
                  ),
                  isThreeLine: true,
                  onTap: () {
                    if (!n.read) c.svc.markRead(n.id);
                    final idx = c.leads.indexWhere((l) => l.id == n.leadId);
                    if (idx >= 0) {
                      Navigator.of(ctx).pop();
                      showLeadDetail(context, c.leads[idx]);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
