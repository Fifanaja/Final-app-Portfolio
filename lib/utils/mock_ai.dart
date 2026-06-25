import 'dart:math';
import '../models/detection.dart';

class MockAI {
  static final _r = Random();

  static List<Detection> generateDetections() {
    final n = 4 + _r.nextInt(6); // 4..9 จุด
    final types = AcneType.values;
    return List.generate(n, (_) {
      // กันไม่ให้ชิดขอบเกินไป
      final x = 0.12 + _r.nextDouble() * 0.76;
      final y = 0.12 + _r.nextDouble() * 0.76;
      return Detection(x: x, y: y, type: types[_r.nextInt(types.length)]);
    });
  }

  static String randomTip() {
    const tips = [
      'ล้างหน้าวันละ 2 ครั้ง ด้วยโฟมอ่อนโยน',
      'หลีกเลี่ยงการจับ/แกะสิว',
      'เปลี่ยนปลอกหมอนทุกสัปดาห์',
      'ทาครีมกันแดดทุกวัน',
      'ดื่มน้ำและนอนพักให้เพียงพอ',
    ];
    return tips[_r.nextInt(tips.length)];
  }
}
