import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:my_mobile_app/models/recognition.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class RecognitionResult {
  final List<Recognition> recognitions;
  const RecognitionResult({required this.recognitions});
}

class AiService {
  AiService._privateConstructor();
  static final AiService instance = AiService._privateConstructor();
  Interpreter? _interpreter;

  // 🚨 กลับมาใช้สิว 6 ชนิดตามที่ฟีฟ่าต้องการ
  final List<String> labels = [
    'สิวหัวดำ (Blackhead)', // 0
    'สิวซีสต์/หัวช้าง (Cystic)', // 1
    'สิวอักเสบ/สิวผด (Papules)', // 2
    'สิวหัวหนอง (Pustule)', // 3
    'สิวเสี้ยน (Sebaceous)', // 4
    'สิวหัวขาว/อุดตัน (Whitehead)' // 5
  ];

  Future<void> init() async {
    try {
      _interpreter =
          await Interpreter.fromAsset('assets/models/best_float16.tflite');
      debugPrint('✅ โหลดโมเดล TFLite สำเร็จ');
    } catch (e) {
      debugPrint('🚨 โหลด TFLite ไม่สำเร็จ: $e');
    }
  }

  Future<RecognitionResult> analyzeImage(Uint8List imageBytes) async {
    try {
      if (_interpreter == null)
        return const RecognitionResult(recognitions: []);
      final img.Image? originalImg = img.decodeImage(imageBytes);
      if (originalImg == null) return const RecognitionResult(recognitions: []);

      final int inputSize = _interpreter!.getInputTensor(0).shape[1];
      final img.Image resizedImg =
          img.copyResize(originalImg, width: inputSize, height: inputSize);

      final input = List.generate(
          1,
          (_) => List.generate(inputSize,
              (y) => List.generate(inputSize, (x) => List.filled(3, 0.0))));

      for (int y = 0; y < inputSize; y++) {
        for (int x = 0; x < inputSize; x++) {
          final pixel = resizedImg.getPixel(x, y);
          input[0][y][x][0] = pixel.r / 255.0;
          input[0][y][x][1] = pixel.g / 255.0;
          input[0][y][x][2] = pixel.b / 255.0;
        }
      }

      var outputShape = _interpreter!.getOutputTensor(0).shape;
      int numChannels = outputShape[1];
      int numAnchors = outputShape[2];
      int numClasses = numChannels - 4;

      final output = List.generate(
          1,
          (_) =>
              List.generate(numChannels, (_) => List.filled(numAnchors, 0.0)));
      _interpreter!.run(input, output);

      final List<Recognition> detections = [];

      for (int i = 0; i < numAnchors; i++) {
        double bestClassScore = 0.0;
        int bestClassIndex = -1;

        for (int c = 0; c < numClasses; c++) {
          final score = (output[0][4 + c][i] as num).toDouble();
          if (score > bestClassScore) {
            bestClassScore = score;
            bestClassIndex = c;
          }
        }

        // 🚨 ลดค่าความมั่นใจลงเหลือ 0.15 เพื่อให้จับสิวติดง่ายขึ้น (ตามที่ฟีฟ่าบอกว่าค่าน้อยแต่จับถูก)
        if (bestClassIndex == -1 || bestClassScore < 0.15) continue;

        final rawX = (output[0][0][i] as num).toDouble();
        final rawY = (output[0][1][i] as num).toDouble();
        final rawW = (output[0][2][i] as num).toDouble();
        final rawH = (output[0][3][i] as num).toDouble();

        final cx = rawX > 1.5 ? rawX / inputSize : rawX;
        final cy = rawY > 1.5 ? rawY / inputSize : rawY;
        final w = rawW > 1.5 ? rawW / inputSize : rawW;
        final h = rawH > 1.5 ? rawH / inputSize : rawH;

        double left = cx - (w / 2);
        double top = cy - (h / 2);

        left = left.clamp(0.0, 1.0);
        top = top.clamp(0.0, 1.0);
        double width = w.clamp(0.0, 1.0 - left);
        double height = h.clamp(0.0, 1.0 - top);

        if (width <= 0 || height <= 0 || width > 0.8 || height > 0.8) continue;

        String label =
            bestClassIndex < labels.length ? labels[bestClassIndex] : "สิว";

        detections.add(
          Recognition(
              id: '$i',
              label: label,
              confidence: bestClassScore,
              x: left,
              y: top,
              width: width,
              height: height),
        );
      }

      final filtered = _applyNms(detections, iouThreshold: 0.45);
      return RecognitionResult(recognitions: filtered);
    } catch (e) {
      return const RecognitionResult(recognitions: []);
    }
  }

  List<Recognition> _applyNms(List<Recognition> detections,
      {double iouThreshold = 0.45}) {
    if (detections.isEmpty) return [];
    final sorted = [...detections]
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final List<Recognition> selected = [];
    while (sorted.isNotEmpty) {
      final current = sorted.removeAt(0);
      selected.add(current);
      sorted.removeWhere((candidate) {
        if (candidate.label != current.label) return false;
        return _iou(current, candidate) > iouThreshold;
      });
    }
    return selected;
  }

  double _iou(Recognition a, Recognition b) {
    final ax1 = a.x;
    final ay1 = a.y;
    final ax2 = a.x + a.width;
    final ay2 = a.y + a.height;
    final bx1 = b.x;
    final by1 = b.y;
    final bx2 = b.x + b.width;
    final by2 = b.y + b.height;
    final interLeft = ax1 > bx1 ? ax1 : bx1;
    final interTop = ay1 > by1 ? ay1 : by1;
    final interRight = ax2 < bx2 ? ax2 : bx2;
    final interBottom = ay2 < by2 ? ay2 : by2;
    final interWidth = (interRight - interLeft).clamp(0.0, double.infinity);
    final interHeight = (interBottom - interTop).clamp(0.0, double.infinity);
    final interArea = interWidth * interHeight;
    final areaA = a.width * a.height;
    final areaB = b.width * b.height;
    final union = areaA + areaB - interArea;
    return union <= 0 ? 0.0 : interArea / union;
  }
}
