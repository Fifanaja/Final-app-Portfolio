import 'package:flutter/material.dart';
import '../models/recognition.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<Recognition> recognitions;

  BoundingBoxPainter(this.recognitions);

  // 🎨 1. ฟังก์ชันเลือกสีกล่อง แยกสีตามชนิดสิว
  Color _getColor(String label) {
    if (label.contains('Blackhead'))
      return Colors.blueAccent; // สิวหัวดำ = น้ำเงิน
    if (label.contains('Cystic')) return Colors.redAccent; // สิวหัวช้าง = แดง
    if (label.contains('Papules'))
      return Colors.orangeAccent; // สิวอักเสบ = ส้ม
    if (label.contains('Pustule'))
      return Colors.amberAccent; // สิวหัวหนอง = เหลือง
    if (label.contains('Sebaceous'))
      return Colors.purpleAccent; // สิวเสี้ยน = ม่วง
    if (label.contains('Whitehead'))
      return Colors.greenAccent; // สิวหัวขาว = เขียว
    return Colors.cyanAccent;
  }

  // 🔤 2. ฟังก์ชันย่อชื่อ เอาแค่ภาษาอังกฤษสั้นๆ พอ จะได้ไม่เกะกะ
  String _getShortName(String label) {
    if (label.contains('Blackhead')) return 'Blackhead';
    if (label.contains('Cystic')) return 'Cystic';
    if (label.contains('Papules')) return 'Papules';
    if (label.contains('Pustule')) return 'Pustule';
    if (label.contains('Sebaceous')) return 'Sebaceous';
    if (label.contains('Whitehead')) return 'Whitehead';
    return 'Acne';
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (var rec in recognitions) {
      final boxColor = _getColor(rec.label);

      final paintBox = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0; // ความหนากรอบ

      final rect = Rect.fromLTWH(
        rec.x * size.width,
        rec.y * size.height,
        rec.width * size.width,
        rec.height * size.height,
      );

      // วาดกรอบสี่เหลี่ยม
      canvas.drawRect(rect, paintBox);

      // วาดป้ายชื่อแบบย่อ
      final shortName = _getShortName(rec.label);
      final textStyle = const TextStyle(
        color: Colors.white,
        fontSize: 9, // ลดขนาดฟอนต์ลง จะได้ไม่เกะกะ
        fontWeight: FontWeight.bold,
      );

      final textSpan = TextSpan(text: shortName, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // ทำพื้นหลังป้ายชื่อให้โปร่งใสหน่อยๆ (opacity 0.8)
      final textBackgroundRect = Rect.fromLTWH(
        rect.left,
        rect.top - 14,
        textPainter.width + 4,
        textPainter.height + 2,
      );

      final paintTextBg = Paint()..color = boxColor.withOpacity(0.8);
      canvas.drawRect(textBackgroundRect, paintTextBg);
      textPainter.paint(canvas, Offset(rect.left + 2, rect.top - 13));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
