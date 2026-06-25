import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_mobile_app/models/recognition.dart';
import 'package:my_mobile_app/theme.dart';
import 'package:my_mobile_app/widgets/bounding_box_painter.dart';

class ResultScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final List<Recognition> recognitions;

  const ResultScreen({
    super.key,
    required this.imageBytes,
    required this.recognitions,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<Map<String, String>> _chatMessages = [];

  bool _isLoadingAI = true;
  bool _isSaved = false;
  String? _historyDocId;
  ui.Image? _decodedImage;

  String _userName = 'คุณ';
  String _userGender = 'ไม่ระบุ';
  String _userAge = 'ไม่ระบุ';

  List<Recognition> _recognitions = [];

  @override
  void initState() {
    super.initState();
    // 1. ดึงค่าสิวมาเก็บไว้ก่อน (สำคัญมาก ห้ามลบ!)
    _recognitions = widget.recognitions.toList();

    // 2. โหลดโปรไฟล์เสร็จแล้วค่อยสั่ง AI รุก (วิเคราะห์ผลทันที)
    _loadUserProfile().then((_) {
      _initChat();
    });

    _decodeImage();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            _userName =
                (data['username'] ?? user.displayName ?? 'ตัวเอง').toString();
            _userGender = (data['gender'] ?? 'ไม่ระบุ').toString();
            _userAge = (data['age'] ?? 'ไม่ระบุ').toString();
          });
        }
      }
    } catch (e) {
      debugPrint('❌ ดึงโปรไฟล์พัง: $e');
    }
  }

  Future<void> _decodeImage() async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(widget.imageBytes, (ui.Image img) {
      completer.complete(img);
    });
    final image = await completer.future;
    if (!mounted) return;
    setState(() {
      _decodedImage = image;
    });
  }

  // 🧠 ฟังก์ชันหัวใจหลัก: รวมร่างสรุปผล + คำแนะนำ เป็นข้อความเดียว!
  Future<void> _initChat() async {
    setState(() {
      _isLoadingAI = true; // เริ่มปุ๊บ โชว์หมุนๆ รอเลย ยังไม่พ่นข้อความ
    });

    final total = _recognitions.length;
    final summary = _buildDetectionSummaryMap();
    final diagnosis = _primaryDiagnosis();
    final lines =
        summary.entries.map((e) => '• ${e.key} ${e.value} จุด').join('\n');

    // 1. สร้างข้อความส่วนแรก (ทักทาย + สรุปจำนวนสิว) เตรียมรอไว้ก่อน
    String localSummary =
        'สวัสดีค่ะคุณ $_userName! ACNE.AI ตรวจพบสิวทั้งหมด $total จุดนะคะ ✨\n$lines';

    // ถ้าไม่พบสิวเลย ก็จบแค่นี้ ไม่ต้องไปถาม AI
    if (_recognitions.isEmpty) {
      if (mounted) {
        setState(() {
          _chatMessages.add({
            'role': 'model',
            'message':
                'สวัสดีค่ะคุณ $_userName! ACNE.AI ไม่พบสิวที่ชัดเจนในภาพนี้นะคะ ✨\nดูแลผิวให้สะอาดแบบนี้ต่อไปค่ะ!'
          });
          _isLoadingAI = false;
        });
        _saveToHistory();
      }
      return;
    }

    // 2. ถ้าพบสิว แอบไปถาม Gemini เรื่องวิธีรักษา
    try {
      const apiKey = 'AIzaSyD5gXjYiMtySHdTPO3OZP_nV4sCt4yF3gI';
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

      final prompt = '''
คุณคือ "ACNE.AI" ผู้เชี่ยวชาญด้านผิวพรรณ 
ผู้ใช้ชื่อ $_userName อายุ $_userAge ปี เพศ $_userGender 
เพิ่งสแกนพบ: $diagnosis
จงแนะนำ "วิธีดูแลรักษาเบื้องต้น" สำหรับสิวประเภทนี้
[กฎการตอบ]:
1. ตอบแบบสั้น กระชับ เป็นข้อๆ
2. ห้ามแนะนำยาอันตราย
3. 🚨 ห้ามเกริ่นทักทายซ้ำ (ไม่ต้องพูดสวัสดีแล้ว) ให้เริ่มที่คำแนะนำทันที!
''';

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {"text": prompt}
                  ]
                }
              ],
              "generationConfig": {"temperature": 0.7, "maxOutputTokens": 2048}
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiAdvice = data['candidates'][0]['content']['parts'][0]['text']
            .toString()
            .trim();

        if (mounted) {
          setState(() {
            // 🚨 3. รวมร่างข้อความที่นี่! (เอาคำทักทาย + คำแนะนำ มาต่อกัน)
            _chatMessages.add({
              'role': 'model',
              'message': '$localSummary\n\n💡 **คำแนะนำเบื้องต้น:**\n$aiAdvice'
            });
            _isLoadingAI = false;
          });
          _saveToHistory();
        }
      } else {
        _fallbackInitialResponse(localSummary);
      }
    } catch (e) {
      debugPrint('AI Initial Error: $e');
      _fallbackInitialResponse(localSummary);
    }
  }

  // ฟังก์ชันสำรอง กรณีเน็ตหลุดหรือ AI คิวเต็มตอนเริ่มหน้า
  void _fallbackInitialResponse(String localSummary) {
    if (mounted) {
      setState(() {
        _chatMessages.add({
          'role': 'model',
          'message':
              '$localSummary\n\n(ตอนนี้ระบบ AI อาจจะคิวเต็ม แนะนำให้ล้างหน้าให้สะอาดด้วยคลีนเซอร์สูตรอ่อนโยน และหลีกเลี่ยงการบีบสิวนะคะ ✨)'
        });
        _isLoadingAI = false;
      });
      _saveToHistory();
    }
  }

  void _fallbackResponse() {
    final safeAdvice =
        "สำหรับการดูแลเบื้องต้น แนะนำให้ล้างหน้าให้สะอาดด้วยคลีนเซอร์สูตรอ่อนโยน และหลีกเลี่ยงการบีบสิวนะครับ (ตอนนี้ระบบ AI อาจจะคิวเต็ม ลองถามใหม่อีกครั้งนะครับ ✨)";
    if (mounted) {
      setState(() {
        _chatMessages.add({'role': 'model', 'message': safeAdvice});
        _isLoadingAI = false;
      });
      _saveToHistory();
    }
  }

  Map<String, int> _buildDetectionSummaryMap() {
    final Map<String, int> result = {};
    for (final item in _recognitions) {
      result[item.label] = (result[item.label] ?? 0) + 1;
    }
    return result;
  }

  String _primaryDiagnosis() {
    if (_recognitions.isEmpty) return 'ไม่พบสิวที่ชัดเจน';
    final summary = _buildDetectionSummaryMap();
    final sorted = summary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  double _topConfidence() {
    if (_recognitions.isEmpty) return 0;
    return _recognitions
        .map((e) => e.confidence)
        .reduce((a, b) => a > b ? a : b);
  }

  Future<void> _saveToHistory() async {
    if (_isSaved || _decodedImage == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final codec =
          await ui.instantiateImageCodec(widget.imageBytes, targetWidth: 400);
      final frame = await codec.getNextFrame();
      final byteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final base64Image = base64Encode(byteData.buffer.asUint8List());

      final recognitionsData = _recognitions.map((e) {
        return {
          'id': e.id,
          'label': e.label,
          'confidence': e.confidence,
          'x': e.x,
          'y': e.y,
          'width': e.width,
          'height': e.height,
        };
      }).toList();

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .add({
        'diagnosis': _primaryDiagnosis(),
        'confidence': _topConfidence(),
        'imageBase64': base64Image,
        'timestamp': FieldValue.serverTimestamp(),
        'chatHistory': _chatMessages,
        'detectionCount': _recognitions.length,
        'recognitions': recognitionsData,
      });

      _historyDocId = docRef.id;
      _isSaved = true;
    } catch (e) {
      debugPrint('❌ เซฟประวัติพัง: $e');
    }
  }

  Future<void> _syncHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _historyDocId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .doc(_historyDocId)
          .update({
        'chatHistory': _chatMessages,
      });
    } catch (e) {
      debugPrint('sync error: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoadingAI) return;

    setState(() {
      _chatMessages.add({'role': 'user', 'message': text});
      _textController.clear();
      _isLoadingAI = true;
    });
    _scrollToBottom();

    final diagnosis = _primaryDiagnosis();

    try {
      const apiKey = 'AIzaSyD5gXjYiMtySHdTPO3OZP_nV4sCt4yF3gI';
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

      final prompt = '''
คุณคือ "ACNE.AI" ผู้เชี่ยวชาญด้านผิวพรรณที่คุยเป็นธรรมชาติ เหมือนเพื่อนให้คำปรึกษา
ข้อมูลผู้ใช้: คุณ $_userName, อายุ $_userAge ปี
สิวที่ผู้ใช้กำลังเป็นอยู่: $diagnosis

คำถามล่าสุดของผู้ใช้: "$text"

[กฎเหล็กในการตอบ (Strict Rules)]:
1. ห้ามเกริ่นนำ ห้ามทักทาย ห้ามสรุปผลสิวซ้ำ เข้าประเด็นตอบคำถามทันที!
2. เน้นการตอบแบบ "สั้น โคตรกระชับ เข้าใจง่าย"
3. หากมีคำแนะนำหลายข้อ บังคับให้ใช้ Bullet points (•) 
4. ห้ามแนะนำยาอันตราย
''';

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {"text": prompt}
                  ]
                }
              ],
              "generationConfig": {"temperature": 0.7, "maxOutputTokens": 2048}
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiSpeech = data['candidates'][0]['content']['parts'][0]['text']
            .toString()
            .trim();

        setState(() {
          _chatMessages.add({'role': 'model', 'message': aiSpeech});
        });
      } else {
        _fallbackResponse();
      }
    } catch (e) {
      _fallbackResponse();
    } finally {
      if (mounted) setState(() => _isLoadingAI = false);
      _scrollToBottom();
      _syncHistory();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // 🚨 UI กล่องรูปภาพอันเก่าที่กรอบตรงเป๊ะ!
  Widget _buildImagePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(widget.imageBytes, fit: BoxFit.fill),
        if (_decodedImage != null)
          CustomPaint(painter: BoundingBoxPainter(_recognitions)),
        Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
              Colors.black.withOpacity(0.25),
              Colors.transparent,
              Colors.transparent
            ]))),
        Positioned(
            top: 92,
            left: 12,
            right: 12,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.42),
                          borderRadius: BorderRadius.circular(18)),
                      child: Text(
                          _recognitions.isEmpty
                              ? 'ไม่พบสิว'
                              : 'ตรวจพบ ${_recognitions.length} จุด',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12))),
                  if (_recognitions.isNotEmpty)
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.42),
                            borderRadius: BorderRadius.circular(18)),
                        child: Text(
                            'สูงสุด ${(_topConfidence() * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12))),
                ])),
      ],
    );
  }

  // 🚨 UI แชทบับเบิ้ลอันเก่าที่อ่านง่าย สีพื้นหลังถูกต้อง!
  Widget _buildChatBubble(
      {required String message, required bool isUser, bool isLoading = false}) {
    return Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85),
            decoration: BoxDecoration(
                color: isUser ? brandCyan : Colors.grey[100],
                borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 0),
                    bottomRight: Radius.circular(isUser ? 0 : 16))),
            child: isLoading
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: brandCyan)),
                    const SizedBox(width: 10),
                    Flexible(
                        child: Text(message,
                            style: TextStyle(
                                color: isUser ? Colors.white : Colors.black87,
                                fontSize: 14)))
                  ])
                : Text(message,
                    style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                        fontSize: 14,
                        height: 1.4))));
  }

  Widget _buildChatSection() {
    return Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(children: [
          const SizedBox(height: 14),
          Text('💬 ถาม-ตอบกับ ACNE.AI แชทบอท',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[700])),
          const SizedBox(height: 8),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                  _recognitions.isEmpty
                      ? '⚠️ ประเมินเบื้องต้นเท่านั้น'
                      : '⚠️ ผลสแกนนี้ไม่ใช่การวินิจฉัยทางการแพทย์',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.grey))),
          Expanded(
              child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _chatMessages.length +
                      (_isLoadingAI &&
                              _chatMessages.isNotEmpty &&
                              _chatMessages.last['role'] == 'user'
                          ? 1
                          : 0),
                  itemBuilder: (context, index) {
                    if (index == _chatMessages.length)
                      return _buildChatBubble(
                          message: 'กำลังคิด...',
                          isUser: false,
                          isLoading: true);
                    final msg = _chatMessages[index];
                    return _buildChatBubble(
                        message: msg['message'] ?? '',
                        isUser: msg['role'] == 'user');
                  })),
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[200]!))),
              child: SafeArea(
                  top: false,
                  child: Row(children: [
                    Expanded(
                        child: TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                                hintText: 'ถาม ACNE.AI แชทบอท...',
                                filled: true,
                                fillColor: Colors.grey[100],
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide: BorderSide.none)))),
                    const SizedBox(width: 10),
                    CircleAvatar(
                        backgroundColor: _isLoadingAI ? Colors.grey : brandCyan,
                        child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: _isLoadingAI ? null : _sendMessage)),
                  ]))),
        ]));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('ผลลัพธ์ ACNE.AI',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (route) => false))),
        body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(gradient: bgGradient),
            child: Column(children: [
              Expanded(
                  flex: 5,
                  child: SizedBox(
                      width: double.infinity,
                      child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(30)),
                          child: _buildImagePreview()))),
              Expanded(flex: 5, child: _buildChatSection()),
            ])));
  }
}
