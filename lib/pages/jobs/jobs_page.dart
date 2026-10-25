// =============================================================
// jobs_page.dart — Admin: Jobs (single file, live Firestore data)
//
// A job = a quote_requests/{id} doc that has been scheduled
// (status 'scheduled', or 'completed' after being scheduled).
//
// Reads
//   quote_requests  where status in ['scheduled','completed']
//   users           staff = every user whose role != 'customer'
//                   (change _isStaff() if you use a specific role name)
//
// Writes on quote_requests/{id}
//   assignedTo (uid), assignedName, assignedPhone, assignedAt
//   scheduledDate, scheduledSlot, crewNote
//   jobStatus: scheduled | on_the_way | in_progress | completed
//   startedAt, completedAt, beforePhotos[], afterPhotos[]
//   status stays 'scheduled' until the job is completed -> 'completed'
//   (so the Quote Pipeline page keeps working unchanged)
//
// Storage: jobs/{requestId}/{file}
// Also writes notifications/{id} for the customer and the assigned person.
//
// Usage:
//   const JobsPage()                  // widget (sidebar / body)
//   openJobsPage();                   // navigate with GetX, no context
//   openJobById(context, 'docId');    // open one job's detail popup
//
// Packages: cloud_firestore, firebase_auth, firebase_storage,
//           file_picker, url_launcher, get
// =============================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
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
const _blue = Color(0xFF2145E6);

class _St {
  final String label;
  final Color color;
  final IconData icon;
  const _St(this.label, this.color, this.icon);
}

/// Job progress (order matters).
const _jobKeys = ['scheduled', 'on_the_way', 'in_progress', 'completed'];
const _jobSt = <String, _St>{
  'scheduled': _St(
    'Scheduled',
    Color(0xFF1B1464),
    Icons.event_available_rounded,
  ),
  'on_the_way': _St(
    'On the way',
    Color(0xFF2271B1),
    Icons.directions_car_rounded,
  ),
  'in_progress': _St(
    'In progress',
    Color(0xFFE67E22),
    Icons.construction_rounded,
  ),
  'completed': _St('Completed', Color(0xFF22B573), Icons.task_alt_rounded),
};

const _slots = {
  'Morning': '8 AM – 12 PM',
  'Afternoon': '12 – 4 PM',
  'Evening': '4 – 8 PM',
};

const _svcIcons = <String, IconData>{
  'Painting': Icons.format_paint_outlined,
  'Moving': Icons.local_shipping_outlined,
  'Cleaning': Icons.cleaning_services_outlined,
  'Assembly': Icons.build_outlined,
  'Lawn Services': Icons.grass_outlined,
  'Waste Disposal': Icons.delete_outline,
  'Pressure Washing': Icons.water_drop_outlined,
  'Seasonal Services': Icons.ac_unit_outlined,
  'General Handyman': Icons.handyman_outlined,
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

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Today", "Tomorrow", "Yesterday" or a date.
String _rel(DateTime d) {
  final diff = _day(d).difference(_day(DateTime.now())).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return _d(d);
}

double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
}

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

InputDecoration _dec(String? label, {String? hint, IconData? icon}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20, color: _muted),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: _ob(_line),
      enabledBorder: _ob(_line),
      focusedBorder: _ob(_orange, w: 1.6),
    );

Widget _chip(String key, {bool small = false}) {
  final m = _jobSt[key] ?? _St(key, Colors.grey, Icons.circle);
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

Widget _box({required Widget child, EdgeInsets? pad, Color? color}) =>
    Container(
      width: double.infinity,
      padding: pad ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
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

Widget _label(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    t,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      color: _ink,
      fontSize: 13,
    ),
  ),
);

Widget _btn(
  String label,
  IconData icon,
  VoidCallback? onTap, {
  Color color = _blue,
  bool busy = false,
}) => SizedBox(
  width: double.infinity,
  height: 48,
  child: ElevatedButton.icon(
    onPressed: busy ? null : onTap,
    icon: busy
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 18),
    label: Text(label, overflow: TextOverflow.ellipsis),
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: color,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
);

Future<bool> _confirm(
  BuildContext context,
  String title,
  String body, {
  String ok = 'Confirm',
  Color color = _blue,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title),
      content: Text(body, style: const TextStyle(height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: _muted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

// ── Models ──────────────────────────────────────────────────
class _Staff {
  _Staff(this.uid, this.m);
  final String uid;
  final Map<String, dynamic> m;
  String get name {
    final n = '${m['name'] ?? ''}'.trim();
    return n.isEmpty ? '${m['email'] ?? 'Unnamed'}' : n;
  }

  String get phone => '${m['phone'] ?? ''}';
  String get role => '${m['role'] ?? ''}';
}

/// Everyone who is not a customer can be assigned to a job.
bool _isStaff(Map<String, dynamic> m) =>
    '${m['role'] ?? ''}'.toLowerCase() != 'customer';

class _Job {
  _Job(this.id, this.m);
  final String id;
  final Map<String, dynamic> m;
  factory _Job.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      _Job(d.id, d.data() ?? {});

  String s(String k) => (m[k] ?? '').toString();
  String get number => s('requestNumber').isEmpty ? id : s('requestNumber');
  String get customer =>
      s('customerName').isEmpty ? 'Customer' : s('customerName');
  String get service => s('service');
  String get address => s('address');

  DateTime? _ts(String k) =>
      m[k] is Timestamp ? (m[k] as Timestamp).toDate() : null;
  DateTime? get date => _ts('scheduledDate');
  DateTime? get completedAt => _ts('completedAt');
  String get slot => s('scheduledSlot');

  /// Only requests that were actually scheduled count as jobs.
  bool get isJob =>
      date != null &&
      (s('status') == 'scheduled' || s('status') == 'completed');

  String get stage {
    if (s('status') == 'completed') return 'completed';
    final j = s('jobStatus');
    return _jobKeys.contains(j) ? j : 'scheduled';
  }

  int get stageIndex => _jobKeys.indexOf(stage);
  bool get done => stage == 'completed';

  String get assignedUid => s('assignedTo');
  bool get unassigned => assignedUid.isEmpty;
  String get assignedName => s('assignedName');

  double get total {
    final t = _num(m['quoteTotal']);
    if (t > 0) return t;
    final q = m['quote'] is Map ? _num((m['quote'] as Map)['total']) : 0.0;
    return q > 0 ? q : _num(m['quoteAmount']);
  }

  double get advance => _num(m['depositNow']);
  double get later => m['depositLater'] != null
      ? _num(m['depositLater'])
      : (total - advance < 0 ? 0 : total - advance);
  bool get balancePaid => m['balancePaid'] == true;

  List<String> photos(String k) => ((m[k] as List?) ?? [])
      .map((e) => '$e')
      .where((e) => e.isNotEmpty)
      .toList();

  bool get isToday => date != null && _day(date!) == _day(DateTime.now());
  bool get overdue =>
      !done && date != null && _day(date!).isBefore(_day(DateTime.now()));
}

// ── Backend ─────────────────────────────────────────────────
class _Api {
  static final db = FirebaseFirestore.instance;
  static DocumentReference<Map<String, dynamic>> req(String id) =>
      db.collection('quote_requests').doc(id);
  static String get me => FirebaseAuth.instance.currentUser?.email ?? 'admin';

  static Map<String, dynamic> hist(String status, String note) => {
    'status': status,
    'at': Timestamp.now(),
    'by': me,
    if (note.isNotEmpty) 'note': note,
  };

  static Future<void> notify(
    String uid,
    String title,
    String body,
    String requestId,
  ) async {
    if (uid.isEmpty) return;
    try {
      await db.collection('notifications').add({
        'userId': uid,
        'title': title,
        'body': body,
        'type': 'job',
        'requestId': requestId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static final Stream<List<_Job>> jobs = db
      .collection('quote_requests')
      .where('status', whereIn: ['scheduled', 'completed'])
      .snapshots()
      .map((s) {
        final l = s.docs.map(_Job.fromDoc).where((j) => j.isJob).toList();
        l.sort((a, b) => a.date!.compareTo(b.date!));
        return l;
      });

  static final Stream<List<_Staff>> staff = db
      .collection('users')
      .snapshots()
      .map((s) {
        final l = s.docs
            .where((d) => _isStaff(d.data()))
            .map((d) => _Staff(d.id, d.data()))
            .toList();
        l.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return l;
      });
}

/// Opens the Jobs screen. No context needed.
void openJobsPage() => Get.to(() => const JobsPage());

// =============================================================
// PAGE
// =============================================================
class JobsPage extends StatefulWidget {
  const JobsPage({super.key});
  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  String _filter = 'all';
  String _q = '';

  static const _filters = <String, String>{
    'all': 'All',
    'today': 'Today',
    'upcoming': 'Upcoming',
    'progress': 'In Progress',
    'completed': 'Completed',
    'unassigned': 'Unassigned',
  };

  bool _match(_Job j, String f) {
    switch (f) {
      case 'today':
        return j.isToday && !j.done;
      case 'upcoming':
        return !j.done && j.stage == 'scheduled' && !j.isToday;
      case 'progress':
        return j.stage == 'on_the_way' || j.stage == 'in_progress';
      case 'completed':
        return j.done;
      case 'unassigned':
        return j.unassigned && !j.done;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Jobs',
    subtitle: 'Scheduled work — assign a person, track progress, close the job',
    children: [
      StreamBuilder<List<_Job>>(
        stream: _Api.jobs,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('Could not load jobs.\n${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final all = snap.data!;
          int count(String f) => all.where((j) => _match(j, f)).length;
          final q = _q.toLowerCase();
          final list = all.where((j) {
            if (!_match(j, _filter)) return false;
            if (q.isEmpty) return true;
            return '${j.customer} ${j.number} ${j.service} ${j.address} ${j.assignedName}'
                .toLowerCase()
                .contains(q);
          }).toList();
          if (_filter == 'completed') {
            list.sort((a, b) => b.date!.compareTo(a.date!));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stats(count),
              const SizedBox(height: 20),
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: _dec(
                  null,
                  hint: 'Search customer, reference, service, address, person',
                  icon: Icons.search,
                ),
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
                          showCheckmark: false,
                          label: Text(
                            '${e.value}  ${e.key == 'all' ? all.length : count(e.key)}',
                          ),
                          selected: _filter == e.key,
                          selectedColor: _orange,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: _line),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _filter == e.key ? Colors.white : _ink,
                          ),
                          onSelected: (_) => setState(() => _filter = e.key),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'No jobs found.\nJobs appear here once a request is scheduled.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, height: 1.5),
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (_, b) =>
                      b.maxWidth >= 860 ? _table(list) : _cards(list),
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget _stats(int Function(String) count) {
    final items = <(String, String, Color, IconData)>[
      ('today', 'Today', _navy, Icons.today_rounded),
      ('upcoming', 'Upcoming', const Color(0xFF2271B1), Icons.event_rounded),
      (
        'progress',
        'In Progress',
        const Color(0xFFE67E22),
        Icons.construction_rounded,
      ),
      ('unassigned', 'Unassigned', _red, Icons.person_off_rounded),
      ('completed', 'Completed', _green, Icons.task_alt_rounded),
    ];
    return LayoutBuilder(
      builder: (_, b) {
        final cols = b.maxWidth >= 1000 ? 5 : (b.maxWidth >= 640 ? 3 : 2);
        const gap = 10.0;
        final w = ((b.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final it in items)
              SizedBox(
                width: w,
                child: Material(
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _filter == it.$1 ? it.$3 : _line,
                      width: _filter == it.$1 ? 1.8 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => setState(
                      () => _filter = _filter == it.$1 ? 'all' : it.$1,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          Container(width: 5, color: it.$3),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${count(it.$1)}',
                                          style: const TextStyle(
                                            fontSize: 26,
                                            height: 1.1,
                                            fontWeight: FontWeight.w900,
                                            color: _navy,
                                          ),
                                        ),
                                        Text(
                                          it.$2,
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
                                  Icon(
                                    it.$4,
                                    color: it.$3.withValues(alpha: .6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _who(_Job j, {double size = 13}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        j.unassigned ? Icons.person_off_outlined : Icons.person_rounded,
        size: 15,
        color: j.unassigned ? _red : _green,
      ),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          j.unassigned ? 'Unassigned' : j.assignedName,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w700,
            color: j.unassigned ? _red : _ink,
          ),
        ),
      ),
    ],
  );

  Widget _when(_Job j) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _rel(j.date!),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: j.overdue ? _red : (j.isToday ? _orange : _ink),
        ),
      ),
      Text(
        j.slot.isEmpty ? '—' : j.slot,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, fontSize: 12),
      ),
    ],
  );

  Widget _table(List<_Job> list) {
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
                cell(3, const Text('Job', style: head)),
                cell(2, const Text('Service', style: head)),
                cell(2, const Text('Schedule', style: head)),
                cell(2, const Text('Assigned to', style: head)),
                cell(2, const Text('Amount', style: head)),
                cell(2, const Text('Status', style: head)),
                const SizedBox(width: 24),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          for (var i = 0; i < list.length; i++)
            InkWell(
              onTap: () => openJobById(context, list[i].id),
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
                            '${list[i].number} • ${list[i].address}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    cell(
                      2,
                      Text(list[i].service, overflow: TextOverflow.ellipsis),
                    ),
                    cell(2, _when(list[i])),
                    cell(2, _who(list[i])),
                    cell(
                      2,
                      Text(
                        _money(list[i].total),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    cell(
                      2,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _chip(list[i].stage),
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

  Widget _cards(List<_Job> list) =>
      Column(children: [for (final j in list) _tile(j)]);

  Widget _tile(_Job j) {
    final color = _jobSt[j.stage]!.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: j.overdue ? _red : _line),
        ),
        child: InkWell(
          onTap: () => openJobById(context, j.id),
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
                      child: Icon(
                        _svcIcons[j.service] ?? Icons.handyman_outlined,
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            j.customer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _ink,
                            ),
                          ),
                          Text(
                            '${j.number} • ${j.service}',
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
                    _chip(j.stage, small: true),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.event_rounded, size: 16, color: _muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_rel(j.date!)}${j.slot.isEmpty ? '' : ' • ${j.slot}'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: j.overdue
                              ? _red
                              : (j.isToday ? _orange : _ink),
                        ),
                      ),
                    ),
                    Text(
                      _money(j.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 16, color: _muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        j.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _who(j, size: 12.5),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Public entry point (use from the dashboard etc.).
void openJobById(BuildContext context, String id) {
  final narrow = MediaQuery.of(context).size.width < 700;
  showDialog(
    context: context,
    builder: (_) => _JobDialog(id: id, fullscreen: narrow),
  );
}

// =============================================================
// JOB DETAIL DIALOG
// =============================================================
class _JobDialog extends StatefulWidget {
  const _JobDialog({required this.id, required this.fullscreen});
  final String id;
  final bool fullscreen;
  @override
  State<_JobDialog> createState() => _JobDialogState();
}

class _JobDialogState extends State<_JobDialog> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _s = _Api.req(
    widget.id,
  ).snapshots();

  @override
  Widget build(BuildContext context) {
    final content = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
            child: Text('Job not found'),
          );
        }
        final j = _Job.fromDoc(snap.data!);
        if (!j.isJob) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This request is not scheduled yet.\nSchedule it in the Quote Pipeline first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, height: 1.5),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
        return Column(
          mainAxisSize: widget.fullscreen ? MainAxisSize.max : MainAxisSize.min,
          children: [
            _header(j),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: LayoutBuilder(
                  builder: (_, b) {
                    final panel = _JobPanel(
                      key: ValueKey('${j.id}-${j.stage}-${j.assignedUid}'),
                      j: j,
                    );
                    final info = _JobInfo(j: j);
                    final track = _Track(j: j);
                    if (b.maxWidth < 780) {
                      return Column(
                        children: [
                          track,
                          const SizedBox(height: 16),
                          panel,
                          const SizedBox(height: 16),
                          info,
                        ],
                      );
                    }
                    return Column(
                      children: [
                        track,
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: info),
                            const SizedBox(width: 16),
                            SizedBox(width: 380, child: panel),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    if (widget.fullscreen) {
      return Dialog.fullscreen(
        backgroundColor: _bg,
        child: SafeArea(child: content),
      );
    }
    return Dialog(
      backgroundColor: _bg,
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1080,
          maxHeight: MediaQuery.of(context).size.height * .94,
        ),
        child: content,
      ),
    );
  }

  Widget _header(_Job j) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${j.number} — ${j.customer}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              Text(
                '${j.service} • ${_rel(j.date!)}${j.slot.isEmpty ? '' : ' • ${j.slot}'}',
                style: const TextStyle(color: _muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _chip(j.stage, small: true),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

// =============================================================
// PROGRESS TRACK
// =============================================================
class _Track extends StatelessWidget {
  const _Track({required this.j});
  final _Job j;

  @override
  Widget build(BuildContext context) {
    final cur = j.stageIndex;
    return _box(
      pad: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        children: [
          for (var i = 0; i < _jobKeys.length; i++)
            Expanded(child: _step(i, cur)),
        ],
      ),
    );
  }

  Widget _step(int i, int cur) {
    final m = _jobSt[_jobKeys[i]]!;
    final done = i < cur || cur == _jobKeys.length - 1;
    final active = i == cur;
    final on = done || active;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 3,
                color: i == 0 ? Colors.transparent : (on ? _green : _line),
              ),
            ),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? _green : (active ? m.color : Colors.white),
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? Colors.transparent : _line,
                  width: 2,
                ),
              ),
              child: Icon(
                done ? Icons.check : m.icon,
                size: 16,
                color: on ? Colors.white : _muted,
              ),
            ),
            Expanded(
              child: Container(
                height: 3,
                color: i == _jobKeys.length - 1
                    ? Colors.transparent
                    : (done ? _green : _line),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          m.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            color: on ? _ink : _muted,
          ),
        ),
      ],
    );
  }
}

// =============================================================
// JOB INFO (left column)
// =============================================================
class _JobInfo extends StatelessWidget {
  const _JobInfo({required this.j});
  final _Job j;

  Widget _row(String k, String v, int i, {String? uri}) => Container(
    color: i.isOdd ? _bg : Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
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

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, String?)>[
      ('Customer', j.customer, null),
      ('Phone', j.s('phone'), 'tel:${j.s('phone')}'),
      ('Email', j.s('email'), 'mailto:${j.s('email')}'),
      ('Service', j.service, null),
      ('Description', j.s('description'), null),
      (
        'Address',
        j.address,
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(j.address)}',
      ),
      ('Date', _d(j.date!), null),
      ('Time slot', j.slot, null),
      ('Total', _money(j.total), null),
      ('Advance', _money(j.advance), null),
      (
        'Balance',
        '${_money(j.later)}${j.balancePaid ? '  ✓ received' : (j.done ? '  • due' : '')}',
        null,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Job details',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: _ink,
          ),
        ),
        const SizedBox(height: 10),
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
        _heading('Before photos (${j.photos('beforePhotos').length})'),
        _Photos(j: j, field: 'beforePhotos'),
        _heading('After photos (${j.photos('afterPhotos').length})'),
        _Photos(j: j, field: 'afterPhotos'),
      ],
    );
  }
}

// =============================================================
// PHOTOS (before / after upload)
// =============================================================
class _Photos extends StatefulWidget {
  const _Photos({required this.j, required this.field});
  final _Job j;
  final String field;
  @override
  State<_Photos> createState() => _PhotosState();
}

class _PhotosState extends State<_Photos> {
  bool _busy = false;

  Future<void> _add() async {
    try {
      final picked = await FilePicker.pickFiles(type: FileType.image);
      if (picked.isEmpty) return;
      setState(() => _busy = true);
      final urls = <String>[];
      for (final f in picked) {
        final bytes = await f.readAsBytes();
        if (bytes.isEmpty || bytes.length > 15 * 1024 * 1024) continue;
        final ext = f.name.contains('.')
            ? f.name.split('.').last.toLowerCase()
            : 'jpg';
        final ref = FirebaseStorage.instance.ref(
          'jobs/${widget.j.id}/${widget.field}_${DateTime.now().millisecondsSinceEpoch}_${urls.length}.$ext',
        );
        await ref.putData(
          bytes,
          SettableMetadata(
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
        urls.add(await ref.getDownloadURL());
      }
      if (urls.isNotEmpty) {
        await _Api.req(widget.j.id).update({
          widget.field: FieldValue.arrayUnion(urls),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _toast('${urls.length} photo(s) added');
      }
    } on FirebaseException catch (e) {
      _toast(e.message ?? 'Upload failed. Check Storage rules.', error: true);
    } catch (_) {
      _toast('Could not add photos', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove(String url) async {
    if (!await _confirm(
      context,
      'Remove photo?',
      'This removes it from the job.',
      ok: 'Remove',
      color: _red,
    )) {
      return;
    }
    try {
      await _Api.req(widget.j.id).update({
        widget.field: FieldValue.arrayRemove([url]),
      });
    } catch (_) {
      _toast('Could not remove photo', error: true);
    }
  }

  void _view(String url) => showDialog(
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
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              children: [
                IconButton(
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

  @override
  Widget build(BuildContext context) {
    final urls = widget.j.photos(widget.field);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final u in urls)
          Stack(
            children: [
              InkWell(
                onTap: () => _view(u),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 92,
                  height: 92,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _line),
                    color: Colors.white,
                  ),
                  child: Image.network(
                    u,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined, color: _muted),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: InkWell(
                  onTap: () => _remove(u),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        InkWell(
          onTap: _busy ? null : _add,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _orange.withValues(alpha: .4)),
            ),
            child: _busy
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: _orange),
                      SizedBox(height: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: _orange,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// =============================================================
// JOB PANEL (assign person, progress, reschedule, notes)
// =============================================================
class _JobPanel extends StatefulWidget {
  const _JobPanel({super.key, required this.j});
  final _Job j;
  @override
  State<_JobPanel> createState() => _JobPanelState();
}

class _JobPanelState extends State<_JobPanel> {
  final _note = TextEditingController();
  String? _pick; // selected staff uid
  bool _busy = false;
  bool _resched = false;
  DateTime? _newDate;
  String _newSlot = 'Morning';

  _Job get j => widget.j;

  @override
  void initState() {
    super.initState();
    _note.text = j.s('crewNote');
    _pick = j.unassigned ? null : j.assignedUid;
    _newDate = j.date;
    for (final k in _slots.keys) {
      if (j.slot.startsWith(k)) _newSlot = k;
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f, String ok) async {
    setState(() => _busy = true);
    try {
      await f();
      _toast(ok);
    } on FirebaseException catch (e) {
      _toast(e.message ?? 'Action failed. Check permissions.', error: true);
    } catch (_) {
      _toast('Something went wrong. Please try again.', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _assign(List<_Staff> staff) async {
    final p = staff.where((e) => e.uid == _pick).toList();
    if (p.isEmpty) {
      _toast('Choose a person first', error: true);
      return;
    }
    final who = p.first;
    await _run(() async {
      await _Api.req(j.id).update({
        'assignedTo': who.uid,
        'assignedName': who.name,
        'assignedPhone': who.phone,
        'assignedAt': FieldValue.serverTimestamp(),
        'crewNote': _note.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          _Api.hist('scheduled', 'Assigned to ${who.name}'),
        ]),
      });
      await _Api.notify(
        who.uid,
        'New job assigned',
        '${j.service} for ${j.customer} on ${_d(j.date!)}'
            '${j.slot.isEmpty ? '' : ' (${j.slot})'}\n${j.address}',
        j.id,
      );
      await _Api.notify(
        j.s('userId'),
        'Your job has a team member',
        '${who.name} is assigned to your ${j.service} job on ${_d(j.date!)}.',
        j.id,
      );
    }, 'Assigned to ${who.name}');
  }

  Future<void> _unassign() async {
    if (!await _confirm(
      context,
      'Remove assignment?',
      '${j.assignedName} will be removed from this job.',
      ok: 'Remove',
      color: _red,
    )) {
      return;
    }
    await _run(() async {
      await _Api.req(j.id).update({
        'assignedTo': null,
        'assignedName': '',
        'assignedPhone': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          _Api.hist('scheduled', 'Unassigned ${j.assignedName}'),
        ]),
      });
      await _Api.notify(
        j.assignedUid,
        'Job unassigned',
        '${j.service} for ${j.customer} was removed from your list.',
        j.id,
      );
      if (mounted) setState(() => _pick = null);
    }, 'Assignment removed');
  }

  Future<void> _saveNote() => _run(
    () => _Api.req(j.id).update({
      'crewNote': _note.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
    'Notes saved',
  );

  Future<void> _setStage(String key, String msg) async {
    if (j.unassigned && key != 'scheduled') {
      _toast('Assign a person before starting the job', error: true);
      return;
    }
    await _run(() async {
      await _Api.req(j.id).update({
        'jobStatus': key,
        if (key == 'in_progress') 'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          _Api.hist('scheduled', _jobSt[key]!.label),
        ]),
      });
      await _Api.notify(j.s('userId'), 'Job update', msg, j.id);
    }, _jobSt[key]!.label);
  }

  Future<void> _complete() async {
    if (!await _confirm(
      context,
      'Mark job completed?',
      'The customer will be notified.\nBalance due: ${_money(j.later)}.',
      ok: 'Complete',
      color: _green,
    )) {
      return;
    }
    await _run(() async {
      await _Api.req(j.id).update({
        'status': 'completed',
        'jobStatus': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          _Api.hist('completed', 'Job completed'),
        ]),
      });
      await _Api.notify(
        j.s('userId'),
        'Job completed',
        'Your ${j.service} job is complete. Balance due: ${_money(j.later)}.',
        j.id,
      );
    }, 'Job completed');
  }

  Future<void> _pickNewDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (_newDate ?? now).isBefore(now) ? now : (_newDate ?? now),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _newDate = d);
  }

  Future<void> _reschedule() async {
    if (_newDate == null) return;
    final label = '${_d(_newDate!)} • $_newSlot (${_slots[_newSlot]})';
    await _run(() async {
      await _Api.req(j.id).update({
        'scheduledDate': Timestamp.fromDate(_newDate!),
        'scheduledSlot': '$_newSlot (${_slots[_newSlot]})',
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          _Api.hist('scheduled', 'Rescheduled to $label'),
        ]),
      });
      await _Api.notify(
        j.s('userId'),
        'Job rescheduled',
        'Your ${j.service} job is now $label.',
        j.id,
      );
      await _Api.notify(
        j.assignedUid,
        'Job rescheduled',
        '${j.service} for ${j.customer} is now $label.',
        j.id,
      );
      if (mounted) setState(() => _resched = false);
    }, 'Job rescheduled');
  }

  Widget _title(String t, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: _ink,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        sub,
        style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.35),
      ),
      const SizedBox(height: 14),
    ],
  );

  Widget _assignSection() => StreamBuilder<List<_Staff>>(
    stream: _Api.staff,
    builder: (context, snap) {
      final staff = snap.data ?? const <_Staff>[];
      final valid = staff.any((e) => e.uid == _pick) ? _pick : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Assigned person'),
          if (!j.unassigned)
            _box(
              color: _green.withValues(alpha: .08),
              pad: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: _green,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          j.assignedName,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (j.s('assignedPhone').isNotEmpty)
                          Text(
                            j.s('assignedPhone'),
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (j.s('assignedPhone').isNotEmpty)
                    IconButton(
                      onPressed: () => _open('tel:${j.s('assignedPhone')}'),
                      icon: const Icon(Icons.call, color: _green),
                    ),
                ],
              ),
            ),
          if (!j.unassigned) const SizedBox(height: 10),
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData)
            const LinearProgressIndicator()
          else if (staff.isEmpty)
            const Text(
              'No staff profiles found in the users collection.',
              style: TextStyle(color: _muted, fontSize: 12.5),
            )
          else
            DropdownButtonFormField<String>(
              value: valid,
              isExpanded: true,
              decoration: _dec(
                null,
                hint: 'Select person',
                icon: Icons.person_search,
              ),
              items: [
                for (final s in staff)
                  DropdownMenuItem(
                    value: s.uid,
                    child: Text(
                      s.role.isEmpty ? s.name : '${s.name}  •  ${s.role}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (j.done || _busy)
                  ? null
                  : (v) => setState(() => _pick = v),
            ),
          if (!j.done && staff.isNotEmpty) ...[
            const SizedBox(height: 10),
            _btn(
              j.unassigned ? 'Assign to job' : 'Change person',
              Icons.person_add_alt_1_rounded,
              (_pick == null || _pick == j.assignedUid)
                  ? null
                  : () => _assign(staff),
              busy: _busy,
            ),
            if (!j.unassigned)
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _unassign,
                  child: const Text(
                    'Remove assignment',
                    style: TextStyle(color: _red),
                  ),
                ),
              ),
          ],
        ],
      );
    },
  );

  Widget _progressSection() {
    if (j.done) {
      return _box(
        color: _green.withValues(alpha: .1),
        child: Row(
          children: [
            const Icon(Icons.verified_rounded, color: _green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Completed${j.completedAt == null ? '' : ' • ${_dt(j.completedAt!)}'}'
                '\nBalance ${_money(j.later)} ${j.balancePaid ? 'received' : 'due — collect it in Quote Pipeline'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }
    switch (j.stage) {
      case 'scheduled':
        return _btn(
          'On the way',
          Icons.directions_car_rounded,
          () => _setStage(
            'on_the_way',
            'Our team is on the way to your location.',
          ),
          color: const Color(0xFF2271B1),
          busy: _busy,
        );
      case 'on_the_way':
        return _btn(
          'Start job',
          Icons.play_arrow_rounded,
          () => _setStage(
            'in_progress',
            'Work has started on your ${j.service} job.',
          ),
          color: const Color(0xFFE67E22),
          busy: _busy,
        );
      default:
        return _btn(
          'Mark job completed',
          Icons.task_alt_rounded,
          _complete,
          color: _green,
          busy: _busy,
        );
    }
  }

  Widget _reschedSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!_resched)
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _resched = true),
            icon: const Icon(Icons.edit_calendar_rounded, size: 18),
            label: const Text('Reschedule job'),
          ),
        )
      else ...[
        _label('New date'),
        OutlinedButton.icon(
          onPressed: _pickNewDate,
          icon: const Icon(Icons.event, size: 18),
          label: Text(_newDate == null ? 'Select date' : _d(_newDate!)),
        ),
        const SizedBox(height: 10),
        _label('Time slot'),
        DropdownButtonFormField<String>(
          value: _newSlot,
          isExpanded: true,
          decoration: _dec(null),
          items: [
            for (final e in _slots.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text('${e.key} (${e.value})'),
              ),
          ],
          onChanged: (v) => setState(() => _newSlot = v!),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _resched = false),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _busy ? null : _reschedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save new time'),
              ),
            ),
          ],
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => _box(
    pad: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          j.done ? 'Job closed' : 'Manage job',
          j.done
              ? 'This job is finished.'
              : 'Assign a person, update progress and add instructions.',
        ),
        _assignSection(),
        const Divider(height: 30, color: _line),
        _label('Instructions / notes for the person'),
        TextField(
          controller: _note,
          maxLines: 3,
          decoration: _dec(null, hint: 'Gate code, tools, materials, access…'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: _busy ? null : _saveNote,
            child: const Text('Save notes'),
          ),
        ),
        const Divider(height: 30, color: _line),
        _label('Progress'),
        _progressSection(),
        if (!j.done) ...[
          const Divider(height: 30, color: _line),
          _reschedSection(),
        ],
      ],
    ),
  );
}
