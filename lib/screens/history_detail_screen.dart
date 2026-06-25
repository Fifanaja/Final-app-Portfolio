import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:my_mobile_app/models/recognition.dart';
import 'package:my_mobile_app/theme.dart';
import 'package:my_mobile_app/widgets/bounding_box_painter.dart';

class HistoryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const HistoryDetailScreen({
    super.key,
    required this.data,
  });

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  Uint8List? _imageBytes;
  ui.Image? _decodedImage;
  List<Recognition> _recognitions = [];

  bool _isImageExpanded = false;

  @override
  void initState() {
    super.initState();
    _prepareData();
  }

  Future<void> _prepareData() async {
    final imageBase64 = (widget.data['imageBase64'] ?? '').toString();

    Uint8List? bytes;
    if (imageBase64.isNotEmpty) {
      try {
        bytes = base64Decode(imageBase64);
      } catch (_) {}
    }

    final recognitions = Recognition.listFromJson(widget.data['recognitions']);

    ui.Image? decoded;
    if (bytes != null) {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      decoded = frame.image;
    }

    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _decodedImage = decoded;
      _recognitions = recognitions.where((e) => e.confidence >= 0.25).toList();
    });
  }

  Widget _buildChatBubble(
    BuildContext context, {
    required String message,
    required bool isUser,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? brandCyan : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Map<String, int> _buildSummaryMap() {
    final result = <String, int>{};
    for (final item in _recognitions) {
      result[item.label] = (result[item.label] ?? 0) + 1;
    }
    return result;
  }

  // 🚨 พระเอกของเรากลับมาแล้ว: ใช้ FittedBox จับรูปและกรอบมัดรวมกันตามโค้ดเก่า!
  Widget _buildImagePreview() {
    if (_imageBytes == null) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Icon(
            Icons.image_not_supported,
            size: 50,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          panEnabled: true,
          minScale: 1.0,
          maxScale: 5.0,
          child: Center(
            child: _decodedImage != null
                ? FittedBox(
                    fit: BoxFit.cover, // ให้ภาพขึงเต็มกรอบหน้าจอ
                    child: SizedBox(
                      width: _decodedImage!.width.toDouble(),
                      height: _decodedImage!.height.toDouble(),
                      child: Stack(
                        children: [
                          Image.memory(
                            _imageBytes!,
                            fit: BoxFit.fill, 
                          ),
                          CustomPaint(
                            size: Size(
                              _decodedImage!.width.toDouble(),
                              _decodedImage!.height.toDouble(),
                            ),
                            painter: BoundingBoxPainter(_recognitions),
                          ),
                        ],
                      ),
                    ),
                  )
                : Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.38),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final diagnosis = (widget.data['diagnosis'] ?? 'Unknown').toString().trim();
    final confidence = ((widget.data['confidence'] ?? 0.0) as num).toDouble();
    final chatHistory = (widget.data['chatHistory'] as List?) ?? [];
    final summary = _buildSummaryMap();

    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'History Detail',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: bgGradient),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isImageExpanded = true;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.fastOutSlowIn,
                height: _isImageExpanded ? screenHeight * 0.65 : 280,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
                child: _buildImagePreview(),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_isImageExpanded) {
                    setState(() {
                      _isImageExpanded = false;
                    });
                  }
                },
                behavior: HitTestBehavior.opaque, 
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diagnosis.isEmpty ? 'ไม่ทราบผลการวิเคราะห์' : diagnosis,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.15,
                          fontWeight: FontWeight.bold,
                          color: brandCyanDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ความมั่นใจ ${(confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (summary.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: summary.entries.map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: brandCyan.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${e.key} ${e.value}',
                                style: const TextStyle(
                                  color: brandCyanDark,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 18),
                      const Text(
                        'แชทย้อนหลัง',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: chatHistory.isEmpty
                            ? Center(
                                child: Text(
                                  'ยังไม่มีประวัติแชทในรายการนี้',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              )
                            : ListView.builder(
                                itemCount: chatHistory.length,
                                itemBuilder: (context, index) {
                                  final item = Map<String, dynamic>.from(
                                    chatHistory[index] as Map,
                                  );
                                  final isUser = item['role'] == 'user';
                                  final message =
                                      (item['message'] ?? '').toString();

                                  return _buildChatBubble(
                                    context,
                                    message: message,
                                    isUser: isUser,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}