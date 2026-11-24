import 'dart:ui';
import 'package:admin_twinhandymans_llc/Admin/pages/role.dart';
import 'package:admin_twinhandymans_llc/Sale_System/Registration_form.dart';
import 'package:admin_twinhandymans_llc/Sale_System/Sale_Portal/Sale_Screen.dart';
// TODO: adjust this path to where SalesPortalPage lives in your project.
// If SalesPortalPage is already exported by Registration_form.dart, remove it.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'Admin/controllers/app_controller.dart';
import 'Admin/controllers/core/core.dart';
import 'Admin/layout/shell.dart';
import 'Admin/widgets/widgets.dart';
import 'Admin/pages/dashboard/dashboard_page.dart';

// =========================================================
// ADMIN AUTH CONTROLLER
// =========================================================
class AdminAuthController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final isLoading = false.obs;
  final hidePassword = true.obs;
  final error = RxnString();

  /// Set when a sales rep tries to enter but is not approved.
  /// LoginPage listens to this and shows the approval dialog.
  static final blocked = Rxn<RepAccess>();

  /// Staff roles + approved sales reps may enter the portal.
  static bool isAllowedRole(String? role) =>
      role != null && (kStaffRoles.contains(role) || role == kSalesRepRole);

  /// True when the role is a sales representative.
  static bool isSalesRep(String? role) => role == kSalesRepRole;

  /// Decides which screen a signed-in user should land on.
  /// sales_rep -> SalesPortalPage, everyone else -> Shell.
  static Widget homeFor(String? role) =>
      isSalesRep(role) ? const SalesPortalPage() : const Shell();

  static void notifyBlocked(RepAccess access) {
    if (blocked.value == null) blocked.value = access;
  }

  Future<String?> fetchRole(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return (snap.data()?['role'] as String?)?.toLowerCase().trim();
  }

  /// Clears anything cached from a previous user.
  static void resetSession() {
    if (Get.isRegistered<DashboardController>()) {
      Get.delete<DashboardController>(force: true);
    }
    if (Get.isRegistered<AppController>()) {
      Get.find<AppController>().page.value = 0;
    }
  }

  Future<void> signIn(String email, String password) async {
    email = email.trim();
    password = password.trim();
    error.value = null;

    if (email.isEmpty || password.isEmpty) {
      error.value = 'Please enter your email and password.';
      return;
    }
    if (!GetUtils.isEmail(email)) {
      error.value = 'Please enter a valid email address.';
      return;
    }

    try {
      isLoading.value = true;

      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user!;

      final role = await fetchRole(user.uid);
      if (!isAllowedRole(role)) {
        await _auth.signOut();
        error.value = 'This account does not have staff access.';
        return;
      }

      // ── Approval gate (sales representatives) ──
      if (isSalesRep(role)) {
        final access = await fetchRepAccess(user.uid);
        if (!access.approved) {
          await _auth.signOut();
          notifyBlocked(access);
          return;
        }
      }

      resetSession();
      RoleController.ensure().role.value = role!;

      // ── Role based navigation ──
      if (isSalesRep(role)) {
        Get.offAll(() => const SalesPortalPage());
      } else {
        Get.offAll(() => const Shell());
      }
    } on FirebaseAuthException catch (e) {
      error.value = _message(e.code);
    } on FirebaseException catch (e) {
      await _auth.signOut();
      error.value = e.code == 'permission-denied'
          ? 'You do not have permission to access the portal.'
          : 'Could not verify your account. Please try again.';
    } catch (_) {
      await _auth.signOut();
      error.value = 'Something went wrong. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resetPassword(String email) async {
    email = email.trim();
    if (!GetUtils.isEmail(email)) {
      error.value = 'Enter your email above, then tap "Forgot password?".';
      return;
    }
    try {
      isLoading.value = true;
      error.value = null;
      await _auth.sendPasswordResetEmail(email: email);
      Get.snackbar('Email sent', 'Check $email for a password reset link.');
    } on FirebaseAuthException catch (e) {
      error.value = _message(e.code);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    resetSession();
    RoleController.ensure().role.value = '';
    Get.offAll(() => const LoginPage());
  }

  String _message(String code) {
    switch (code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Sign in failed ($code).';
    }
  }
}

// =========================================================
// AUTH GATE
// =========================================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// Returns the role if the user may enter, otherwise null.
  Future<String?> _loadRole(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final role = (snap.data()?['role'] as String?)?.toLowerCase().trim();
    if (!AdminAuthController.isAllowedRole(role)) return role;

    // ── Approval gate (sales representatives) ──
    if (AdminAuthController.isSalesRep(role)) {
      final access = await fetchRepAccess(uid);
      if (!access.approved) {
        AdminAuthController.notifyBlocked(access);
        await FirebaseAuth.instance.signOut();
        return null;
      }
    }

    RoleController.ensure().role.value = role!;
    return role;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return const LoginPage();

        // A new rep is registering: profile documents are not written yet.
        if (RegistrationGuard.active) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return FutureBuilder<String?>(
          future: _loadRole(user.uid),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final role = roleSnap.data;
            if (roleSnap.hasError || !AdminAuthController.isAllowedRole(role)) {
              FirebaseAuth.instance.signOut();
              return const LoginPage();
            }

            // ── Role based home: sales_rep -> SalesPortalPage, else Shell ──
            return AdminAuthController.homeFor(role);
          },
        );
      },
    );
  }
}

// =========================================================
// LOGIN PAGE – centered glassmorphism design
// =========================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final c = Get.put(AdminAuthController());
  final _email = TextEditingController();
  final _password = TextEditingController();

  Worker? _blockedWorker;
  bool _dialogOpen = false;

  static const _accent = Color(0xFF4F8CFF);
  static const _accent2 = Color(0xFF7C5CFF);

  @override
  void initState() {
    super.initState();
    _blockedWorker = ever(AdminAuthController.blocked, (_) => _showBlocked());
    // The notice may have been set before this page was built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showBlocked());
  }

  @override
  void dispose() {
    _blockedWorker?.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Approval gate dialog (pending / rejected / suspended).
  Future<void> _showBlocked() async {
    final access = AdminAuthController.blocked.value;
    if (access == null || _dialogOpen || !mounted) return;
    _dialogOpen = true;
    AdminAuthController.blocked.value = null;
    await showApprovalDialog(context, access.status, reason: access.reason);
    _dialogOpen = false;
  }

  void _submit() => c.signIn(_email.text, _password.text);

  void _openSalesRegister() => Get.to(() => const SalesRegisterPage());

  InputDecoration _field(String label, IconData icon, {Widget? suffix}) {
    OutlineInputBorder border(Color color, [double w = 1]) =>
        OutlineInputBorder(
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
      focusedBorder: border(_accent, 1.6),
    );
  }

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
    final compact = width < 520;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF070F24),
                    Color(0xFF0E1F46),
                    Color(0xFF1B1646),
                  ],
                ),
              ),
            ),
          ),
          // Glow orbs (give the glass something to blur)
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

          // Centered glass card
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
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 20 : 36,
                            vertical: compact ? 26 : 40,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.16),
                                Colors.white.withOpacity(0.05),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.22),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 50,
                                offset: const Offset(0, 24),
                              ),
                            ],
                          ),
                          child: Obx(() => _buildForm(compact)),
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

  Widget _buildForm(bool compact) {
    final loading = c.isLoading.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Logo
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
        SizedBox(height: compact ? 22 : 26),
        Text(
          'Welcome back',
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
          'Sign in to manage your sales, leads, customers and business operations.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        SizedBox(height: compact ? 24 : 30),

        // Email
        TextField(
          controller: _email,
          enabled: !loading,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: _field('Email', Icons.mail_outline),
        ),
        const SizedBox(height: 14),

        // Password
        TextField(
          controller: _password,
          enabled: !loading,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          obscureText: c.hidePassword.value,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          decoration: _field(
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

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: loading ? null : () => c.resetPassword(_email.text),
            child: const Text(
              'Forgot password?',
              style: TextStyle(color: Color(0xFF9DBEFF)),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Sign in button
        Opacity(
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
                onTap: loading ? null : _submit,
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
                      : const Text(
                          'SIGN IN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),

        SizedBox(height: compact ? 22 : 26),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.18))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'NEW SALES TEAM MEMBER?',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.18))),
          ],
        ),
        const SizedBox(height: 10),

        // Sales representative register
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Are you a sales representative? ',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: loading ? null : _openSalesRegister,
                  child: const Text(
                    'Register here',
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
        const SizedBox(height: 18),
        Text(
          'Authorized staff only.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }
}

// import 'dart:ui';
// import 'package:admin_twinhandymans_llc/Admin/pages/role.dart';
// import 'package:admin_twinhandymans_llc/Sale_System/Registration_form.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// import 'Admin/controllers/app_controller.dart';
// import 'Admin/controllers/core/core.dart';
// import 'Admin/layout/shell.dart';
// import 'Admin/widgets/widgets.dart';
// import 'Admin/pages/dashboard/dashboard_page.dart';

// // =========================================================
// // ADMIN AUTH CONTROLLER
// // =========================================================
// class AdminAuthController extends GetxController {
//   final _auth = FirebaseAuth.instance;
//   final _db = FirebaseFirestore.instance;

//   final isLoading = false.obs;
//   final hidePassword = true.obs;
//   final error = RxnString();

//   /// Set when a sales rep tries to enter but is not approved.
//   /// LoginPage listens to this and shows the approval dialog.
//   static final blocked = Rxn<RepAccess>();

//   /// Staff roles + approved sales reps may enter the portal.
//   static bool isAllowedRole(String? role) =>
//       role != null && (kStaffRoles.contains(role) || role == kSalesRepRole);

//   static void notifyBlocked(RepAccess access) {
//     if (blocked.value == null) blocked.value = access;
//   }

//   Future<String?> fetchRole(String uid) async {
//     final snap = await _db.collection('users').doc(uid).get();
//     if (!snap.exists) return null;
//     return (snap.data()?['role'] as String?)?.toLowerCase().trim();
//   }

//   /// Clears anything cached from a previous user.
//   static void resetSession() {
//     if (Get.isRegistered<DashboardController>()) {
//       Get.delete<DashboardController>(force: true);
//     }
//     if (Get.isRegistered<AppController>()) {
//       Get.find<AppController>().page.value = 0;
//     }
//   }

//   Future<void> signIn(String email, String password) async {
//     email = email.trim();
//     password = password.trim();
//     error.value = null;

//     if (email.isEmpty || password.isEmpty) {
//       error.value = 'Please enter your email and password.';
//       return;
//     }
//     if (!GetUtils.isEmail(email)) {
//       error.value = 'Please enter a valid email address.';
//       return;
//     }

//     try {
//       isLoading.value = true;

//       final cred = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       final user = cred.user!;

//       final role = await fetchRole(user.uid);
//       if (!isAllowedRole(role)) {
//         await _auth.signOut();
//         error.value = 'This account does not have staff access.';
//         return;
//       }

//       // ── Approval gate (sales representatives) ──
//       if (role == kSalesRepRole) {
//         final access = await fetchRepAccess(user.uid);
//         if (!access.approved) {
//           await _auth.signOut();
//           notifyBlocked(access);
//           return;
//         }
//       }

//       resetSession();
//       RoleController.ensure().role.value = role!;
//       Get.offAll(() => const Shell());
//     } on FirebaseAuthException catch (e) {
//       error.value = _message(e.code);
//     } on FirebaseException catch (e) {
//       await _auth.signOut();
//       error.value = e.code == 'permission-denied'
//           ? 'You do not have permission to access the portal.'
//           : 'Could not verify your account. Please try again.';
//     } catch (_) {
//       await _auth.signOut();
//       error.value = 'Something went wrong. Please try again.';
//     } finally {
//       isLoading.value = false;
//     }
//   }

//   Future<void> resetPassword(String email) async {
//     email = email.trim();
//     if (!GetUtils.isEmail(email)) {
//       error.value = 'Enter your email above, then tap "Forgot password?".';
//       return;
//     }
//     try {
//       isLoading.value = true;
//       error.value = null;
//       await _auth.sendPasswordResetEmail(email: email);
//       Get.snackbar('Email sent', 'Check $email for a password reset link.');
//     } on FirebaseAuthException catch (e) {
//       error.value = _message(e.code);
//     } finally {
//       isLoading.value = false;
//     }
//   }

//   Future<void> signOut() async {
//     await _auth.signOut();
//     resetSession();
//     RoleController.ensure().role.value = '';
//     Get.offAll(() => const LoginPage());
//   }

//   String _message(String code) {
//     switch (code) {
//       case 'invalid-email':
//         return 'That email address is not valid.';
//       case 'user-disabled':
//         return 'This account has been disabled.';
//       case 'user-not-found':
//       case 'wrong-password':
//       case 'invalid-credential':
//         return 'Incorrect email or password.';
//       case 'too-many-requests':
//         return 'Too many attempts. Please wait a moment and try again.';
//       case 'network-request-failed':
//         return 'Network error. Check your connection.';
//       default:
//         return 'Sign in failed ($code).';
//     }
//   }
// }

// // =========================================================
// // AUTH GATE
// // =========================================================
// class AuthGate extends StatelessWidget {
//   const AuthGate({super.key});

//   /// Returns the role if the user may enter, otherwise null.
//   Future<String?> _loadRole(String uid) async {
//     final snap = await FirebaseFirestore.instance
//         .collection('users')
//         .doc(uid)
//         .get();
//     final role = (snap.data()?['role'] as String?)?.toLowerCase().trim();
//     if (!AdminAuthController.isAllowedRole(role)) return role;

//     // ── Approval gate (sales representatives) ──
//     if (role == kSalesRepRole) {
//       final access = await fetchRepAccess(uid);
//       if (!access.approved) {
//         AdminAuthController.notifyBlocked(access);
//         await FirebaseAuth.instance.signOut();
//         return null;
//       }
//     }

//     RoleController.ensure().role.value = role!;
//     return role;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snap) {
//         if (snap.connectionState == ConnectionState.waiting) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }
//         final user = snap.data;
//         if (user == null) return const LoginPage();

//         // A new rep is registering: profile documents are not written yet.
//         if (RegistrationGuard.active) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }

//         return FutureBuilder<String?>(
//           future: _loadRole(user.uid),
//           builder: (context, roleSnap) {
//             if (roleSnap.connectionState != ConnectionState.done) {
//               return const Scaffold(
//                 body: Center(child: CircularProgressIndicator()),
//               );
//             }
//             final role = roleSnap.data;
//             if (roleSnap.hasError || !AdminAuthController.isAllowedRole(role)) {
//               FirebaseAuth.instance.signOut();
//               return const LoginPage();
//             }
//             return const Shell();
//           },
//         );
//       },
//     );
//   }
// }

// // =========================================================
// // LOGIN PAGE – centered glassmorphism design
// // =========================================================
// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final c = Get.put(AdminAuthController());
//   final _email = TextEditingController();
//   final _password = TextEditingController();

//   Worker? _blockedWorker;
//   bool _dialogOpen = false;

//   static const _accent = Color(0xFF4F8CFF);
//   static const _accent2 = Color(0xFF7C5CFF);

//   @override
//   void initState() {
//     super.initState();
//     _blockedWorker = ever(AdminAuthController.blocked, (_) => _showBlocked());
//     // The notice may have been set before this page was built.
//     WidgetsBinding.instance.addPostFrameCallback((_) => _showBlocked());
//   }

//   @override
//   void dispose() {
//     _blockedWorker?.dispose();
//     _email.dispose();
//     _password.dispose();
//     super.dispose();
//   }

//   /// Approval gate dialog (pending / rejected / suspended).
//   Future<void> _showBlocked() async {
//     final access = AdminAuthController.blocked.value;
//     if (access == null || _dialogOpen || !mounted) return;
//     _dialogOpen = true;
//     AdminAuthController.blocked.value = null;
//     await showApprovalDialog(context, access.status, reason: access.reason);
//     _dialogOpen = false;
//   }

//   void _submit() => c.signIn(_email.text, _password.text);

//   void _openSalesRegister() => Get.to(() => const SalesRegisterPage());

//   InputDecoration _field(String label, IconData icon, {Widget? suffix}) {
//     OutlineInputBorder border(Color color, [double w = 1]) =>
//         OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: BorderSide(color: color, width: w),
//         );
//     return InputDecoration(
//       labelText: label,
//       labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
//       floatingLabelStyle: const TextStyle(color: Colors.white),
//       prefixIcon: Icon(icon, color: Colors.white70),
//       suffixIcon: suffix,
//       filled: true,
//       fillColor: Colors.white.withOpacity(0.08),
//       contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
//       enabledBorder: border(Colors.white.withOpacity(0.18)),
//       disabledBorder: border(Colors.white.withOpacity(0.10)),
//       focusedBorder: border(_accent, 1.6),
//     );
//   }

//   Widget _orb(double size, List<Color> colors) => Container(
//     width: size,
//     height: size,
//     decoration: BoxDecoration(
//       shape: BoxShape.circle,
//       gradient: RadialGradient(colors: colors),
//     ),
//   );

//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final compact = width < 520;

//     return Scaffold(
//       resizeToAvoidBottomInset: true,
//       body: Stack(
//         children: [
//           // Background gradient
//           Positioned.fill(
//             child: Container(
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                   colors: [
//                     Color(0xFF070F24),
//                     Color(0xFF0E1F46),
//                     Color(0xFF1B1646),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           // Glow orbs (give the glass something to blur)
//           Positioned(
//             top: -120,
//             left: -100,
//             child: _orb(420, [_accent.withOpacity(0.55), Colors.transparent]),
//           ),
//           Positioned(
//             bottom: -160,
//             right: -120,
//             child: _orb(500, [_accent2.withOpacity(0.5), Colors.transparent]),
//           ),
//           Positioned(
//             top: 140,
//             right: width * 0.18,
//             child: _orb(220, [
//               const Color(0xFF22D3EE).withOpacity(0.28),
//               Colors.transparent,
//             ]),
//           ),

//           // Centered glass card
//           SafeArea(
//             child: Center(
//               child: SingleChildScrollView(
//                 padding: EdgeInsets.all(compact ? 14 : 32),
//                 child: TweenAnimationBuilder<double>(
//                   tween: Tween(begin: 0, end: 1),
//                   duration: const Duration(milliseconds: 700),
//                   curve: Curves.easeOutCubic,
//                   builder: (context, t, child) => Opacity(
//                     opacity: t,
//                     child: Transform.translate(
//                       offset: Offset(0, 24 * (1 - t)),
//                       child: child,
//                     ),
//                   ),
//                   child: ConstrainedBox(
//                     constraints: const BoxConstraints(maxWidth: 440),
//                     child: ClipRRect(
//                       borderRadius: BorderRadius.circular(28),
//                       child: BackdropFilter(
//                         filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
//                         child: Container(
//                           padding: EdgeInsets.symmetric(
//                             horizontal: compact ? 20 : 36,
//                             vertical: compact ? 26 : 40,
//                           ),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(28),
//                             gradient: LinearGradient(
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                               colors: [
//                                 Colors.white.withOpacity(0.16),
//                                 Colors.white.withOpacity(0.05),
//                               ],
//                             ),
//                             border: Border.all(
//                               color: Colors.white.withOpacity(0.22),
//                             ),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(0.35),
//                                 blurRadius: 50,
//                                 offset: const Offset(0, 24),
//                               ),
//                             ],
//                           ),
//                           child: Obx(() => _buildForm(compact)),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildForm(bool compact) {
//     final loading = c.isLoading.value;

//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         // Logo
//         Center(
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.25),
//                   blurRadius: 20,
//                   offset: const Offset(0, 8),
//                 ),
//               ],
//             ),
//             child: const Logo(),
//           ),
//         ),
//         SizedBox(height: compact ? 22 : 26),
//         Text(
//           'Welcome back',
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             fontSize: compact ? 26 : 30,
//             fontWeight: FontWeight.w800,
//             color: Colors.white,
//             letterSpacing: -0.5,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           'Sign in to manage your sales, leads, customers and business operations.',
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             color: Colors.white.withOpacity(0.7),
//             fontSize: 14,
//             height: 1.4,
//           ),
//         ),
//         SizedBox(height: compact ? 24 : 30),

//         // Email
//         TextField(
//           controller: _email,
//           enabled: !loading,
//           style: const TextStyle(color: Colors.white),
//           cursorColor: Colors.white,
//           keyboardType: TextInputType.emailAddress,
//           textInputAction: TextInputAction.next,
//           autofillHints: const [AutofillHints.email],
//           decoration: _field('Email', Icons.mail_outline),
//         ),
//         const SizedBox(height: 14),

//         // Password
//         TextField(
//           controller: _password,
//           enabled: !loading,
//           style: const TextStyle(color: Colors.white),
//           cursorColor: Colors.white,
//           obscureText: c.hidePassword.value,
//           textInputAction: TextInputAction.done,
//           autofillHints: const [AutofillHints.password],
//           onSubmitted: (_) => _submit(),
//           decoration: _field(
//             'Password',
//             Icons.lock_outline,
//             suffix: IconButton(
//               onPressed: c.hidePassword.toggle,
//               icon: Icon(
//                 c.hidePassword.value
//                     ? Icons.visibility_off_outlined
//                     : Icons.visibility_outlined,
//                 color: Colors.white70,
//               ),
//             ),
//           ),
//         ),

//         // Error
//         if (c.error.value != null) ...[
//           const SizedBox(height: 14),
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.red.withOpacity(0.15),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
//             ),
//             child: Row(
//               children: [
//                 const Icon(
//                   Icons.error_outline,
//                   color: Colors.redAccent,
//                   size: 18,
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     c.error.value!,
//                     style: const TextStyle(
//                       color: Color(0xFFFFB4B4),
//                       fontSize: 13,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],

//         Align(
//           alignment: Alignment.centerRight,
//           child: TextButton(
//             onPressed: loading ? null : () => c.resetPassword(_email.text),
//             child: const Text(
//               'Forgot password?',
//               style: TextStyle(color: Color(0xFF9DBEFF)),
//             ),
//           ),
//         ),
//         const SizedBox(height: 6),

//         // Sign in button
//         Opacity(
//           opacity: loading ? 0.7 : 1,
//           child: Container(
//             height: 54,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(14),
//               gradient: const LinearGradient(colors: [_accent, _accent2]),
//               boxShadow: [
//                 BoxShadow(
//                   color: _accent.withOpacity(0.45),
//                   blurRadius: 24,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(14),
//                 onTap: loading ? null : _submit,
//                 child: Center(
//                   child: loading
//                       ? const SizedBox(
//                           width: 22,
//                           height: 22,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2.5,
//                             color: Colors.white,
//                           ),
//                         )
//                       : const Text(
//                           'SIGN IN',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.w800,
//                             letterSpacing: 1.4,
//                           ),
//                         ),
//                 ),
//               ),
//             ),
//           ),
//         ),

//         SizedBox(height: compact ? 22 : 26),
//         Row(
//           children: [
//             Expanded(child: Divider(color: Colors.white.withOpacity(0.18))),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 12),
//               child: Text(
//                 'NEW SALES TEAM MEMBER?',
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(0.5),
//                   fontSize: 10.5,
//                   letterSpacing: 1.2,
//                 ),
//               ),
//             ),
//             Expanded(child: Divider(color: Colors.white.withOpacity(0.18))),
//           ],
//         ),
//         const SizedBox(height: 10),

//         // Sales representative register
//         Center(
//           child: Wrap(
//             alignment: WrapAlignment.center,
//             crossAxisAlignment: WrapCrossAlignment.center,
//             children: [
//               Text(
//                 'Are you a sales representative? ',
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(0.7),
//                   fontSize: 13,
//                 ),
//               ),
//               MouseRegion(
//                 cursor: SystemMouseCursors.click,
//                 child: GestureDetector(
//                   onTap: loading ? null : _openSalesRegister,
//                   child: const Text(
//                     'Register here',
//                     style: TextStyle(
//                       color: Color(0xFF9DBEFF),
//                       fontSize: 13,
//                       fontWeight: FontWeight.w700,
//                       decoration: TextDecoration.underline,
//                       decorationColor: Color(0xFF9DBEFF),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 18),
//         Text(
//           'Authorized staff only.',
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             color: Colors.white.withOpacity(0.4),
//             fontSize: 11.5,
//           ),
//         ),
//       ],
//     );
//   }
// }

// import 'dart:ui';

// import 'package:admin_twinhandymans_llc/Admin/pages/role.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// import 'Admin/controllers/app_controller.dart';
// import 'Admin/controllers/core/core.dart';
// import 'Admin/layout/shell.dart';
// import 'Admin/widgets/widgets.dart';
// import 'Admin/pages/dashboard/dashboard_page.dart';
// // TODO: import your separate sales representative register page here, e.g.
// // import 'Admin/pages/auth/sales_register_page.dart';

// // =========================================================
// // ADMIN AUTH CONTROLLER  (unchanged)
// // =========================================================
// class AdminAuthController extends GetxController {
//   final _auth = FirebaseAuth.instance;
//   final _db = FirebaseFirestore.instance;

//   final isLoading = false.obs;
//   final hidePassword = true.obs;
//   final error = RxnString();

//   Future<String?> fetchRole(String uid) async {
//     final snap = await _db.collection('users').doc(uid).get();
//     if (!snap.exists) return null;
//     return (snap.data()?['role'] as String?)?.toLowerCase().trim();
//   }

//   /// Clears anything cached from a previous user.
//   static void resetSession() {
//     if (Get.isRegistered<DashboardController>()) {
//       Get.delete<DashboardController>(force: true);
//     }
//     if (Get.isRegistered<AppController>()) {
//       Get.find<AppController>().page.value = 0;
//     }
//   }

//   Future<void> signIn(String email, String password) async {
//     email = email.trim();
//     password = password.trim();
//     error.value = null;

//     if (email.isEmpty || password.isEmpty) {
//       error.value = 'Please enter your email and password.';
//       return;
//     }
//     if (!GetUtils.isEmail(email)) {
//       error.value = 'Please enter a valid email address.';
//       return;
//     }

//     try {
//       isLoading.value = true;

//       final cred = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       final user = cred.user!;

//       final role = await fetchRole(user.uid);
//       if (role == null || !kStaffRoles.contains(role)) {
//         await _auth.signOut();
//         error.value = 'This account does not have staff access.';
//         return;
//       }

//       resetSession();
//       RoleController.ensure().role.value = role;
//       Get.offAll(() => const Shell());
//     } on FirebaseAuthException catch (e) {
//       error.value = _message(e.code);
//     } on FirebaseException catch (e) {
//       await _auth.signOut();
//       error.value = e.code == 'permission-denied'
//           ? 'You do not have permission to access the portal.'
//           : 'Could not verify your account. Please try again.';
//     } catch (_) {
//       await _auth.signOut();
//       error.value = 'Something went wrong. Please try again.';
//     } finally {
//       isLoading.value = false;
//     }
//   }

//   Future<void> resetPassword(String email) async {
//     email = email.trim();
//     if (!GetUtils.isEmail(email)) {
//       error.value = 'Enter your email above, then tap "Forgot password?".';
//       return;
//     }
//     try {
//       isLoading.value = true;
//       error.value = null;
//       await _auth.sendPasswordResetEmail(email: email);
//       Get.snackbar('Email sent', 'Check $email for a password reset link.');
//     } on FirebaseAuthException catch (e) {
//       error.value = _message(e.code);
//     } finally {
//       isLoading.value = false;
//     }
//   }

//   Future<void> signOut() async {
//     await _auth.signOut();
//     resetSession();
//     RoleController.ensure().role.value = '';
//     Get.offAll(() => const LoginPage());
//   }

//   String _message(String code) {
//     switch (code) {
//       case 'invalid-email':
//         return 'That email address is not valid.';
//       case 'user-disabled':
//         return 'This account has been disabled.';
//       case 'user-not-found':
//       case 'wrong-password':
//       case 'invalid-credential':
//         return 'Incorrect email or password.';
//       case 'too-many-requests':
//         return 'Too many attempts. Please wait a moment and try again.';
//       case 'network-request-failed':
//         return 'Network error. Check your connection.';
//       default:
//         return 'Sign in failed ($code).';
//     }
//   }
// }

// // =========================================================
// // AUTH GATE (unchanged)
// // =========================================================
// class AuthGate extends StatelessWidget {
//   const AuthGate({super.key});

//   Future<String?> _loadRole(String uid) async {
//     final snap = await FirebaseFirestore.instance
//         .collection('users')
//         .doc(uid)
//         .get();
//     final role = (snap.data()?['role'] as String?)?.toLowerCase().trim();
//     if (role != null && kStaffRoles.contains(role)) {
//       RoleController.ensure().role.value = role;
//     }
//     return role;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snap) {
//         if (snap.connectionState == ConnectionState.waiting) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }
//         final user = snap.data;
//         if (user == null) return const LoginPage();

//         return FutureBuilder<String?>(
//           future: _loadRole(user.uid),
//           builder: (context, roleSnap) {
//             if (roleSnap.connectionState != ConnectionState.done) {
//               return const Scaffold(
//                 body: Center(child: CircularProgressIndicator()),
//               );
//             }
//             final role = roleSnap.data;
//             if (roleSnap.hasError ||
//                 role == null ||
//                 !kStaffRoles.contains(role)) {
//               FirebaseAuth.instance.signOut();
//               return const LoginPage();
//             }
//             return const Shell();
//           },
//         );
//       },
//     );
//   }
// }

// // =========================================================
// // LOGIN PAGE – centered glassmorphism design
// // =========================================================
// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final c = Get.put(AdminAuthController());
//   final _email = TextEditingController();
//   final _password = TextEditingController();

//   static const _accent = Color(0xFF4F8CFF);
//   static const _accent2 = Color(0xFF7C5CFF);

//   @override
//   void dispose() {
//     _email.dispose();
//     _password.dispose();
//     super.dispose();
//   }

//   void _submit() => c.signIn(_email.text, _password.text);

//   void _openSalesRegister() {
//     // TODO: replace with your real sales-rep register page / route.
//     // Get.to(() => const SalesRegisterPage());
//     // or: Get.toNamed('/sales-register');
//   }

//   InputDecoration _field(String label, IconData icon, {Widget? suffix}) {
//     OutlineInputBorder border(Color color, [double w = 1]) =>
//         OutlineInputBorder(
//           borderRadius: BorderRadius.circular(14),
//           borderSide: BorderSide(color: color, width: w),
//         );
//     return InputDecoration(
//       labelText: label,
//       labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
//       floatingLabelStyle: const TextStyle(color: Colors.white),
//       prefixIcon: Icon(icon, color: Colors.white70),
//       suffixIcon: suffix,
//       filled: true,
//       fillColor: Colors.white.withOpacity(0.08),
//       contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
//       enabledBorder: border(Colors.white.withOpacity(0.18)),
//       disabledBorder: border(Colors.white.withOpacity(0.10)),
//       focusedBorder: border(_accent, 1.6),
//     );
//   }

//   Widget _orb(double size, List<Color> colors) => Container(
//     width: size,
//     height: size,
//     decoration: BoxDecoration(
//       shape: BoxShape.circle,
//       gradient: RadialGradient(colors: colors),
//     ),
//   );

//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final compact = width < 520;

//     return Scaffold(
//       body: Stack(
//         children: [
//           // Background gradient
//           Positioned.fill(
//             child: Container(
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                   colors: [
//                     Color(0xFF070F24),
//                     Color(0xFF0E1F46),
//                     Color(0xFF1B1646),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           // Glow orbs (give the glass something to blur)
//           Positioned(
//             top: -120,
//             left: -100,
//             child: _orb(420, [_accent.withOpacity(0.55), Colors.transparent]),
//           ),
//           Positioned(
//             bottom: -160,
//             right: -120,
//             child: _orb(500, [_accent2.withOpacity(0.5), Colors.transparent]),
//           ),
//           Positioned(
//             top: 140,
//             right: width * 0.18,
//             child: _orb(220, [
//               const Color(0xFF22D3EE).withOpacity(0.28),
//               Colors.transparent,
//             ]),
//           ),

//           // Centered glass card
//           Center(
//             child: SingleChildScrollView(
//               padding: EdgeInsets.all(compact ? 16 : 32),
//               child: TweenAnimationBuilder<double>(
//                 tween: Tween(begin: 0, end: 1),
//                 duration: const Duration(milliseconds: 700),
//                 curve: Curves.easeOutCubic,
//                 builder: (context, t, child) => Opacity(
//                   opacity: t,
//                   child: Transform.translate(
//                     offset: Offset(0, 24 * (1 - t)),
//                     child: child,
//                   ),
//                 ),
//                 child: ConstrainedBox(
//                   constraints: const BoxConstraints(maxWidth: 440),
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(28),
//                     child: BackdropFilter(
//                       filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
//                       child: Container(
//                         padding: EdgeInsets.symmetric(
//                           horizontal: compact ? 22 : 36,
//                           vertical: compact ? 28 : 40,
//                         ),
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(28),
//                           gradient: LinearGradient(
//                             begin: Alignment.topLeft,
//                             end: Alignment.bottomRight,
//                             colors: [
//                               Colors.white.withOpacity(0.16),
//                               Colors.white.withOpacity(0.05),
//                             ],
//                           ),
//                           border: Border.all(
//                             color: Colors.white.withOpacity(0.22),
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.35),
//                               blurRadius: 50,
//                               offset: const Offset(0, 24),
//                             ),
//                           ],
//                         ),
//                         child: Obx(() => _buildForm()),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildForm() {
//     final loading = c.isLoading.value;

//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         // Logo
//         Center(
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.25),
//                   blurRadius: 20,
//                   offset: const Offset(0, 8),
//                 ),
//               ],
//             ),
//             child: const Logo(),
//           ),
//         ),
//         const SizedBox(height: 26),
//         const Text(
//           'Welcome back',
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             fontSize: 30,
//             fontWeight: FontWeight.w800,
//             color: Colors.white,
//             letterSpacing: -0.5,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           'Sign in to manage your sales, leads, customers and business operations.',
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             color: Colors.white.withOpacity(0.7),
//             fontSize: 14,
//             height: 1.4,
//           ),
//         ),
//         const SizedBox(height: 30),

//         // Email
//         TextField(
//           controller: _email,
//           enabled: !loading,
//           style: const TextStyle(color: Colors.white),
//           cursorColor: Colors.white,
//           keyboardType: TextInputType.emailAddress,
//           textInputAction: TextInputAction.next,
//           autofillHints: const [AutofillHints.email],
//           decoration: _field('Email', Icons.mail_outline),
//         ),
//         const SizedBox(height: 14),

//         // Password
//         TextField(
//           controller: _password,
//           enabled: !loading,
//           style: const TextStyle(color: Colors.white),
//           cursorColor: Colors.white,
//           obscureText: c.hidePassword.value,
//           textInputAction: TextInputAction.done,
//           autofillHints: const [AutofillHints.password],
//           onSubmitted: (_) => _submit(),
//           decoration: _field(
//             'Password',
//             Icons.lock_outline,
//             suffix: IconButton(
//               onPressed: c.hidePassword.toggle,
//               icon: Icon(
//                 c.hidePassword.value
//                     ? Icons.visibility_off_outlined
//                     : Icons.visibility_outlined,
//                 color: Colors.white70,
//               ),
//             ),
//           ),
//         ),

//         // Error
//         if (c.error.value != null) ...[
//           const SizedBox(height: 14),
//           Container(
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.red.withOpacity(0.15),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
//             ),
//             child: Row(
//               children: [
//                 const Icon(
//                   Icons.error_outline,
//                   color: Colors.redAccent,
//                   size: 18,
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     c.error.value!,
//                     style: const TextStyle(
//                       color: Color(0xFFFFB4B4),
//                       fontSize: 13,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],

//         Align(
//           alignment: Alignment.centerRight,
//           child: TextButton(
//             onPressed: loading ? null : () => c.resetPassword(_email.text),
//             child: const Text(
//               'Forgot password?',
//               style: TextStyle(color: Color(0xFF9DBEFF)),
//             ),
//           ),
//         ),
//         const SizedBox(height: 6),

//         // Sign in button
//         Opacity(
//           opacity: loading ? 0.7 : 1,
//           child: Container(
//             height: 54,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(14),
//               gradient: const LinearGradient(colors: [_accent, _accent2]),
//               boxShadow: [
//                 BoxShadow(
//                   color: _accent.withOpacity(0.45),
//                   blurRadius: 24,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 borderRadius: BorderRadius.circular(14),
//                 onTap: loading ? null : _submit,
//                 child: Center(
//                   child: loading
//                       ? const SizedBox(
//                           width: 22,
//                           height: 22,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2.5,
//                             color: Colors.white,
//                           ),
//                         )
//                       : const Text(
//                           'SIGN IN',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontWeight: FontWeight.w800,
//                             letterSpacing: 1.4,
//                           ),
//                         ),
//                 ),
//               ),
//             ),
//           ),
//         ),

//         const SizedBox(height: 26),
//         Row(
//           children: [
//             Expanded(child: Divider(color: Colors.white.withOpacity(0.18))),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 12),
//               child: Text(
//                 'NEW SALES TEAM MEMBER?',
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(0.5),
//                   fontSize: 10.5,
//                   letterSpacing: 1.2,
//                 ),
//               ),
//             ),
//             Expanded(child: Divider(color: Colors.white.withOpacity(0.18))),
//           ],
//         ),
//         const SizedBox(height: 10),

//         // Sales representative register text
//         Center(
//           child: Wrap(
//             alignment: WrapAlignment.center,
//             crossAxisAlignment: WrapCrossAlignment.center,
//             children: [
//               Text(
//                 'Are you a sales representative? ',
//                 style: TextStyle(
//                   color: Colors.white.withOpacity(0.7),
//                   fontSize: 13,
//                 ),
//               ),
//               MouseRegion(
//                 cursor: SystemMouseCursors.click,
//                 child: GestureDetector(
//                   onTap: loading ? null : _openSalesRegister,
//                   child: const Text(
//                     'Register here',
//                     style: TextStyle(
//                       color: Color(0xFF9DBEFF),
//                       fontSize: 13,
//                       fontWeight: FontWeight.w700,
//                       decoration: TextDecoration.underline,
//                       decorationColor: Color(0xFF9DBEFF),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 18),
//         Text(
//           'Authorized staff only.',
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             color: Colors.white.withOpacity(0.4),
//             fontSize: 11.5,
//           ),
//         ),
//       ],
//     );
//   }
// }
