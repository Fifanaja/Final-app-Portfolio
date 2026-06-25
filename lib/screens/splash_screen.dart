import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(parent: _ac, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeIn);

    _ac.forward();

    // รอรวม ๆ ~1.2s แล้วเข้า Home
    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // พื้นหลังโทนอ่อน + วงกลมไล่เฉดแบบแอปเรา
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // วงกลมกราเดียนต์เบลอ ๆ ด้านหลัง เพิ่มกลิ่นแบรนด์
          Align(
            alignment: const Alignment(0, -0.2),
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: homeCircleGradient,
              ),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: _scale,
              child: FadeTransition(
                opacity: _fade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.flutter_dash, size: 96, color: Colors.white),
                    SizedBox(height: 14),
                    Text(
                      'ACNE.AI',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Analyzing skin…',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
