// =============================================================
// calendar_page.dart — Admin: Calendar & Scheduling (single file, live)
//
// Reads quote_requests (live). Nothing is written here; tap any item
// to open the request, where you schedule / complete the job.
//
//   scheduled  status 'scheduled'  + scheduledDate  -> Scheduled job
//   completed  status 'completed'  + scheduledDate  -> Completed job
//   ready      quote accepted + advance paid, not scheduled
//              -> "Ready to schedule" (shown on customer's preferredDate)
//   requested  any other open request with preferredDate
//              -> "Requested date" (new / review / quoted / accepted)
//
// Example: customer asks for Painting on Nov 12 -> orange "Requested"
// marker on Nov 12. You quote, they accept and pay the advance -> it turns
// green "Ready to schedule". You schedule it (Nov 14, Morning) in the
// request dialog -> navy "Scheduled" marker moves to Nov 14.
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
const _grey = Color(0xFF4F5D75);

class _Kind {
  final String label;
  final Color color;
  const _Kind(this.label, this.color);
}

const _kinds = <String, _Kind>{
  'scheduled': _Kind('Scheduled', _navy),
  'ready': _Kind('Ready to schedule', _green),
  'requested': _Kind('Requested date', _orange),
  'completed': _Kind('Completed', _grey),
};

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
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
const _wd = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

String _d(DateTime d) => '${_mon[d.month - 1]} ${d.day}, ${d.year}';
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
bool _same(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;
}

String _money(num v) {
  final p = v.toStringAsFixed(2).split('.');
  final i = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '\$$i.${p[1]}';
}

// ── Model ───────────────────────────────────────────────────
class _Ev {
  _Ev(this.id, this.m, this.kind, this.date);
  final String id;
  final Map<String, dynamic> m;
  final String kind;
  final DateTime date;

  String s(String k) => (m[k] ?? '').toString();
  String get number => s('requestNumber').isEmpty ? id : s('requestNumber');
  String get customer =>
      s('customerName').isEmpty ? 'Customer' : s('customerName');
  String get service => s('service');
  String get address => s('address');
  String get slot => kind == 'scheduled' || kind == 'completed'
      ? s('scheduledSlot')
      : s('preferredSlot');
  double get total {
    final t = _num(m['quoteTotal']);
    if (t > 0) return t;
    final q = m['quote'] is Map ? _num((m['quote'] as Map)['total']) : 0;
    return q > 0 ? q.toDouble() : _num(m['quoteAmount']);
  }

  _Kind get meta => _kinds[kind]!;

  static DateTime? _ts(dynamic v) => v is Timestamp ? v.toDate() : null;

  /// Builds the calendar item for a request (or null if it has no date).
  static _Ev? from(String id, Map<String, dynamic> m) {
    final status = '${m['status'] ?? 'pending'}';
    final sched = _ts(m['scheduledDate']);
    final pref = _ts(m['preferredDate']);
    final paid = m['advancePaid'] == true || m['depositPaid'] == true;

    if (status == 'rejected' || status == 'cancelled') return null;
    if (status == 'scheduled' && sched != null) {
      return _Ev(id, m, 'scheduled', _day(sched));
    }
    if (status == 'completed') {
      final d = sched ?? pref;
      return d == null ? null : _Ev(id, m, 'completed', _day(d));
    }
    if (pref == null) return null;
    if (status == 'accepted' && paid) return _Ev(id, m, 'ready', _day(pref));
    return _Ev(id, m, 'requested', _day(pref));
  }
}

// =============================================================
// PAGE
// =============================================================
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late final Stream<List<_Ev>> _stream = FirebaseFirestore.instance
      .collection('quote_requests')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if (_Ev.from(d.id, d.data()) case final e?) e,
        ],
      );

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _sel = _day(DateTime.now());
  String? _only; // kind filter (legend chips)

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Calendar & Scheduling',
    subtitle: 'Scheduled jobs and customer-requested dates, live',
    children: [
      StreamBuilder<List<_Ev>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('Could not load calendar.\n${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _content(snap.data!);
        },
      ),
    ],
  );

  Widget _content(List<_Ev> all) {
    final list = _only == null
        ? all
        : all.where((e) => e.kind == _only).toList();
    final inMonth = all
        .where(
          (e) => e.date.year == _month.year && e.date.month == _month.month,
        )
        .toList();
    int cnt(String k) => inMonth.where((e) => e.kind == k).length;
    final todo = all.where((e) => e.kind == 'ready').toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final grid = _grid(list);
    final side = Column(
      children: [
        _dayPanel(list.where((e) => _same(e.date, _sel)).toList()),
        if (todo.isNotEmpty) ...[const SizedBox(height: 14), _todoPanel(todo)],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (_, b) {
            final cols = b.maxWidth >= 900 ? 4 : 2;
            const gap = 10.0;
            final w = ((b.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final k in _kinds.keys)
                  SizedBox(
                    width: w,
                    child: _StatCard(
                      label: _kinds[k]!.label,
                      count: cnt(k),
                      color: _kinds[k]!.color,
                      selected: _only == k,
                      onTap: () =>
                          setState(() => _only = _only == k ? null : k),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 14),
          child: Text(
            _only == null
                ? 'This month · tap a card to filter the calendar'
                : 'Showing only “${_kinds[_only]!.label}” · tap the card again to clear',
            style: const TextStyle(color: _muted, fontSize: 12.5),
          ),
        ),
        LayoutBuilder(
          builder: (_, b) => b.maxWidth >= 900
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: grid),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: side),
                  ],
                )
              : Column(children: [grid, const SizedBox(height: 16), side]),
        ),
      ],
    );
  }

  // ── month grid ──
  Widget _grid(List<_Ev> list) {
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = first.weekday % 7;
    final today = _day(DateTime.now());
    final byDay = <int, List<_Ev>>{};
    for (final e in list) {
      if (e.date.year == _month.year && e.date.month == _month.month) {
        byDay.putIfAbsent(e.date.day, () => []).add(e);
      }
    }

    return _box(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1, 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${_months[_month.month - 1]} ${_month.year}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: _ink,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _month = DateTime(today.year, today.month, 1);
                  _sel = today;
                }),
                child: const Text('Today'),
              ),
              IconButton(
                onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1, 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (_, b) {
              final wide = b.maxWidth >= 560;
              final cellH = wide ? 92.0 : 52.0;
              return Column(
                children: [
                  Row(
                    children: [
                      for (final w in _wd)
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                wide ? w : w[0],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: (b.maxWidth / 7) / cellH,
                    children: [
                      for (var i = 0; i < offset; i++) const SizedBox(),
                      for (var d = 1; d <= days; d++)
                        _cell(
                          DateTime(_month.year, _month.month, d),
                          byDay[d] ?? const [],
                          wide,
                          _same(DateTime(_month.year, _month.month, d), today),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _cell(DateTime date, List<_Ev> evs, bool wide, bool isToday) {
    final sel = _same(date, _sel);
    return InkWell(
      onTap: () => setState(() => _sel = date),
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: EdgeInsets.all(wide ? 6 : 4),
        decoration: BoxDecoration(
          color: sel ? _navy : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? _navy : (isToday ? _orange : _line),
            width: isToday && !sel ? 1.6 : 1,
          ),
        ),
        child: ClipRect(
          child: Column(
            crossAxisAlignment: wide
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: wide ? 13 : 12.5,
                  color: sel ? Colors.white : _ink,
                ),
              ),
              const Spacer(),
              if (evs.isNotEmpty)
                wide
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final e in evs.take(2))
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: e.meta.color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                e.customer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (evs.length > 2)
                            Text(
                              '+${evs.length - 2} more',
                              style: TextStyle(
                                fontSize: 10,
                                color: sel ? Colors.white70 : _muted,
                              ),
                            ),
                        ],
                      )
                    : Wrap(
                        spacing: 2,
                        runSpacing: 2,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final e in evs.take(3))
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: sel ? Colors.white : e.meta.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
            ],
          ),
        ),
      ),
    );
  }

  // ── selected-day panel ──
  Widget _dayPanel(List<_Ev> evs) => _box(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _d(_sel),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: _ink,
          ),
        ),
        Text(
          evs.isEmpty
              ? 'Nothing on this day'
              : '${evs.length} item${evs.length > 1 ? 's' : ''}',
          style: const TextStyle(color: _muted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        if (evs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                'No jobs or requests',
                style: TextStyle(color: _muted),
              ),
            ),
          )
        else
          for (final e in evs) _evTile(e),
      ],
    ),
  );

  Widget _evTile(_Ev e, {bool showDate = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: _bg,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openRequestById(context, e.id),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: e.meta.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.customer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: e.meta.color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              e.meta.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${e.number} • ${e.service}'
                        '${showDate ? ' • ${_d(e.date)}' : ''}'
                        '${e.slot.isEmpty ? '' : ' • ${e.slot}'}',
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                      ),
                      if (e.address.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 13,
                                color: _muted,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  e.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (e.total > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Quote ${_money(e.total)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: _ink,
                            ),
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
    ),
  );

  // ── jobs waiting to be scheduled ──
  Widget _todoPanel(List<_Ev> todo) => _box(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_available_rounded, color: _green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Needs scheduling (${todo.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
        const Text(
          'Quote accepted and advance paid',
          style: TextStyle(color: _muted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        for (final e in todo) _evTile(e, showDate: true),
      ],
    ),
  );

  Widget _box({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _line),
    ),
    child: child,
  );
}

// ── Stat card (also a filter) ───────────────────────────────
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
