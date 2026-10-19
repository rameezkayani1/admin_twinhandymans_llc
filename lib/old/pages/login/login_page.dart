import 'package:admin_twinhandymans_llc/layout/shell.dart';
// import 'package:admin_twinhandymans_llc/pages/customers/customers_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme.dart';

// =========================================================
// ROLES  (users/{uid}.role in Firestore)
// New registrations are 'customer'. Change the field in Firebase
// to owner / manager / crew to allow admin portal login.
// =========================================================
const portalRoles = ['owner', 'manager', 'crew'];

// =========================================================
// LOGIN CONTROLLER  (logic only; text controllers live in the page)
// =========================================================
class LoginController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final isLoading = false.obs;
  final hidePassword = true.obs;

  /// Used by main(): decides the first screen on app start.
  static Future<Widget> startPage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginView();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final role = (doc.data()?['role'] ?? 'customer') as String;
      if (portalRoles.contains(role)) return const Shell();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    return const LoginView();
  }

  Future<void> login({required String email, required String password}) async {
    email = email.trim();
    password = password.trim();

    // ---------- Validation ----------
    if (email.isEmpty || password.isEmpty) {
      return _error('Please enter email and password');
    }
    if (!GetUtils.isEmail(email)) {
      return _error('Please enter a valid email address');
    }

    try {
      isLoading.value = true;

      // 1) Firebase Auth sign in
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2) Read role from Firestore users/{uid}
      final doc = await _db.collection('users').doc(cred.user!.uid).get();
      final role = (doc.data()?['role'] ?? 'customer') as String;

      // 3) Only owner / manager / crew can enter the admin portal
      if (!portalRoles.contains(role)) {
        await _auth.signOut();
        return _error('Access denied. This account is not an admin account.');
      }

      Get.offAll(() => const Shell());
    } on FirebaseAuthException catch (e) {
      _error(_authMessage(e.code));
    } catch (_) {
      _error('Something went wrong. Please try again.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> forgotPassword(String email) async {
    email = email.trim();
    if (!GetUtils.isEmail(email)) {
      return _error('Enter your email first, then tap Forgot password');
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      Get.snackbar('Email sent', 'Check your inbox to reset your password.');
    } on FirebaseAuthException catch (e) {
      _error(_authMessage(e.code));
    }
  }

  void _error(String msg) => Get.snackbar('Error', msg);

  String _authMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'network-request-failed':
        return 'No internet connection';
      default:
        return 'Login failed ($code)';
    }
  }
}

// =========================================================
// LOGIN PAGE
// =========================================================
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final c = Get.put(LoginController());

  // The page owns its text controllers and disposes them safely
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => c.login(email: _email.text, password: _password.text);

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
                if (!wide) ...[const _Logo(), const SizedBox(height: 28)],
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
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: c.hidePassword.value,
                  textInputAction: TextInputAction.done,
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => c.forgotPassword(_email.text),
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
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('SIGN IN'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Only owner, manager and crew accounts can sign in here.',
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
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Logo(light: true),
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

class _Logo extends StatelessWidget {
  final bool light;
  const _Logo({this.light = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: C.orange,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.handyman, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Text(
          'Twins Handyman',
          style: TextStyle(
            color: light ? Colors.white : C.navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';

// import '../../core/core.dart';
// import '../../layout/shell.dart';
// import '../../widgets/widgets.dart';

// class LoginPage extends StatelessWidget {
//   const LoginPage({super.key});
//   @override
//   Widget build(BuildContext context) {
//     final wide = MediaQuery.of(context).size.width >= 900;
//     final form = Center(
//       child: SingleChildScrollView(
//         padding: const EdgeInsets.all(28),
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 400),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               if (!wide) ...[const Logo(), const SizedBox(height: 28)],
//               const Text(
//                 'Admin Sign In',
//                 style: TextStyle(
//                   fontSize: 28,
//                   fontWeight: FontWeight.w900,
//                   color: C.navy,
//                 ),
//               ),
//               const SizedBox(height: 6),
//               const Text(
//                 'Manage quotes, jobs, payments and customers.',
//                 style: TextStyle(color: C.muted),
//               ),
//               const SizedBox(height: 28),
//               const TextField(
//                 decoration: InputDecoration(
//                   labelText: 'Email',
//                   prefixIcon: Icon(Icons.mail_outline),
//                 ),
//               ),
//               const SizedBox(height: 14),
//               const TextField(
//                 obscureText: true,
//                 decoration: InputDecoration(
//                   labelText: 'Password',
//                   prefixIcon: Icon(Icons.lock_outline),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: TextButton(
//                   onPressed: () {},
//                   child: const Text('Forgot password?'),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () => Get.off(() => const Shell()),
//                   child: const Text('SIGN IN'),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               const Text(
//                 'Demo mode: tap Sign In to continue. MFA is enabled for owner accounts.',
//                 style: TextStyle(color: C.muted, fontSize: 12),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: wide
//           ? Row(
//               children: [
//                 Expanded(
//                   child: Container(
//                     color: C.navy,
//                     padding: const EdgeInsets.all(56),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: const [
//                         // Logo(light: true),
//                         SizedBox(height: 40),
//                         Text(
//                           'Run your contracting\nbusiness from one place.',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 40,
//                             fontWeight: FontWeight.w900,
//                             height: 1.1,
//                           ),
//                         ),
//                         SizedBox(height: 18),
//                         Text(
//                           'Quotes • Jobs • Scheduling • Invoices • Payments • Reviews',
//                           style: TextStyle(
//                             color: Color(0xFFB8C4D6),
//                             fontSize: 16,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 Expanded(child: form),
//               ],
//             )
//           : form,
//     );
//   }
// }
