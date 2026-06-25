import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:my_mobile_app/config/api_keys.dart';

import '../theme.dart';

class CompareScreen extends StatefulWidget {
  final Map<String, dynamic> latestData;
  final Map<String, dynamic> previousData;

  const CompareScreen({
    super.key,
    required this.latestData,
    required this.previousData,
  });

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  bool _isLoadingAiSummary = true;
  String _aiSummary = '';

  @override
  void initState() {
    super.initState();
    _generateAiSummary();
  }

  // 1. ดึงจำนวนสิวมาใช้งาน (เผื่อค่าเป็น null ให้ตีเป็น 0)
  int _getCount(Map<String, dynamic> data) {
    return int.tryParse(data['detectionCount']?.toString() ?? '0') ?? 0;
  }

  // 2. ให้คะแนนความรุนแรงของสิว (เผื่อกรณีจำนวนสิวเท่าเดิม แต่ชนิดสิวเปลี่ยน)
  int _getSeverityLevel(String diagnosis) {
    if (diagnosis.contains('ผิวสุขภาพดี') || diagnosis.contains('ไม่พบปัญหา'))
      return 0;
    if (diagnosis.contains('สิวผด') ||
        diagnosis.contains('สิวอุดตัน') ||
        diagnosis.contains('Blackhead')) return 1;
    if (diagnosis.contains('สิวอักเสบ') || diagnosis.contains('Papule'))
      return 2;
    if (diagnosis.contains('สิวหัวช้าง') || diagnosis.contains('Cystic'))
      return 3;
    return 1;
  }

  // 3. 🧠 Logic การเปรียบเทียบที่ Make Sense! (อธิบายอาจารย์ตามนี้ได้เลย)
  int _checkTrend(
      int latestCount, int prevCount, String latestDiag, String prevDiag) {
    // กฎข้อ 1: เทียบ "จำนวนสิว" ก่อนเลย ชัดเจนที่สุด
    if (latestCount < prevCount) return -1; // สิวลดลง = ดีขึ้น (-1)
    if (latestCount > prevCount) return 1; // สิวเพิ่มขึ้น = แย่ลง (1)

    // กฎข้อ 2: ถ้าจำนวนสิว "เท่าเดิม" ให้ดูที่ "ความรุนแรงของชนิดสิว"
    int latestSeverity = _getSeverityLevel(latestDiag);
    int prevSeverity = _getSeverityLevel(prevDiag);

    if (latestSeverity < prevSeverity) return -1; // ชนิดสิวเบาลง = ดีขึ้น (-1)
    if (latestSeverity > prevSeverity)
      return 1; // ชนิดสิวรุนแรงขึ้น = แย่ลง (1)

    return 0; // ทุกอย่างเท่าเดิมจริงๆ (0)
  }

  String _getSummaryText(
      int latestCount, int prevCount, String latestDiag, String prevDiag) {
    int trend = _checkTrend(latestCount, prevCount, latestDiag, prevDiag);
    if (trend == 1) return 'แนวโน้มสิวเพิ่มขึ้น / รุนแรงขึ้น';
    if (trend == -1) return 'แนวโน้มสิวลดลง / ดีขึ้น';
    return 'แนวโน้มใกล้เคียงเดิม';
  }

  Color _getSummaryColor(
      int latestCount, int prevCount, String latestDiag, String prevDiag) {
    int trend = _checkTrend(latestCount, prevCount, latestDiag, prevDiag);
    if (trend == 1) return Colors.redAccent.shade700;
    if (trend == -1) return Colors.green;
    return Colors.orange;
  }

  Future<void> _generateAiSummary() async {
    final latestDiagnosis =
        (widget.latestData['diagnosis'] ?? 'ไม่ระบุ').toString();
    final latestCount = _getCount(widget.latestData);

    final previousDiagnosis =
        (widget.previousData['diagnosis'] ?? 'ไม่ระบุ').toString();
    final previousCount = _getCount(widget.previousData);

    int trend = _checkTrend(
        latestCount, previousCount, latestDiagnosis, previousDiagnosis);
    String trendWord =
        trend == -1 ? "ดีขึ้น" : (trend == 1 ? "แย่ลง" : "เท่าเดิม");

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: ApiKeys.geminiApiKey,
      );

      // 🚨 ส่ง Prompt ใหม่ที่อิงจาก "จำนวนสิว" ไม่ใช่ Confidence
      final prompt = '''
คุณคือผู้ช่วยด้านผิวพรรณของแอป ACNE.AI
ช่วยสรุปการเปรียบเทียบผลสแกนสิว 2 ครั้งให้ผู้ใช้เข้าใจง่าย เป็นภาษาไทย

ข้อมูลครั้งก่อน: เป็นสิวประเภท $previousDiagnosis จำนวน $previousCount จุด
ข้อมูลล่าสุด: เป็นสิวประเภท $latestDiagnosis จำนวน $latestCount จุด
แนวโน้ม: $trendWord

ข้อกำหนด:
1. สรุปสั้นๆ เป็นกันเอง ให้กำลังใจ
2. วิเคราะห์จาก "จำนวนสิวที่ลดลง/เพิ่มขึ้น" เป็นหลัก 
3. ให้คำแนะนำดูแลผิว 1-2 ข้อ
4. ความยาวไม่เกิน 4 บรรทัด
''';

      final response = await model.generateContent([Content.text(prompt)]);
      if (!mounted) return;

      setState(() {
        _aiSummary = response.text?.trim() ?? 'กำลังประมวลผล...';
        _isLoadingAiSummary = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiSummary =
            'AI สรุปเบื้องต้น: ผลล่าสุดมีแนวโน้ม $trendWord แนะนำให้ดูแลความสะอาดผิวหน้าอย่างสม่ำเสมอนะคะ';
        _isLoadingAiSummary = false;
      });
    }
  }

  Widget _buildCompareImage(
      {required String imageUrl, required String imageBase64}) {
    if (imageUrl.isNotEmpty) {
      return Image.network(imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image));
    }
    if (imageBase64.isNotEmpty) {
      return Image.memory(base64Decode(imageBase64),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image));
    }
    return Container(
        color: Colors.grey[200],
        child: const Center(
            child: Icon(Icons.image_not_supported, color: Colors.grey)));
  }

  @override
  Widget build(BuildContext context) {
    // ดึงข้อมูลเพื่อใช้แสดงผลใน UI
    final latestDiagnosis =
        (widget.latestData['diagnosis'] ?? 'ไม่ระบุ').toString();
    final latestCount = _getCount(widget.latestData);
    final latestImageUrl = (widget.latestData['imageUrl'] ?? '').toString();
    final latestImageBase64 =
        (widget.latestData['imageBase64'] ?? '').toString();

    final previousDiagnosis =
        (widget.previousData['diagnosis'] ?? 'ไม่ระบุ').toString();
    final previousCount = _getCount(widget.previousData);
    final previousImageUrl = (widget.previousData['imageUrl'] ?? '').toString();
    final previousImageBase64 =
        (widget.previousData['imageBase64'] ?? '').toString();

    final summaryText = _getSummaryText(
        latestCount, previousCount, latestDiagnosis, previousDiagnosis);
    final summaryColor = _getSummaryColor(
        latestCount, previousCount, latestDiagnosis, previousDiagnosis);

    // คำนวณผลต่างของจำนวนสิว
    final diffCount = latestCount - previousCount;
    final diffText = diffCount > 0
        ? 'เพิ่มขึ้น $diffCount จุด'
        : (diffCount < 0 ? 'ลดลง ${diffCount.abs()} จุด' : 'เท่าเดิม');
    final diffColor = diffCount < 0
        ? Colors.green
        : (diffCount > 0 ? Colors.redAccent : Colors.orange);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Before / After Compare',
            style: TextStyle(
                color: brandCyanDark,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // กล่องรูปภาพ และ สรุปแนวโน้ม
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: glassCardDecoration,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: _CompareImageCard(
                                  title: 'ก่อนหน้า',
                                  child: _buildCompareImage(
                                      imageUrl: previousImageUrl,
                                      imageBase64: previousImageBase64))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _CompareImageCard(
                                  title: 'ล่าสุด',
                                  child: _buildCompareImage(
                                      imageUrl: latestImageUrl,
                                      imageBase64: latestImageBase64))),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: summaryColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: summaryColor.withOpacity(0.35)),
                        ),
                        child: Text(summaryText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: summaryColor)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // กล่องเปรียบเทียบข้อมูล (เปลี่ยนเป็นจำนวนสิวแล้ว!)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: glassCardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('เปรียบเทียบผลการวิเคราะห์',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: brandCyanDark)),
                      const SizedBox(height: 16),
                      _CompareInfoRow(
                          label: 'Diagnosis ก่อนหน้า',
                          value: previousDiagnosis),
                      _CompareInfoRow(
                          label: 'Diagnosis ล่าสุด', value: latestDiagnosis),
                      _CompareInfoRow(
                          label: 'จำนวนสิวก่อนหน้า',
                          value: '$previousCount จุด'),
                      _CompareInfoRow(
                          label: 'จำนวนสิวล่าสุด', value: '$latestCount จุด'),
                      _CompareInfoRow(
                          label: 'ผลต่าง',
                          value: diffText,
                          valueColor: diffColor),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // กล่องสรุปจาก AI
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: glassCardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: brandCyanDark),
                          SizedBox(width: 8),
                          Text('AI Summary',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: brandCyanDark)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingAiSummary)
                        const Center(
                            child: CircularProgressIndicator(color: brandCyan))
                      else
                        Text(_aiSummary,
                            style: TextStyle(
                                color: Colors.grey[800],
                                height: 1.6,
                                fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompareImageCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _CompareImageCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: brandCyanDark)),
        const SizedBox(height: 8),
        ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(height: 180, width: double.infinity, child: child)),
      ],
    );
  }
}

class _CompareInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _CompareInfoRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              flex: 3,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey[700], fontWeight: FontWeight.w600))),
          Expanded(
              flex: 2,
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: valueColor ?? Colors.black87,
                      fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
