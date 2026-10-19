import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/core.dart';
import 'pages/login/login_page.dart';
import 'controllers/app_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase before using Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register GetX controller.
  Get.put(AppController(), permanent: true);

  runApp(const TwinsAdminApp());
}

class TwinsAdminApp extends StatelessWidget {
  const TwinsAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Twins Handyman Admin',
      theme: AppTheme.light,
      home: const LoginPage(),
    );
  }
}
