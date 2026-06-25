import 'dart:convert';
import 'detection.dart';

class ScanEntry {
  final String imagePath;
  final DateTime timestamp;
  final List<Detection> detections;

  ScanEntry({
    required this.imagePath,
    required this.timestamp,
    required this.detections,
  });

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'timestamp': timestamp.toIso8601String(),
    'detections': detections.map((e) => e.toJson()).toList(),
  };

  factory ScanEntry.fromJson(Map<String, dynamic> j) => ScanEntry(
    imagePath: j['imagePath'] as String,
    timestamp: DateTime.parse(j['timestamp'] as String),
    detections: (j['detections'] as List)
        .map((e) => Detection.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  static String encodeList(List<ScanEntry> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<ScanEntry> decodeList(String s) {
    final raw = jsonDecode(s) as List;
    return raw
        .map((e) => ScanEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
