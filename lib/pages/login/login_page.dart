import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/core.dart';
import '../../layout/shell.dart';
import '../../widgets/widgets.dart';

/// Roles allowed into the admin portal (crew/customer are blocked).
const kAdminRoles = {'owner', 'admin', 'manager'};

// =========================================================
// ADMIN AUTH CONTROLLER
// =========================================================
class AdminAuthController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final isLoading = false.obs;
  final hidePassword = true.obs;
  final error = RxnString();

  /// Reads users/{uid}.role. Returns null if profile missing.
  Future<String?> fetchRole(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return (snap.data()?['role'] as String?)?.toLowerCase();
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

      // 1) Firebase Auth
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user!;

      // 2) Role check in Firestore (users/{uid})
      final role = await fetchRole(user.uid);
      if (role == null || !kAdminRoles.contains(role)) {
        await _auth.signOut();
        error.value = 'This account does not have admin access.';
        return;
      }

      // 3) Success
      Get.offAll(() => const Shell());
    } on FirebaseAuthException catch (e) {
      error.value = _message(e.code);
    } on FirebaseException catch (e) {
      await _auth.signOut();
      error.value = e.code == 'permission-denied'
          ? 'You do not have permission to access the admin portal.'
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
// AUTH GATE – use as `home:` so refresh/reopen keeps admin
// signed in, and non-admins always land on LoginPage.
// =========================================================
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

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

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final role = (roleSnap.data?.data()?['role'] as String?)
                ?.toLowerCase();
            if (roleSnap.hasError ||
                role == null ||
                !kAdminRoles.contains(role)) {
              FirebaseAuth.instance.signOut();
              return const LoginPage();
            }
            return const Shell();
          },
        );
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final c = Get.put(AdminAuthController());
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => c.signIn(_email.text, _password.text);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!wide) ...[const Logo(), const SizedBox(height: 28)],
                const Text(
                  'Admin Sign In',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: C.navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Manage quotes, jobs, payments and customers.',
                  style: TextStyle(color: C.muted),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _email,
                  enabled: !c.isLoading.value,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  enabled: !c.isLoading.value,
                  obscureText: c.hidePassword.value,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: c.hidePassword.toggle,
                      icon: Icon(
                        c.hidePassword.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                ),
                if (c.error.value != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    c.error.value!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: c.isLoading.value
                        ? null
                        : () => c.resetPassword(_email.text),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: c.isLoading.value ? null : _submit,
                    child: c.isLoading.value
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('SIGN IN'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Authorized staff only. Owner and manager accounts are created by the business owner.',
                  style: TextStyle(color: C.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: wide
          ? Row(
              children: [
                Expanded(
                  child: Container(
                    color: C.navy,
                    padding: const EdgeInsets.all(56),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SizedBox(height: 40),
                        Text(
                          'Run your contracting\nbusiness from one place.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Quotes • Jobs • Scheduling • Invoices • Payments • Reviews',
                          style: TextStyle(
                            color: Color(0xFFB8C4D6),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: form),
              ],
            )
          : form,
    );
  }
}
