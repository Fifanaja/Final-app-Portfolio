import 'dart:ui';

class Recognition {
  final String id;
  final String label;
  final double confidence;
  final double x;
  final double y;
  final double width;
  final double height;

  const Recognition({
    required this.id,
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Rect get rect => Rect.fromLTWH(x, y, width, height);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'confidence': confidence,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  factory Recognition.fromJson(Map<String, dynamic> json) {
    return Recognition(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      confidence: ((json['confidence'] ?? 0) as num).toDouble(),
      x: ((json['x'] ?? 0) as num).toDouble(),
      y: ((json['y'] ?? 0) as num).toDouble(),
      width: ((json['width'] ?? 0) as num).toDouble(),
      height: ((json['height'] ?? 0) as num).toDouble(),
    );
  }

  static List<Recognition> listFromJson(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) => Recognition.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
