class ScanHistoryItem {
  final String id;
  final String imagePath;
  final DateTime scannedAt;
  final String status;
  final String? grade;
  final double? confidence;

  const ScanHistoryItem({
    required this.id,
    required this.imagePath,
    required this.scannedAt,
    required this.status,
    this.grade,
    this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'scannedAt': scannedAt.toIso8601String(),
        'status': status,
        'grade': grade,
        'confidence': confidence,
      };

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      status: json['status'] as String,
      grade: json['grade'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
    );
  }
}
