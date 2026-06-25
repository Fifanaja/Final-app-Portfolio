import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _tip = 'กำลังโหลดคำแนะนำ...';
  bool _isLoadingTip = true;

  @override
  void initState() {
    super.initState();
    _loadRandomTip();
  }

  Future<void> _signOut() async {
    // 1. สั่งออกจากระบบ Firebase อย่างเป็นทางการ
    await FirebaseAuth.instance.signOut();

    // 2. วิชามารเตะกลับหน้าแรก: เคลียร์หน้าจอที่ซ้อนกันอยู่ทิ้งให้หมด
    // แล้วเด้งกลับไปหา "ยามเฝ้าประตู (StreamBuilder)" ในไฟล์ main.dart
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  String _getUsername(User? user) {
    if (user == null) return 'Guest';

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user.email?.trim();
    if (email != null && email.isNotEmpty && email.contains('@')) {
      return email.split('@')[0];
    }

    return 'Guest';
  }

  Future<void> _openProfile(BuildContext context) async {
    await Navigator.pushNamed(context, '/profile');
    await FirebaseAuth.instance.currentUser?.reload();
    await _loadRandomTip();
    if (mounted) {
      setState(() {});
    }
  }

  void _openHistory(BuildContext context) {
    Navigator.pushNamed(context, '/history').then((_) async {
      await _loadRandomTip();
      if (mounted) setState(() {});
    });
  }

  void _openScan(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanScreen()),
    ).then((_) async {
      await _loadRandomTip();
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadRandomTip() async {
    try {
      if (mounted) {
        setState(() {
          _isLoadingTip = true;
        });
      }

      final snapshot =
          await FirebaseFirestore.instance.collection('tips').limit(50).get();

      final docs = snapshot.docs.where((doc) {
        final data = doc.data();
        final text = (data['text'] ?? '').toString().trim();
        return text.isNotEmpty;
      }).toList();

      if (docs.isEmpty) {
        if (!mounted) return;
        setState(() {
          _tip = 'ยังไม่มีคำแนะนำในระบบ';
          _isLoadingTip = false;
        });
        return;
      }

      final random = Random();
      final randomDoc = docs[random.nextInt(docs.length)];
      final text = (randomDoc.data()['text'] ?? '').toString().trim();

      if (!mounted) return;
      setState(() {
        _tip = text;
        _isLoadingTip = false;
      });
    } catch (e) {
      debugPrint('โหลด tips ไม่สำเร็จ: $e');
      if (!mounted) return;
      setState(() {
        _tip = 'ไม่สามารถโหลดคำแนะนำได้';
        _isLoadingTip = false;
      });
    }
  }

  Widget _buildRecentScanImage({
    required String imageUrl,
    required String imageBase64,
  }) {
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 72,
          height: 72,
          color: Colors.grey[200],
          child: const Icon(Icons.image),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 72,
            height: 72,
            color: Colors.grey[100],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    if (imageBase64.isNotEmpty) {
      return Image.memory(
        base64Decode(imageBase64),
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 72,
          height: 72,
          color: Colors.grey[200],
          child: const Icon(Icons.image),
        ),
      );
    }

    return Container(
      width: 72,
      height: 72,
      color: Colors.grey[200],
      child: const Icon(Icons.image),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data ?? FirebaseAuth.instance.currentUser;
        final username = _getUsername(user);

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text(
              'AcneScreen AI',
              style: TextStyle(
                color: brandCyanDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout, color: Colors.grey),
                onPressed: _signOut,
              ),
            ],
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await FirebaseAuth.instance.currentUser?.reload();
                await _loadRandomTip();
                if (mounted) {
                  setState(() {});
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'สวัสดี, $username 👋',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'วันนี้ผิวหน้าของคุณเป็นยังไงบ้าง?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: brandCyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: brandCyan.withOpacity(0.18),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: brandCyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lightbulb_rounded,
                              color: brandCyanDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _isLoadingTip
                                ? Text(
                                    'Tip: กำลังโหลดคำแนะนำ...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                  )
                                : Text(
                                    'Tip: $_tip',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () => _openScan(context),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [brandCyan, brandCyanDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: brandCyan.withOpacity(0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.face_retouching_natural,
                              size: 64,
                              color: Colors.white,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Scan Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Tap to analyze your skin',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.history,
                            title: 'History',
                            subtitle: 'ดูประวัติการสแกน',
                            onTap: () => _openHistory(context),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.person,
                            title: 'Profile',
                            subtitle: 'แก้ไขข้อมูลส่วนตัว',
                            onTap: () => _openProfile(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Scans',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openHistory(context),
                          child: const Text(
                            'See All',
                            style: TextStyle(
                              color: brandCyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (user == null)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text('กรุณาเข้าสู่ระบบเพื่อดูประวัติ'),
                        ),
                      )
                    else
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('history')
                            .orderBy('timestamp', descending: true)
                            .limit(3)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: brandCyan,
                                ),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'โหลดประวัติไม่สำเร็จ: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                              ),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];

                          if (docs.isEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 32,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.history_toggle_off,
                                    size: 52,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'ยังไม่มีประวัติการสแกน',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'เมื่อคุณสแกนผิวแล้ว ประวัติล่าสุดจะมาแสดงตรงนี้',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            children: docs.map((doc) {
                              final data =
                                  doc.data() as Map<String, dynamic>? ?? {};
                              final diagnosis =
                                  (data['diagnosis'] ?? 'Unknown').toString();
                              final confidence =
                                  ((data['confidence'] ?? 0.0) as num)
                                      .toDouble();
                              final imageUrl =
                                  (data['imageUrl'] ?? '').toString();
                              final imageBase64 =
                                  (data['imageBase64'] ?? '').toString();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: _buildRecentScanImage(
                                        imageUrl: imageUrl,
                                        imageBase64: imageBase64,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            diagnosis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: brandCyanDark,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                    const SizedBox(height: 10),
                    // 🛡️ ข้อความ Disclaimer ตรงหน้า Home (กันผีชะงัดนัก!)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      margin: const EdgeInsets.only(bottom: 20),
                      child: const Text(
                        '⚠️ ข้อควรระวัง: ผลลัพธ์จากการสแกนนี้เป็นการประเมินเบื้องต้นด้วย AI เท่านั้น ไม่ใช่การวินิจฉัยทางการแพทย์ หากมีอาการอักเสบรุนแรงควรปรึกษาแพทย์ผิวหนัง',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: brandCyanDark, size: 28),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
