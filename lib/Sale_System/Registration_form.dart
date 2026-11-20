// Save as: lib/Admin/pages/auth/sales_register_page.dart
import 'dart:ui';

import 'package:admin_twinhandymans_llc/Admin/widgets/widgets.dart'; // Logo()
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ── Shared constants ────────────────────────────────────────────────────────
const kSalesRepRole = 'sales_rep';

const _accent = Color(0xFF4F8CFF);
const _accent2 = Color(0xFF7C5CFF);

const _minAge = 14; // youngest allowed rep (confirm with your attorney)
const _adultAge = 18; // below this -> guardian details required
const _agreementVersion = '1.0';

/// While true, AuthGate must NOT sign the user out (registration is in progress
/// and the profile documents have not been written yet).
class RegistrationGuard {
  static bool active = false;
}

// =========================================================
// REP ACCESS (approval status) – used by register + login
// =========================================================
class RepAccess {
  final String status; // pending | approved | rejected | suspended
  final String? reason;
  const RepAccess(this.status, [this.reason]);
  bool get approved => status == 'approved';
}

Future<RepAccess> fetchRepAccess(String uid) async {
  final snap = await FirebaseFirestore.instance
      .collection('reps')
      .doc(uid)
      .get();
  if (!snap.exists) return const RepAccess('pending');
  final d = snap.data() ?? {};
  return RepAccess(
    ((d['status'] as String?) ?? 'pending').toLowerCase().trim(),
    d['rejectionReason'] as String?,
  );
}

// =========================================================
// REGISTER CONTROLLER
// =========================================================
class SalesRegisterController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final isLoading = false.obs;
  final hidePassword = true.obs;
  final agreed = false.obs;
  final dob = Rxn<DateTime>();
  final error = RxnString();

  int? get age {
    final d = dob.value;
    if (d == null) return null;
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a;
  }

  bool get isMinor => dob.value != null && (age ?? 99) < _adultAge;

  /// Lenient international phone check (GetUtils.isPhoneNumber rejects many
  /// valid numbers, e.g. 11-digit Pakistani numbers like 0300 1234567).
  bool _validPhone(String p) {
    if (!RegExp(r'^\+?[0-9\s\-\(\)]+$').hasMatch(p)) return false;
    final digits = p.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 7 && digits.length <= 15;
  }

  String _cleanPhone(String p) => p.replaceAll(RegExp(r'[\s\-\(\)]'), '');

  /// Creates the Auth account + users/{uid} + a PENDING reps/{uid} application.
  /// Returns true on success.
  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String confirm,
    required String guardianName,
    required String guardianPhone,
  }) async {
    name = name.trim();
    email = email.trim();
    phone = phone.trim();
    password = password.trim();
    guardianName = guardianName.trim();
    guardianPhone = guardianPhone.trim();
    error.value = null;

    // ---------- Validation ----------
    String? problem;
    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      problem = 'Please fill all fields.';
    } else if (!GetUtils.isEmail(email)) {
      problem = 'Please enter a valid email address.';
    } else if (!_validPhone(phone)) {
      problem = 'Please enter a valid phone number.';
    } else if (dob.value == null) {
      problem = 'Please select your date of birth.';
    } else if ((age ?? 0) < _minAge) {
      problem = 'You must be at least $_minAge years old to apply.';
    } else if (isMinor && (guardianName.isEmpty || guardianPhone.isEmpty)) {
      problem = 'Parent / guardian details are required.';
    } else if (isMinor && !_validPhone(guardianPhone)) {
      problem = 'Please enter a valid guardian phone number.';
    } else if (password.length < 6) {
      problem = 'Password must be at least 6 characters.';
    } else if (password != confirm.trim()) {
      problem = 'Passwords do not match.';
    } else if (!agreed.value) {
      problem = 'Please accept the Representative Agreement.';
    }
    if (problem != null) {
      error.value = problem;
      return false;
    }

    User? user;
    String step = 'start';
    try {
      isLoading.value = true;
      RegistrationGuard.active = true;

      // 1) Auth account
      step = 'auth.createUser';
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = cred.user!;
      await user.updateDisplayName(name);

      final uid = user.uid;
      final cleanPhone = _cleanPhone(phone);
      final lowerEmail = email.toLowerCase();

      // 2) users/{uid}  (same collection/shape as the customer app)
      //    Written FIRST and on its own so security rules that look at the
      //    user's profile also work for the reps document below.
      step = 'firestore.users.set';
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': lowerEmail,
        'phone': cleanPhone,
        'role': kSalesRepRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3) reps/{uid}  (pending application)
      step = 'firestore.reps.set';
      await _db.collection('reps').doc(uid).set({
        'uid': uid,
        'repId': null, // assigned on approval
        'name': name,
        'email': lowerEmail,
        'phone': cleanPhone,
        'role': kSalesRepRole,
        'dob': Timestamp.fromDate(dob.value!),
        'isMinor': isMinor,
        if (isMinor)
          'guardian': {
            'name': guardianName,
            'phone': _cleanPhone(guardianPhone),
          },
        'status': 'pending',
        'commissionRate': null, // admin sets (falls back to default)
        'agreementVersion': _agreementVersion,
        'agreementAcceptedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4) Sign out – rep must wait for admin approval
      step = 'auth.signOut';
      await _auth.signOut();
      return true;
    } on FirebaseAuthException catch (e, st) {
      debugPrint(
        '❌ [register:$step] AUTH ERROR code=${e.code} msg=${e.message}',
      );
      debugPrint('$st');
      if (step != 'auth.createUser') await _rollback(user);
      error.value = _message(e.code);
      return false;
    } on FirebaseException catch (e, st) {
      // Firestore errors (permission-denied, unavailable, ...)
      debugPrint(
        '❌ [register:$step] FIRESTORE ERROR plugin=${e.plugin} code=${e.code} msg=${e.message}',
      );
      debugPrint('$st');
      await _rollback(user);
      error.value = e.code == 'permission-denied'
          ? 'Could not submit your application (permission denied). '
                'Please contact Twins Handyman LLC.'
          : 'Could not submit your application. Please try again.';
      if (kDebugMode) error.value = '[$step] ${e.code}: ${e.message}';
      return false;
    } catch (e, st) {
      debugPrint('❌ [register:$step] ERROR: $e');
      debugPrint('$st');
      await _rollback(user);
      error.value = 'Could not submit your application. Please try again.';
      if (kDebugMode) error.value = '[$step] $e';
      return false;
    } finally {
      RegistrationGuard.active = false;
      isLoading.value = false;
    }
  }

  /// Removes a half-created account (and profile docs) so the person can retry
  /// with the same email instead of getting "email already in use".
  Future<void> _rollback(User? user) async {
    if (user == null) return;
    final uid = user.uid;
    try {
      await _db.collection('reps').doc(uid).delete();
    } catch (_) {}
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (_) {}
    try {
      await user.delete();
    } catch (e) {
      debugPrint('⚠️ Could not delete half-created user: $e');
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }

  String _message(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-up is disabled in Firebase.';
      default:
        return 'Registration failed ($code).';
    }
  }
}

// =========================================================
// REGISTER PAGE
// =========================================================
class SalesRegisterPage extends StatefulWidget {
  const SalesRegisterPage({super.key});

  @override
  State<SalesRegisterPage> createState() => _SalesRegisterPageState();
}

class _SalesRegisterPageState extends State<SalesRegisterPage> {
  late final SalesRegisterController c;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _gName = TextEditingController();
  final _gPhone = TextEditingController();

  @override
  void initState() {
    super.initState();
    Get.delete<SalesRegisterController>(force: true);
    c = Get.put(SalesRegisterController());
  }

  @override
  void dispose() {
    for (final t in [
      _name,
      _email,
      _phone,
      _password,
      _confirm,
      _gName,
      _gPhone,
    ]) {
      t.dispose();
    }
    Get.delete<SalesRegisterController>(force: true);
    super.dispose();
  }

  Future<void> _submit() async {
    if (c.isLoading.value) return; // prevent double submit
    FocusScope.of(context).unfocus();
    final ok = await c.register(
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
      password: _password.text,
      confirm: _confirm.text,
      guardianName: _gName.text,
      guardianPhone: _gPhone.text,
    );
    if (!ok || !mounted) return;
    await showApprovalDialog(context, 'submitted');
    if (mounted && Navigator.of(context).canPop()) Get.back();
  }

  Future<void> _pickDob() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: c.dob.value ?? DateTime(now.year - 16, now.month, now.day),
      firstDate: DateTime(now.year - 80),
      lastDate: now,
      helpText: 'Date of birth',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            onPrimary: Colors.white,
            surface: Color(0xFF0E1F46),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) c.dob.value = picked;
  }

  String _fmt(DateTime d) {
    const m = [
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
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 520;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _AuthBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(compact ? 14 : 32),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - t)),
                      child: child,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: GlassPanel(
                      radius: 28,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 20 : 36,
                          vertical: compact ? 26 : 38,
                        ),
                        // LayoutBuilder outside, Obx inside (so Rx reads are tracked)
                        child: LayoutBuilder(
                          builder: (context, box) =>
                              Obx(() => _form(box.maxWidth, compact)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Two fields side by side when there is room, stacked otherwise.
  Widget _pair(bool two, Widget a, Widget b) => two
      ? Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ],
        )
      : Column(children: [a, const SizedBox(height: 14), b]);

  Widget _form(double innerWidth, bool compact) {
    final loading = c.isLoading.value;
    final two = innerWidth >= 460;
    final minor = c.isMinor;

    final nameF = TextField(
      controller: _name,
      enabled: !loading,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      keyboardType: TextInputType.name,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: _glassField('Full name', Icons.person_outline),
    );
    final emailF = TextField(
      controller: _email,
      enabled: !loading,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.email],
      decoration: _glassField('Email', Icons.mail_outline),
    );
    final phoneF = TextField(
      controller: _phone,
      enabled: !loading,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: _glassField('Phone', Icons.call_outlined),
    );
    final dobF = GestureDetector(
      onTap: loading ? null : _pickDob,
      behavior: HitTestBehavior.opaque,
      child: InputDecorator(
        isEmpty: c.dob.value == null,
        decoration: _glassField(
          'Date of birth',
          Icons.cake_outlined,
          suffix: const Icon(
            Icons.calendar_month_outlined,
            color: Colors.white70,
          ),
        ),
        child: Text(
          c.dob.value == null ? '' : _fmt(c.dob.value!),
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
    final passF = TextField(
      controller: _password,
      enabled: !loading,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      obscureText: c.hidePassword.value,
      textInputAction: TextInputAction.next,
      decoration: _glassField(
        'Password',
        Icons.lock_outline,
        suffix: IconButton(
          onPressed: c.hidePassword.toggle,
          icon: Icon(
            c.hidePassword.value
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.white70,
          ),
        ),
      ),
    );
    final confirmF = TextField(
      controller: _confirm,
      enabled: !loading,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      obscureText: c.hidePassword.value,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: _glassField('Confirm password', Icons.lock_reset_outlined),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Logo(),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Sales rep sign up',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 26 : 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Apply for an account. An admin reviews every application before you can sign in.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 26),

        _pair(two, nameF, emailF),
        const SizedBox(height: 14),
        _pair(two, phoneF, dobF),

        // Guardian details (only under 18)
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: minor
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 10),
                        child: Text(
                          'You are under 18. A parent or guardian must be listed.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      _pair(
                        two,
                        TextField(
                          controller: _gName,
                          enabled: !loading,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          decoration: _glassField(
                            'Guardian name',
                            Icons.family_restroom_outlined,
                          ),
                        ),
                        TextField(
                          controller: _gPhone,
                          enabled: !loading,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: _glassField(
                            'Guardian phone',
                            Icons.phone_in_talk_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 14),
        _pair(two, passF, confirmF),
        const SizedBox(height: 10),

        // Agreement
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: loading ? null : c.agreed.toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Checkbox(
                    value: c.agreed.value,
                    onChanged: loading ? null : (_) => c.agreed.toggle(),
                    activeColor: _accent,
                    checkColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.6)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'I agree to the Representative Agreement and understand '
                      'commission is paid on payments the customer has made.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Error
        if (c.error.value != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    c.error.value!,
                    style: const TextStyle(
                      color: Color(0xFFFFB4B4),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        _GradientButton(
          label: 'SUBMIT APPLICATION',
          loading: loading,
          onTap: _submit,
        ),
        const SizedBox(height: 16),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Already applied? ',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: loading
                      ? null
                      : () {
                          if (Navigator.of(context).canPop()) Get.back();
                        },
                  child: const Text(
                    'Sign in',
                    style: TextStyle(
                      color: Color(0xFF9DBEFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF9DBEFF),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =========================================================
// APPROVAL DIALOG (glass) – status: pending | rejected | suspended | submitted
// =========================================================
Future<void> showApprovalDialog(
  BuildContext context,
  String status, {
  String? reason,
}) {
  IconData icon;
  Color color;
  String title;
  String message;

  switch (status) {
    case 'submitted':
      icon = Icons.check_circle_outline;
      color = const Color(0xFF34D399);
      title = 'Application submitted';
      message =
          'An admin will review your application. You can sign in once it has been approved.';
      break;
    case 'rejected':
      icon = Icons.cancel_outlined;
      color = const Color(0xFFFF6B6B);
      title = 'Application not approved';
      message =
          'Unfortunately your application was not approved. Contact Twins Handyman LLC if you have questions.';
      break;
    case 'suspended':
      icon = Icons.block;
      color = const Color(0xFFFFA24D);
      title = 'Account suspended';
      message =
          'Your account is currently suspended. Please contact Twins Handyman LLC.';
      break;
    default: // pending
      icon = Icons.hourglass_top_rounded;
      color = const Color(0xFFFFC857);
      title = 'Approval pending';
      message =
          'Your application is still under review. You can sign in as soon as an admin approves your account.';
  }

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withOpacity(0.55),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, __) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              type: MaterialType.transparency,
              child: GlassPanel(
                radius: 28,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withOpacity(0.18),
                            border: Border.all(color: color.withOpacity(0.6)),
                          ),
                          child: Icon(icon, color: color, size: 36),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      if (status == 'rejected' &&
                          reason != null &&
                          reason.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                            ),
                          ),
                          child: Text(
                            'Reason: ${reason.trim()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _GradientButton(
                        label: 'OK',
                        loading: false,
                        onTap: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// =========================================================
// SHARED GLASS BUILDING BLOCKS
// =========================================================
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.radius = 28});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.16),
              Colors.white.withOpacity(0.05),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 50,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  Widget _orb(double size, List<Color> colors) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: colors),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF070F24), Color(0xFF0E1F46), Color(0xFF1B1646)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -100,
            child: _orb(420, [_accent.withOpacity(0.55), Colors.transparent]),
          ),
          Positioned(
            bottom: -160,
            right: -120,
            child: _orb(500, [_accent2.withOpacity(0.5), Colors.transparent]),
          ),
          Positioned(
            top: 140,
            right: width * 0.18,
            child: _orb(220, [
              const Color(0xFF22D3EE).withOpacity(0.28),
              Colors.transparent,
            ]),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });
  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: loading ? 0.7 : 1,
    child: Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(colors: [_accent, _accent2]),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
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
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}

InputDecoration _glassField(String label, IconData icon, {Widget? suffix}) {
  OutlineInputBorder border(Color color, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: w),
  );
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
    floatingLabelStyle: const TextStyle(color: Colors.white),
    prefixIcon: Icon(icon, color: Colors.white70),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white.withOpacity(0.08),
    contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
    enabledBorder: border(Colors.white.withOpacity(0.18)),
    disabledBorder: border(Colors.white.withOpacity(0.10)),
    border: border(Colors.white.withOpacity(0.18)),
    focusedBorder: border(_accent, 1.6),
  );
}
