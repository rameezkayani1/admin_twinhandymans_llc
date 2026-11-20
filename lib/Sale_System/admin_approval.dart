// Save as: lib/Admin/pages/reps/rep_management_page.dart
//
// Admin Dashboard → Rep management
//  • approve / reject (with reason) / suspend / reinstate
//  • edit commission rate
//  • view agreement acceptance
//  • performance per rep
//
// Responsive: phone = list → detail page, tablet = list → detail page,
// desktop/web (>= 1000px) = list + detail side by side.
//
// Usage:  RepManagementPage()                 (standalone screen)
//         RepManagementPage(embedded: true)   (inside your dashboard shell)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ── Config (change to match your data) ──────────────────────────────────────
const kDefaultCommissionRate = 10.0; // % used when a rep has no custom rate
const kCurrentAgreementVersion = '1.0'; // same as _agreementVersion in sign-up

// Performance is read from documents that carry the rep's uid.
const kLeadsCollection = 'quote_requests';
const kPaymentsCollection = 'payments';
const kRepLinkField = 'repUid'; // field on those docs holding the rep's uid
const kPaymentAmountField = 'amount'; // numeric field on payment docs
const _wonStatuses = {'accepted', 'scheduled', 'in_progress', 'completed'};

// ── Design tokens (same family as the auth screens) ─────────────────────────
const _bg = Color(0xFF070F24);
const _bgMid = Color(0xFF0E1F46);
const _bgEnd = Color(0xFF1B1646);
const _accent = Color(0xFF4F8CFF);
const _accent2 = Color(0xFF7C5CFF);
const _green = Color(0xFF34D399);
const _amber = Color(0xFFFFC857);
const _red = Color(0xFFFF6B6B);
const _orange = Color(0xFFFFA24D);

// =========================================================
// HELPERS
// =========================================================
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

String _two(int n) => n.toString().padLeft(2, '0');
String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
String _fmtDateTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '${_fmtDate(d)} · $h:${_two(d.minute)} $ap';
}

String _money(double v) {
  final parts = v.toStringAsFixed(2).split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return '\$$whole.${parts[1]}';
}

String _numStr(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

String _makeRepId(String uid) =>
    'REP-${uid.substring(0, uid.length < 6 ? uid.length : 6).toUpperCase()}';

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
  if (p.isEmpty) return '?';
  if (p.length == 1) return p.first[0].toUpperCase();
  return (p.first[0] + p.last[0]).toUpperCase();
}

int _ageOf(DateTime dob) {
  final now = DateTime.now();
  var a = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
    a--;
  }
  return a;
}

DateTime? _dt(dynamic v) => v is Timestamp ? v.toDate() : null;

Color _statusColor(String s) {
  switch (s) {
    case 'approved':
      return _green;
    case 'rejected':
      return _red;
    case 'suspended':
      return _orange;
    default:
      return _amber;
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    case 'suspended':
      return 'Suspended';
    default:
      return 'Pending';
  }
}

IconData _statusIcon(String s) {
  switch (s) {
    case 'approved':
      return Icons.check_circle_outline;
    case 'rejected':
      return Icons.cancel_outlined;
    case 'suspended':
      return Icons.block;
    default:
      return Icons.hourglass_top_rounded;
  }
}

String? _rateValidator(String v) {
  final n = double.tryParse(v.trim());
  if (n == null) return 'Enter a number';
  if (n < 0 || n > 100) return 'Must be between 0 and 100';
  return null;
}

// =========================================================
// MODEL  (Firestore: reps/{uid})
// =========================================================
class _Hist {
  final String action;
  final String? by;
  final DateTime? at;
  final String? note;
  const _Hist({required this.action, this.by, this.at, this.note});
}

class _Rep {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String status;
  final String? repId;
  final double? commissionRate;
  final String? rejectionReason;
  final String? suspensionReason;
  final bool isMinor;
  final DateTime? dob;
  final String? guardianName;
  final String? guardianPhone;
  final String? agreementVersion;
  final DateTime? agreementAcceptedAt;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final List<_Hist> history;

  const _Rep({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.status,
    this.repId,
    this.commissionRate,
    this.rejectionReason,
    this.suspensionReason,
    this.isMinor = false,
    this.dob,
    this.guardianName,
    this.guardianPhone,
    this.agreementVersion,
    this.agreementAcceptedAt,
    this.createdAt,
    this.approvedAt,
    this.history = const [],
  });

  factory _Rep.from(DocumentSnapshot<Map<String, dynamic>> s) {
    final d = s.data() ?? {};
    final g = d['guardian'];
    final hist = <_Hist>[];
    final raw = d['history'];
    if (raw is List) {
      for (final h in raw) {
        if (h is Map) {
          hist.add(
            _Hist(
              action: '${h['action'] ?? ''}',
              by: (h['byName'] ?? h['by'])?.toString(),
              at: _dt(h['at']),
              note: h['note']?.toString(),
            ),
          );
        }
      }
    }
    hist.sort(
      (a, b) => (b.at ?? DateTime(2000)).compareTo(a.at ?? DateTime(2000)),
    );
    return _Rep(
      uid: s.id,
      name: (d['name'] as String?)?.trim() ?? '',
      email: (d['email'] as String?) ?? '',
      phone: (d['phone'] as String?) ?? '',
      status: ((d['status'] as String?) ?? 'pending').toLowerCase().trim(),
      repId: d['repId'] as String?,
      commissionRate: (d['commissionRate'] as num?)?.toDouble(),
      rejectionReason: d['rejectionReason'] as String?,
      suspensionReason: d['suspensionReason'] as String?,
      isMinor: d['isMinor'] == true,
      dob: _dt(d['dob']),
      guardianName: g is Map ? g['name']?.toString() : null,
      guardianPhone: g is Map ? g['phone']?.toString() : null,
      agreementVersion: d['agreementVersion']?.toString(),
      agreementAcceptedAt: _dt(d['agreementAcceptedAt']),
      createdAt: _dt(d['createdAt']),
      approvedAt: _dt(d['approvedAt']),
      history: hist,
    );
  }

  double get rate => commissionRate ?? kDefaultCommissionRate;
}

// =========================================================
// PAGE
// =========================================================
class RepManagementPage extends StatefulWidget {
  const RepManagementPage({super.key, this.embedded = false});

  /// true  → returns just the content (put it inside your dashboard shell)
  /// false → full screen with its own background
  final bool embedded;

  @override
  State<RepManagementPage> createState() => _RepManagementPageState();
}

class _RepManagementPageState extends State<RepManagementPage> {
  final _search = TextEditingController();
  String _filter = 'all'; // all | pending | approved | suspended | rejected
  String? _selected;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance.collection('reps').snapshots();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _AdminGate(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Message(
              icon: Icons.error_outline,
              color: _red,
              title: 'Could not load representatives',
              text: '${snap.error}',
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!.docs.map(_Rep.from).toList()
            ..sort(
              (a, b) => (b.createdAt ?? DateTime(2000)).compareTo(
                a.createdAt ?? DateTime(2000),
              ),
            );
          return LayoutBuilder(
            builder: (context, box) => _content(all, box.maxWidth),
          );
        },
      ),
    );

    if (widget.embedded) {
      return Material(color: Colors.transparent, child: content);
    }
    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg, _bgMid, _bgEnd],
          ),
        ),
        child: SafeArea(child: content),
      ),
    );
  }

  Widget _content(List<_Rep> all, double w) {
    final wide = w >= 1000;
    final pad = w < 600 ? 14.0 : 24.0;

    final q = _search.text.trim().toLowerCase();
    final filtered = all.where((r) {
      if (_filter != 'all' && r.status != _filter) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) ||
          r.email.toLowerCase().contains(q) ||
          r.phone.toLowerCase().contains(q) ||
          (r.repId ?? '').toLowerCase().contains(q);
    }).toList();

    final header = _header(all, w - pad * 2);
    final tiles = _tiles(filtered, wide);

    if (!wide) {
      return ListView(
        padding: EdgeInsets.all(pad),
        children: [header, const SizedBox(height: 16), ...tiles],
      );
    }

    final selected = all.where((r) => r.uid == _selected).isNotEmpty
        ? _selected
        : null;
    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        children: [
          header,
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 420,
                  child: ListView(
                    padding: const EdgeInsets.only(right: 8),
                    children: tiles,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: selected == null
                        ? const _Message(
                            icon: Icons.touch_app_outlined,
                            color: Colors.white54,
                            title: 'Select a representative',
                            text:
                                'Pick someone from the list to review their application, agreement and performance.',
                          )
                        : _RepDetail(key: ValueKey(selected), uid: selected),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header: title, stats, search, filters ─────────────────────────────────
  Widget _header(List<_Rep> all, double w) {
    int count(String s) => all.where((r) => r.status == s).length;
    final cols = w >= 760 ? 4 : 2;
    const gap = 12.0;
    final cardW = (w - gap * (cols - 1)) / cols;

    Widget stat(String label, int v, Color c, IconData i) => SizedBox(
      width: cardW,
      child: _StatCard(label: label, value: '$v', color: c, icon: i),
    );

    final filters = <List<dynamic>>[
      ['all', 'All', all.length],
      ['pending', 'Pending', count('pending')],
      ['approved', 'Approved', count('approved')],
      ['suspended', 'Suspended', count('suspended')],
      ['rejected', 'Rejected', count('rejected')],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sales representatives',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Review applications, set commission and track performance.',
          style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 14),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            stat('Total reps', all.length, _accent, Icons.groups_2_outlined),
            stat(
              'Pending review',
              count('pending'),
              _amber,
              Icons.hourglass_top_rounded,
            ),
            stat(
              'Approved',
              count('approved'),
              _green,
              Icons.verified_outlined,
            ),
            stat('Suspended', count('suspended'), _orange, Icons.block),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: _fieldDeco(
            'Search name, email, phone or Rep ID',
            icon: Icons.search,
            suffix: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => setState(_search.clear),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in filters) ...[
                _FilterChipBtn(
                  label: '${f[1]} (${f[2]})',
                  selected: _filter == f[0],
                  onTap: () => setState(() => _filter = f[0] as String),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _tiles(List<_Rep> list, bool wide) {
    if (list.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: _Message(
            icon: Icons.search_off,
            color: Colors.white54,
            title: 'No representatives found',
            text: 'Try a different search or filter.',
          ),
        ),
      ];
    }
    return [
      for (final r in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RepTile(
            rep: r,
            selected: wide && r.uid == _selected,
            onTap: () {
              if (wide) {
                setState(() => _selected = r.uid);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: _bg,
                      appBar: AppBar(
                        backgroundColor: _bgMid,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        title: Text(r.name.isEmpty ? 'Representative' : r.name),
                      ),
                      body: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_bg, _bgMid, _bgEnd],
                          ),
                        ),
                        child: SafeArea(child: _RepDetail(uid: r.uid)),
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ),
    ];
  }
}

// =========================================================
// ADMIN GATE – only owner/admin may use this page (rules enforce it too)
// =========================================================
class _AdminGate extends StatelessWidget {
  const _AdminGate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      return const _Message(
        icon: Icons.lock_outline,
        color: _amber,
        title: 'Please sign in',
        text: 'You need to be signed in as an admin to manage representatives.',
      );
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(u.uid).get(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final role = ((snap.data?.data()?['role'] as String?) ?? 'customer')
            .toLowerCase();
        if (role == 'owner' || role == 'admin') return child;
        return const _Message(
          icon: Icons.lock_outline,
          color: _red,
          title: 'No access',
          text: 'Only the owner or an admin can manage sales representatives.',
        );
      },
    );
  }
}

// =========================================================
// LIST TILE
// =========================================================
class _RepTile extends StatelessWidget {
  const _RepTile({
    required this.rep,
    required this.selected,
    required this.onTap,
  });
  final _Rep rep;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = rep;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? _accent.withOpacity(0.16)
                : Colors.white.withOpacity(0.06),
            border: Border.all(
              color: selected
                  ? _accent.withOpacity(0.7)
                  : Colors.white.withOpacity(0.10),
            ),
          ),
          child: Row(
            children: [
              _Avatar(name: r.name, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name.isEmpty ? '(no name)' : r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (r.repId != null) r.repId!,
                        if (r.status == 'approved' || r.status == 'suspended')
                          '${_numStr(r.rate)}% commission',
                        if (r.status == 'pending' && r.createdAt != null)
                          'Applied ${_fmtDate(r.createdAt!)}',
                      ].join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Badge(status: r.status),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// DETAIL (used in side pane on desktop, full page on phone/tablet)
// =========================================================
class _RepDetail extends StatefulWidget {
  const _RepDetail({super.key, required this.uid});
  final String uid;

  @override
  State<_RepDetail> createState() => _RepDetailState();
}

class _RepDetailState extends State<_RepDetail> {
  final _db = FirebaseFirestore.instance;
  bool _busy = false;

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream = _db
      .collection('reps')
      .doc(widget.uid)
      .snapshots();

  User? get _admin => FirebaseAuth.instance.currentUser;

  // ── Firestore writes ──────────────────────────────────────────────────────
  Future<void> _update(
    Map<String, dynamic> data,
    String action, {
    String? note,
  }) {
    final a = _admin;
    return _db.collection('reps').doc(widget.uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([
        {
          'action': action,
          'by': a?.uid,
          'byName': a?.displayName ?? a?.email,
          'at': Timestamp.now(),
          if (note != null && note.isNotEmpty) 'note': note,
        },
      ]),
    });
  }

  Future<void> _run(Future<void> Function() job, String okMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
      _toast(okMessage);
    } on FirebaseException catch (e) {
      _toast(
        e.code == 'permission-denied'
            ? 'Permission denied. Only the owner or an admin can do this.'
            : 'Failed: ${e.message ?? e.code}',
        error: true,
      );
    } catch (e) {
      _toast('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error
            ? const Color(0xFFB3261E)
            : const Color(0xFF1F7A5A),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<void> _approve(_Rep r) async {
    final v = await showDialog<String>(
      context: context,
      builder: (_) => _InputDialog(
        title: r.status == 'pending'
            ? 'Approve application'
            : 'Approve representative',
        message:
            '${r.name} will be able to sign in as a sales rep. Set their commission rate.',
        label: 'Commission rate',
        initial: _numStr(r.rate),
        suffix: '%',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: _rateValidator,
        confirmLabel: 'Approve',
        confirmColor: _green,
      ),
    );
    if (v == null) return;
    final rate = double.parse(v.trim());
    await _run(
      () => _update(
        {
          'status': 'approved',
          'repId': r.repId ?? _makeRepId(r.uid),
          'commissionRate': rate,
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': _admin?.uid,
          'rejectionReason': FieldValue.delete(),
          'suspensionReason': FieldValue.delete(),
        },
        'approved',
        note: 'Commission ${_numStr(rate)}%',
      ),
      '${r.name} approved',
    );
  }

  Future<void> _reject(_Rep r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _InputDialog(
        title: 'Reject application',
        message: 'The applicant will see this reason when they try to sign in.',
        label: 'Reason',
        maxLines: 3,
        validator: (v) => v.trim().length < 3 ? 'Please give a reason' : null,
        confirmLabel: 'Reject',
        confirmColor: _red,
      ),
    );
    if (reason == null) return;
    await _run(
      () => _update(
        {
          'status': 'rejected',
          'rejectionReason': reason.trim(),
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': _admin?.uid,
        },
        'rejected',
        note: reason.trim(),
      ),
      'Application rejected',
    );
  }

  Future<void> _suspend(_Rep r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _InputDialog(
        title: 'Suspend representative',
        message:
            '${r.name} will not be able to sign in until reinstated. Add an internal note (optional).',
        label: 'Reason (optional)',
        required: false,
        maxLines: 3,
        confirmLabel: 'Suspend',
        confirmColor: _orange,
      ),
    );
    if (reason == null) return;
    await _run(
      () => _update(
        {
          'status': 'suspended',
          'suspensionReason': reason.trim(),
          'suspendedAt': FieldValue.serverTimestamp(),
          'suspendedBy': _admin?.uid,
        },
        'suspended',
        note: reason.trim(),
      ),
      '${r.name} suspended',
    );
  }

  Future<void> _reinstate(_Rep r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Reinstate representative',
        message: '${r.name} will be able to sign in again.',
        confirmLabel: 'Reinstate',
        confirmColor: _green,
      ),
    );
    if (ok != true) return;
    await _run(
      () => _update({
        'status': 'approved',
        'suspensionReason': FieldValue.delete(),
      }, 'reinstated'),
      '${r.name} reinstated',
    );
  }

  Future<void> _editCommission(_Rep r) async {
    final v = await showDialog<String>(
      context: context,
      builder: (_) => _InputDialog(
        title: 'Edit commission rate',
        message:
            'Percentage of payments the customer has made that ${r.name} earns.',
        label: 'Commission rate',
        initial: _numStr(r.rate),
        suffix: '%',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: _rateValidator,
        confirmLabel: 'Save',
        confirmColor: _accent,
      ),
    );
    if (v == null) return;
    final rate = double.parse(v.trim());
    await _run(
      () => _update(
        {'commissionRate': rate},
        'commission_updated',
        note: '${_numStr(r.rate)}% → ${_numStr(rate)}%',
      ),
      'Commission set to ${_numStr(rate)}%',
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Message(
            icon: Icons.error_outline,
            color: _red,
            title: 'Could not load this representative',
            text: '${snap.error}',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.data!.exists) {
          return const _Message(
            icon: Icons.person_off_outlined,
            color: Colors.white54,
            title: 'Representative not found',
            text: 'This application may have been removed.',
          );
        }
        final r = _Rep.from(snap.data!);
        final pad = MediaQuery.of(context).size.width < 600 ? 14.0 : 22.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _profileHeader(r),
                  const SizedBox(height: 16),
                  _notice(r),
                  _actions(r),
                  const SizedBox(height: 16),
                  _contactCard(r),
                  const SizedBox(height: 14),
                  _commissionCard(r),
                  const SizedBox(height: 14),
                  _agreementCard(r),
                  const SizedBox(height: 14),
                  _PerformanceCard(key: ValueKey('perf-${r.uid}'), rep: r),
                  const SizedBox(height: 14),
                  _historyCard(r),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _profileHeader(_Rep r) => Row(
    children: [
      _Avatar(name: r.name, size: 62),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.name.isEmpty ? '(no name)' : r.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              r.email,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Badge(status: r.status),
                if (r.repId != null)
                  Text(
                    r.repId!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _notice(_Rep r) {
    String? text;
    Color color = _amber;
    IconData icon = _statusIcon(r.status);
    switch (r.status) {
      case 'pending':
        text =
            'Awaiting review. Approving assigns a Rep ID and lets them sign in.';
        break;
      case 'rejected':
        color = _red;
        text = (r.rejectionReason ?? '').trim().isEmpty
            ? 'Application rejected.'
            : 'Rejected: ${r.rejectionReason!.trim()}';
        break;
      case 'suspended':
        color = _orange;
        text = (r.suspensionReason ?? '').trim().isEmpty
            ? 'This account is suspended.'
            : 'Suspended: ${r.suspensionReason!.trim()}';
        break;
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(_Rep r) {
    final btns = <Widget>[];
    switch (r.status) {
      case 'pending':
        btns.addAll([
          _ActionBtn(
            label: 'Approve',
            icon: Icons.check_rounded,
            color: _green,
            filled: true,
            onTap: _busy ? null : () => _approve(r),
          ),
          _ActionBtn(
            label: 'Reject',
            icon: Icons.close_rounded,
            color: _red,
            onTap: _busy ? null : () => _reject(r),
          ),
        ]);
        break;
      case 'approved':
        btns.addAll([
          _ActionBtn(
            label: 'Edit commission',
            icon: Icons.percent_rounded,
            color: _accent,
            filled: true,
            onTap: _busy ? null : () => _editCommission(r),
          ),
          _ActionBtn(
            label: 'Suspend',
            icon: Icons.block,
            color: _orange,
            onTap: _busy ? null : () => _suspend(r),
          ),
        ]);
        break;
      case 'suspended':
        btns.addAll([
          _ActionBtn(
            label: 'Reinstate',
            icon: Icons.restore_rounded,
            color: _green,
            filled: true,
            onTap: _busy ? null : () => _reinstate(r),
          ),
          _ActionBtn(
            label: 'Edit commission',
            icon: Icons.percent_rounded,
            color: _accent,
            onTap: _busy ? null : () => _editCommission(r),
          ),
        ]);
        break;
      case 'rejected':
        btns.add(
          _ActionBtn(
            label: 'Approve instead',
            icon: Icons.check_rounded,
            color: _green,
            filled: true,
            onTap: _busy ? null : () => _approve(r),
          ),
        );
        break;
    }
    return Row(
      children: [
        Expanded(child: Wrap(spacing: 10, runSpacing: 10, children: btns)),
        if (_busy)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
      ],
    );
  }

  Widget _contactCard(_Rep r) => _Card(
    title: 'Applicant',
    icon: Icons.person_outline,
    child: Column(
      children: [
        _kv('Phone', r.phone.isEmpty ? '—' : r.phone),
        _kv('Email', r.email.isEmpty ? '—' : r.email),
        _kv(
          'Date of birth',
          r.dob == null ? '—' : '${_fmtDate(r.dob!)}  (age ${_ageOf(r.dob!)})',
        ),
        if (r.isMinor) ...[
          _kv('Under 18', 'Yes', valueColor: _amber),
          _kv('Guardian', r.guardianName ?? '—'),
          _kv('Guardian phone', r.guardianPhone ?? '—'),
        ],
        _kv('Applied', r.createdAt == null ? '—' : _fmtDateTime(r.createdAt!)),
        if (r.approvedAt != null) _kv('Approved', _fmtDateTime(r.approvedAt!)),
      ],
    ),
  );

  Widget _commissionCard(_Rep r) {
    final custom = r.commissionRate != null;
    final canEdit = r.status == 'approved' || r.status == 'suspended';
    return _Card(
      title: 'Commission',
      icon: Icons.percent_rounded,
      trailing: canEdit
          ? TextButton.icon(
              onPressed: _busy ? null : () => _editCommission(r),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${_numStr(r.rate)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                custom
                    ? 'Custom rate · paid on payments the customer has made'
                    : 'Default rate (not set yet) · paid on payments the customer has made',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _agreementCard(_Rep r) {
    final accepted = r.agreementAcceptedAt != null;
    final outdated =
        r.agreementVersion != null &&
        r.agreementVersion != kCurrentAgreementVersion;
    return _Card(
      title: 'Representative agreement',
      icon: Icons.description_outlined,
      trailing: Icon(
        accepted ? Icons.verified_rounded : Icons.warning_amber_rounded,
        color: accepted ? _green : _amber,
        size: 20,
      ),
      child: Column(
        children: [
          _kv(
            'Status',
            accepted ? 'Accepted' : 'Not recorded',
            valueColor: accepted ? _green : _amber,
          ),
          _kv(
            'Version',
            r.agreementVersion == null
                ? '—'
                : 'v${r.agreementVersion}'
                      '${outdated ? '  (current is v$kCurrentAgreementVersion)' : ''}',
            valueColor: outdated ? _amber : null,
          ),
          _kv(
            'Accepted on',
            accepted ? _fmtDateTime(r.agreementAcceptedAt!) : '—',
          ),
          if (r.isMinor)
            _kv(
              'Guardian on file',
              (r.guardianName ?? '').isEmpty ? 'No' : 'Yes',
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rep confirmed they understand commission is paid on payments the customer has made.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyCard(_Rep r) {
    String label(String a) {
      switch (a) {
        case 'approved':
          return 'Approved';
        case 'rejected':
          return 'Rejected';
        case 'suspended':
          return 'Suspended';
        case 'reinstated':
          return 'Reinstated';
        case 'commission_updated':
          return 'Commission updated';
        default:
          return a;
      }
    }

    final items = r.history.take(10).toList();
    return _Card(
      title: 'Activity',
      icon: Icons.history_rounded,
      child: items.isEmpty
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No admin actions yet.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            )
          : Column(
              children: [
                for (final h in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6, right: 10),
                          decoration: const BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label(h.action),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                              Text(
                                [
                                  if (h.by != null) 'by ${h.by}',
                                  if (h.at != null) _fmtDateTime(h.at!),
                                ].join(' · '),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11.5,
                                ),
                              ),
                              if ((h.note ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    h.note!,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 12.5,
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
}

// =========================================================
// PERFORMANCE (per rep)
// =========================================================
class _Perf {
  final int leads;
  final int won;
  final double revenue;
  const _Perf(this.leads, this.won, this.revenue);
  double get conversion => leads == 0 ? 0 : won / leads * 100;
}

class _PerformanceCard extends StatefulWidget {
  const _PerformanceCard({super.key, required this.rep});
  final _Rep rep;

  @override
  State<_PerformanceCard> createState() => _PerformanceCardState();
}

class _PerformanceCardState extends State<_PerformanceCard> {
  late Future<_Perf> _future = _load();

  Future<_Perf> _load() async {
    final db = FirebaseFirestore.instance;
    final uid = widget.rep.uid;

    final leadSnap = await db
        .collection(kLeadsCollection)
        .where(kRepLinkField, isEqualTo: uid)
        .get();
    var won = 0;
    for (final d in leadSnap.docs) {
      final s = ((d.data()['status'] as String?) ?? '').toLowerCase();
      if (_wonStatuses.contains(s)) won++;
    }

    final paySnap = await db
        .collection(kPaymentsCollection)
        .where(kRepLinkField, isEqualTo: uid)
        .get();
    var revenue = 0.0;
    for (final d in paySnap.docs) {
      revenue += (d.data()[kPaymentAmountField] as num?)?.toDouble() ?? 0;
    }
    return _Perf(leadSnap.docs.length, won, revenue);
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Performance',
      icon: Icons.trending_up_rounded,
      trailing: IconButton(
        tooltip: 'Refresh',
        visualDensity: VisualDensity.compact,
        icon: const Icon(
          Icons.refresh_rounded,
          color: Colors.white70,
          size: 20,
        ),
        onPressed: () => setState(() => _future = _load()),
      ),
      child: FutureBuilder<_Perf>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            );
          }
          if (snap.hasError) {
            return Text(
              'Could not load performance. Check that '
              '"$kLeadsCollection" and "$kPaymentsCollection" documents store the '
              'rep uid in "$kRepLinkField".\n${snap.error}',
              style: const TextStyle(color: Color(0xFFFFB4B4), fontSize: 12.5),
            );
          }
          final p = snap.data!;
          final earned = p.revenue * widget.rep.rate / 100;
          return LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth >= 520 ? 4 : 2;
              const gap = 10.0;
              final w = (box.maxWidth - gap * (cols - 1)) / cols;
              Widget tile(String l, String v, Color c) => SizedBox(
                width: w,
                child: _MiniStat(label: l, value: v, color: c),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      tile('Leads', '${p.leads}', _accent),
                      tile('Won', '${p.won}', _green),
                      tile(
                        'Conversion',
                        '${p.conversion.toStringAsFixed(0)}%',
                        _accent2,
                      ),
                      tile('Collected', _money(p.revenue), _amber),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [
                          _accent.withOpacity(0.22),
                          _accent2.withOpacity(0.22),
                        ],
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Commission earned',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                _money(earned),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_numStr(widget.rep.rate)}%',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// =========================================================
// DIALOGS
// =========================================================
class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.message,
    required this.label,
    required this.confirmLabel,
    required this.confirmColor,
    this.initial = '',
    this.suffix,
    this.keyboardType,
    this.required = true,
    this.maxLines = 1,
    this.validator,
  });

  final String title;
  final String message;
  final String label;
  final String confirmLabel;
  final Color confirmColor;
  final String initial;
  final String? suffix;
  final TextInputType? keyboardType;
  final bool required;
  final int maxLines;
  final String? Function(String)? validator;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _c.text.trim();
    String? err;
    if (widget.required && t.isEmpty) {
      err = 'Required';
    } else if (widget.validator != null) {
      err = widget.validator!(t);
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _bgMid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.white.withOpacity(0.15)),
      ),
      title: Text(
        widget.title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.message,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _c,
                autofocus: true,
                maxLines: widget.maxLines,
                keyboardType: widget.keyboardType,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
                decoration: _fieldDeco(
                  widget.label,
                  suffixText: widget.suffix,
                  error: _error,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: widget.confirmColor,
            foregroundColor: Colors.black87,
          ),
          onPressed: _submit,
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _bgMid,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: Colors.white.withOpacity(0.15)),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 20,
      ),
    ),
    content: Text(
      message,
      style: TextStyle(color: Colors.white.withOpacity(0.75), height: 1.4),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: confirmColor,
          foregroundColor: Colors.black87,
        ),
        onPressed: () => Navigator.of(context).pop(true),
        child: Text(
          confirmLabel,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

// =========================================================
// SMALL UI PIECES
// =========================================================
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.10)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: _accent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

Widget _kv(String k, String v, {Color? valueColor}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 118,
        child: Text(
          k,
          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13),
        ),
      ),
      Expanded(
        child: Text(
          v,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  ),
);

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_accent, _accent2],
      ),
    ),
    child: Text(
      _initials(name),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: size * 0.36,
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(status), color: c, size: 13),
          const SizedBox(width: 5),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: c,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(0.10)),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
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
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _FilterChipBtn extends StatelessWidget {
  const _FilterChipBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(30),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: selected
            ? _accent.withOpacity(0.25)
            : Colors.white.withOpacity(0.06),
        border: Border.all(
          color: selected ? _accent : Colors.white.withOpacity(0.14),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: filled ? color : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: filled ? color : color.withOpacity(0.6),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: filled ? Colors.black87 : color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: filled ? Colors.black87 : color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

InputDecoration _fieldDeco(
  String label, {
  IconData? icon,
  Widget? suffix,
  String? suffixText,
  String? error,
}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
    floatingLabelStyle: const TextStyle(color: Colors.white),
    prefixIcon: icon == null ? null : Icon(icon, color: Colors.white70),
    suffixIcon: suffix,
    suffixText: suffixText,
    suffixStyle: const TextStyle(color: Colors.white70),
    errorText: error,
    filled: true,
    fillColor: Colors.white.withOpacity(0.08),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    enabledBorder: border(Colors.white.withOpacity(0.18)),
    border: border(Colors.white.withOpacity(0.18)),
    focusedBorder: border(_accent, 1.6),
    errorBorder: border(_red),
    focusedErrorBorder: border(_red, 1.6),
  );
}
