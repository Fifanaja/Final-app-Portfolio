import 'dart:typed_data';

class ScanRecord {
  final Uint8List? imageBytes;
  final String diagnosis;
  final double confidence;
  final DateTime createdAt;

  ScanRecord({
    required this.imageBytes,
    required this.diagnosis,
    required this.confidence,
    required this.createdAt,
  });
}

class HistoryStore {
  HistoryStore._();
  static final HistoryStore instance = HistoryStore._();

  final List<ScanRecord> _items = [];
  List<ScanRecord> get items => List.unmodifiable(_items);

  void add(ScanRecord record) {
    _items.insert(0, record);
  }

  void clear() => _items.clear();
}
