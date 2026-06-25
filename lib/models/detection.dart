enum AcneType { whitehead, blackhead, pustule }

class Detection {
  final double x; // 0..1 from left
  final double y; // 0..1 from top
  final AcneType type;
  Detection({required this.x, required this.y, required this.type});

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'type': type.name};

  factory Detection.fromJson(Map<String, dynamic> j) {
    final t = j['type'] as String? ?? 'whitehead';
    return Detection(
      x: (j['x'] as num).toDouble(),
      y: (j['y'] as num).toDouble(),
      type: AcneType.values.firstWhere(
        (e) => e.name == t,
        orElse: () => AcneType.whitehead,
      ),
    );
  }
}

String mostCommonType(Iterable<Detection> list) {
  final counts = <AcneType, int>{};
  for (final d in list) {
    counts[d.type] = (counts[d.type] ?? 0) + 1;
  }
  if (counts.isEmpty) return '-';
  final entry = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  switch (entry.key) {
    case AcneType.whitehead:
      return 'Whiteheads';
    case AcneType.blackhead:
      return 'Blackheads';
    case AcneType.pustule:
      return 'Pustules';
  }
}
