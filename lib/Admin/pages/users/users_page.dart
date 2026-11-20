// =============================================================
// users_page.dart — Admin: Users & Permissions (single file, live data)
//
// Reads   users (every registered account: customers + staff), live
// Writes  users/{uid}: role, active, updatedAt
//         invite -> new users/{autoId} doc (createdByAdmin: true)
//
// Roles stored in `role`: 'customer', 'Owner', 'Manager', 'Crew'
// (any other value, e.g. 'admin', is shown as-is and treated as staff).
// `active` defaults to true when the field is missing.
//
// Usage:  const UsersPage()
//
// Packages: cloud_firestore, firebase_auth, url_launcher, get
// =============================================================
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

/// Roles the admin can assign. Value is what gets stored in Firestore.
const _roles = <String, String>{
  'customer': 'Customer',
  'Owner': 'Owner',
  'Manager': 'Manager',
  'Crew': 'Crew',
};
const _inviteRoles = ['Manager', 'Crew', 'Owner'];

Color _roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'owner':
    case 'admin':
      return _navy;
    case 'manager':
      return const Color(0xFF2271B1);
    case 'crew':
      return const Color(0xFFE67E22);
    case 'customer':
      return _green;
    default:
      return _muted;
  }
}

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

String _d(DateTime d) => '${_mon[d.month - 1]} ${d.day}, ${d.year}';

String _ago(DateTime d) {
  final x = DateTime.now().difference(d);
  if (x.inMinutes < 1) return 'just now';
  if (x.inMinutes < 60) return '${x.inMinutes}m ago';
  if (x.inHours < 24) return '${x.inHours}h ago';
  if (x.inDays < 7) return '${x.inDays}d ago';
  return _d(d);
}

String _money(num v) {
  final p = v.toStringAsFixed(2).split('.');
  final i = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '\$$i.${p[1]}';
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

Widget _pill(String text, Color color, {bool small = false}) => Container(
  padding: EdgeInsets.symmetric(horizontal: small ? 9 : 12, vertical: 5),
  decoration: BoxDecoration(
    color: color.withValues(alpha: .12),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    text,
    style: TextStyle(
      color: color,
      fontWeight: FontWeight.w800,
      fontSize: small ? 11 : 12,
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

// ── Model ───────────────────────────────────────────────────
class _U {
  _U(this.id, this.m);
  final String id;
  final Map<String, dynamic> m;
  factory _U.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      _U(d.id, d.data() ?? {});

  String s(String k) => (m[k] ?? '').toString();
  String get email => s('email');
  String get phone => s('phone');
  String get address => s('address');
  String get name {
    final n = s('name').trim();
    if (n.isNotEmpty) return n;
    final fn = s('fullName').trim();
    if (fn.isNotEmpty) return fn;
    return email.isNotEmpty ? email.split('@').first : 'Unnamed';
  }

  String get role => s('role').isEmpty ? 'customer' : s('role');
  bool get isCustomer => role.toLowerCase() == 'customer';
  bool get isStaff => !isCustomer;
  bool get active => m['active'] != false;
  bool get isMe => id == FirebaseAuth.instance.currentUser?.uid;

  /// Label shown in the UI.
  String get roleLabel => _roles[role] ?? _roles[_match] ?? role;

  /// Matches stored role to a dropdown key regardless of case.
  String get _match => _roles.keys.firstWhere(
    (k) => k.toLowerCase() == role.toLowerCase(),
    orElse: () => role,
  );

  /// Dropdown value (stored key), falls back to the raw role.
  String get roleKey => _match;

  DateTime? get created => m['createdAt'] is Timestamp
      ? (m['createdAt'] as Timestamp).toDate()
      : null;
  int get jobs => _num(m['jobs']).toInt();
  double get spent => _num(m['spent']);
  bool get invited => m['createdByAdmin'] == true;

  String get initials {
    final p = name.trim().split(RegExp(r'\s+'));
    final a = p.first.isEmpty ? '?' : p.first[0];
    final b = p.length > 1 && p.last.isNotEmpty ? p.last[0] : '';
    return (a + b).toUpperCase();
  }
}

// ── Backend ─────────────────────────────────────────────────
class _Api {
  static final db = FirebaseFirestore.instance;
  static DocumentReference<Map<String, dynamic>> user(String id) =>
      db.collection('users').doc(id);

  static final Stream<List<_U>> users = db.collection('users').snapshots().map((
    s,
  ) {
    final l = s.docs.map(_U.fromDoc).toList();
    l.sort((a, b) {
      final x = a.created, y = b.created;
      if (x == null && y == null) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });
    return l;
  });

  static Future<void> setRole(_U u, String role) => user(
    u.id,
  ).update({'role': role, 'updatedAt': FieldValue.serverTimestamp()});

  static Future<void> setActive(_U u, bool v) => user(
    u.id,
  ).update({'active': v, 'updatedAt': FieldValue.serverTimestamp()});
}

/// Changes a role with confirmation + self-protection. Shared by table & dialog.
Future<void> _changeRole(BuildContext context, _U u, String role) async {
  if (role == u.roleKey) return;
  if (u.isMe) {
    _toast('You cannot change your own role', error: true);
    return;
  }
  final ok = await _confirm(
    context,
    'Change role?',
    '${u.name} will become ${_roles[role] ?? role}.',
    ok: 'Change role',
  );
  if (!ok) return;
  try {
    await _Api.setRole(u, role);
    _toast('${u.name} is now ${_roles[role] ?? role}');
  } on FirebaseException catch (e) {
    _toast(
      e.message ?? 'Could not change role. Check permissions.',
      error: true,
    );
  } catch (_) {
    _toast('Could not change role', error: true);
  }
}

/// Activates / deactivates an account with confirmation + self-protection.
Future<void> _changeActive(BuildContext context, _U u, bool v) async {
  if (u.isMe) {
    _toast('You cannot deactivate your own account', error: true);
    return;
  }
  if (!v) {
    final ok = await _confirm(
      context,
      'Deactivate user?',
      '${u.name} will be marked inactive.',
      ok: 'Deactivate',
      color: _red,
    );
    if (!ok) return;
  }
  try {
    await _Api.setActive(u, v);
    _toast(v ? '${u.name} activated' : '${u.name} deactivated');
  } on FirebaseException catch (e) {
    _toast(
      e.message ?? 'Could not update user. Check permissions.',
      error: true,
    );
  } catch (_) {
    _toast('Could not update user', error: true);
  }
}

// =============================================================
// PAGE
// =============================================================
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _filter = 'all';
  String _q = '';

  static const _filters = <String, String>{
    'all': 'All',
    'customer': 'Customers',
    'staff': 'Staff',
    'owner': 'Owner',
    'manager': 'Manager',
    'crew': 'Crew',
    'inactive': 'Inactive',
  };

  bool _match(_U u, String f) {
    switch (f) {
      case 'customer':
        return u.isCustomer;
      case 'staff':
        return u.isStaff;
      case 'owner':
      case 'manager':
      case 'crew':
        return u.role.toLowerCase() == f;
      case 'inactive':
        return !u.active;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) => PageScaffold(
    title: 'Users & Permissions',
    subtitle: 'Every registered account — manage roles and access',
    actions: [
      StreamBuilder<List<_U>>(
        stream: _Api.users,
        builder: (context, snap) => ElevatedButton.icon(
          onPressed: () => _inviteDialog(context, snap.data ?? const []),
          icon: const Icon(Icons.person_add),
          label: const Text('INVITE USER'),
        ),
      ),
    ],
    children: [
      StreamBuilder<List<_U>>(
        stream: _Api.users,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                'Could not load users. Check your permissions.\n${snap.error}',
              ),
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final all = snap.data!;
          int count(String f) => all.where((u) => _match(u, f)).length;
          final q = _q.toLowerCase();
          final list = all.where((u) {
            if (!_match(u, _filter)) return false;
            if (q.isEmpty) return true;
            return '${u.name} ${u.email} ${u.phone} ${u.address} ${u.roleLabel}'
                .toLowerCase()
                .contains(q);
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stats(count),
              const SizedBox(height: 20),
              TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: _dec(
                  null,
                  hint: 'Search name, email, phone, address or role',
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
                          label: Text('${e.value}  ${count(e.key)}'),
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
                      'No users found',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (_, b) =>
                      b.maxWidth >= 860 ? _table(list) : _cards(list),
                ),
              const SizedBox(height: 24),
              const _Matrix(),
            ],
          );
        },
      ),
    ],
  );

  // ── stat cards ──
  Widget _stats(int Function(String) count) {
    final items = <(String, String, Color, IconData)>[
      ('all', 'Total users', _navy, Icons.groups_rounded),
      ('customer', 'Customers', _green, Icons.person_rounded),
      ('staff', 'Staff', const Color(0xFF2271B1), Icons.badge_rounded),
      ('inactive', 'Inactive', _red, Icons.person_off_rounded),
    ];
    return LayoutBuilder(
      builder: (_, b) {
        final cols = b.maxWidth >= 760 ? 4 : 2;
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

  Widget _avatar(_U u, {double r = 20}) => CircleAvatar(
    radius: r,
    backgroundColor: _roleColor(u.role).withValues(alpha: u.active ? .14 : .06),
    child: Text(
      u.initials,
      style: TextStyle(
        color: u.active ? _roleColor(u.role) : _muted,
        fontWeight: FontWeight.w900,
        fontSize: r * .7,
      ),
    ),
  );

  Widget _roleDropdown(_U u) {
    final keys = [
      ..._roles.keys,
      if (!_roles.containsKey(u.roleKey)) u.roleKey,
    ];
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: u.roleKey,
        isDense: true,
        borderRadius: BorderRadius.circular(12),
        items: [
          for (final k in keys)
            DropdownMenuItem(
              value: k,
              child: Text(
                _roles[k] ?? k,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _roleColor(k),
                ),
              ),
            ),
        ],
        onChanged: u.isMe ? null : (v) => _changeRole(context, u, v!),
      ),
    );
  }

  // ── wide: table ──
  Widget _table(List<_U> list) {
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
                cell(4, const Text('User', style: head)),
                cell(2, const Text('Phone', style: head)),
                cell(2, const Text('Role', style: head)),
                cell(2, const Text('Registered', style: head)),
                cell(1, const Text('Status', style: head)),
                const SizedBox(width: 64, child: Text('Active', style: head)),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          for (var i = 0; i < list.length; i++)
            InkWell(
              onTap: () => _openUser(context, list[i].id),
              child: Container(
                color: i.isOdd ? _bg : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    cell(
                      4,
                      Row(
                        children: [
                          _avatar(list[i]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${list[i].name}${list[i].isMe ? '  (you)' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                  ),
                                ),
                                Text(
                                  list[i].email.isEmpty ? '—' : list[i].email,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    cell(
                      2,
                      Text(
                        list[i].phone.isEmpty ? '—' : list[i].phone,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    cell(
                      2,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _roleDropdown(list[i]),
                      ),
                    ),
                    cell(
                      2,
                      Text(
                        list[i].created == null ? '—' : _d(list[i].created!),
                        style: const TextStyle(color: _muted),
                      ),
                    ),
                    cell(
                      1,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _pill(
                          list[i].active ? 'Active' : 'Inactive',
                          list[i].active ? _green : _red,
                          small: true,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Switch(
                        value: list[i].active,
                        activeThumbColor: _navy,
                        onChanged: list[i].isMe
                            ? null
                            : (v) => _changeActive(context, list[i], v),
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

  // ── narrow: cards ──
  Widget _cards(List<_U> list) =>
      Column(children: [for (final u in list) _tile(u)]);

  Widget _tile(_U u) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _line),
      ),
      child: InkWell(
        onTap: () => _openUser(context, u.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _avatar(u, r: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${u.name}${u.isMe ? '  (you)' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: _ink,
                          ),
                        ),
                        Text(
                          u.email.isEmpty ? '—' : u.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: u.active,
                    activeThumbColor: _navy,
                    onChanged: u.isMe
                        ? null
                        : (v) => _changeActive(context, u, v),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _pill(u.roleLabel, _roleColor(u.role), small: true),
                  if (!u.active) _pill('Inactive', _red, small: true),
                  if (u.phone.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.call_outlined,
                          size: 14,
                          color: _muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          u.phone,
                          style: const TextStyle(color: _muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  if (u.created != null)
                    Text(
                      'Joined ${_ago(u.created!)}',
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

// =============================================================
// USER DETAIL DIALOG (live)
// =============================================================
void _openUser(BuildContext context, String id) => showDialog(
  context: context,
  builder: (_) => _UserDialog(id: id),
);

class _UserDialog extends StatelessWidget {
  const _UserDialog({required this.id});
  final String id;

  Widget _row(String k, String v, int i, {String? uri}) => Container(
    color: i.isOdd ? _bg : Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
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
  Widget build(BuildContext context) => Dialog(
    backgroundColor: _bg,
    insetPadding: const EdgeInsets.all(16),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 520,
        maxHeight: MediaQuery.of(context).size.height * .92,
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _Api.user(id).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snap.data!.exists) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Text('User not found'),
            );
          }
          final u = _U.fromDoc(snap.data!);
          final rows = <(String, String, String?)>[
            ('Email', u.email, 'mailto:${u.email}'),
            ('Phone', u.phone, 'tel:${u.phone}'),
            ('Address', u.address, null),
            ('Registered', u.created == null ? '' : _d(u.created!), null),
            ('Source', u.invited ? 'Added by admin' : 'Self registered', null),
            if (u.isCustomer) ('Jobs', '${u.jobs}', null),
            if (u.isCustomer) ('Total spent', _money(u.spent), null),
            ('User ID', u.id, null),
          ];
          final keys = [
            ..._roles.keys,
            if (!_roles.containsKey(u.roleKey)) u.roleKey,
          ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _roleColor(
                        u.role,
                      ).withValues(alpha: .14),
                      child: Text(
                        u.initials,
                        style: TextStyle(
                          color: _roleColor(u.role),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${u.name}${u.isMe ? '  (you)' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              _pill(
                                u.roleLabel,
                                _roleColor(u.role),
                                small: true,
                              ),
                              _pill(
                                u.active ? 'Active' : 'Inactive',
                                u.active ? _green : _red,
                                small: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Role',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: u.roleKey,
                        isExpanded: true,
                        decoration: _dec(null),
                        items: [
                          for (final k in keys)
                            DropdownMenuItem(
                              value: k,
                              child: Text(_roles[k] ?? k),
                            ),
                        ],
                        onChanged: u.isMe
                            ? null
                            : (v) => _changeRole(context, u, v!),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: _navy,
                        title: const Text(
                          'Account active',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          u.isMe
                              ? 'You cannot deactivate your own account'
                              : 'Inactive users are flagged in the admin panel',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                        value: u.active,
                        onChanged: u.isMe
                            ? null
                            : (v) => _changeActive(context, u, v),
                      ),
                      const SizedBox(height: 12),
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
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

// =============================================================
// INVITE / ADD USER
// =============================================================
void _inviteDialog(BuildContext context, List<_U> existing) {
  final n = TextEditingController();
  final e = TextEditingController();
  final p = TextEditingController();
  String role = 'Crew';
  bool busy = false;

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Add staff member'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: n,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('Full name', icon: Icons.person_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: e,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _dec('Email', icon: Icons.mail_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: p,
                  keyboardType: TextInputType.phone,
                  decoration: _dec(
                    'Phone (optional)',
                    icon: Icons.call_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  isExpanded: true,
                  decoration: _dec('Role'),
                  items: [
                    for (final r in _inviteRoles)
                      DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => setS(() => role = v!),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Creates the staff profile so the person can be assigned to jobs. '
                  'They sign in with the same email once their login exists.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          ElevatedButton(
            onPressed: busy
                ? null
                : () async {
                    final name = n.text.trim();
                    final email = e.text.trim().toLowerCase();
                    if (name.isEmpty) {
                      _toast('Enter a name', error: true);
                      return;
                    }
                    if (email.isEmpty || !GetUtils.isEmail(email)) {
                      _toast('Enter a valid email', error: true);
                      return;
                    }
                    if (existing.any((u) => u.email.toLowerCase() == email)) {
                      _toast(
                        'A user with this email already exists',
                        error: true,
                      );
                      return;
                    }
                    setS(() => busy = true);
                    try {
                      final doc = _Api.db.collection('users').doc();
                      await doc.set({
                        'uid': doc.id,
                        'name': name,
                        'email': email,
                        'phone': p.text.trim(),
                        'role': role,
                        'active': true,
                        'createdByAdmin': true,
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _toast('$name added as $role');
                    } on FirebaseException catch (err) {
                      _toast(
                        err.message ?? 'Could not save. Check permissions.',
                        error: true,
                      );
                      setS(() => busy = false);
                    } catch (_) {
                      _toast('Could not save user', error: true);
                      setS(() => busy = false);
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
            ),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('SAVE'),
          ),
        ],
      ),
    ),
  );
}

// =============================================================
// PERMISSION MATRIX (reference)
// =============================================================
class _Matrix extends StatelessWidget {
  const _Matrix();

  static const _modules = [
    'Customers',
    'Quotes',
    'Jobs',
    'Scheduling',
    'Invoices',
    'Payments',
    'Reports',
    'Settings',
  ];
  static const _matrix = {
    'Owner': [1, 1, 1, 1, 1, 1, 1, 1],
    'Manager': [1, 1, 1, 1, 0, 0, 0, 0],
    'Crew': [0, 0, 1, 1, 0, 0, 0, 0],
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Permission matrix',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
          color: _ink,
        ),
      ),
      const SizedBox(height: 10),
      _box(
        pad: const EdgeInsets.all(4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _navy,
            ),
            columns: [
              const DataColumn(label: Text('ROLE')),
              for (final m in _modules)
                DataColumn(
                  label: Text(
                    m.toUpperCase(),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
            rows: [
              for (final e in _matrix.entries)
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        e.key,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    for (final v in e.value)
                      DataCell(
                        Icon(
                          v == 1
                              ? Icons.check_circle
                              : Icons.remove_circle_outline,
                          color: v == 1 ? _green : _line,
                          size: 20,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'Crew members only see assigned jobs. No role except Owner can access payment or banking settings.',
        style: TextStyle(color: _muted, fontSize: 12),
      ),
    ],
  );
}
