import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/history_screen.dart'; // 👈 นำเข้าหน้า History ถูกต้อง 100%
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/scan_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AcneScreen AI',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const AuthGate(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/scan': (context) => const ScanScreen(),
        '/history': (context) => HistoryScreen(), // 👈 ใส่กลับให้เป๊ะๆ
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // กำลังเช็คสถานะล็อกอิน
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: brandCyan),
            ),
          );
        }

        // ล็อกอินอยู่แล้ว -> เข้า Home เลย
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // ยังไม่ล็อกอิน -> ไปหน้า Login
        return const LoginScreen();
      },
    );
  }
}