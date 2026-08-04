/// Where a diagnosis came from -- shown in the UI and stored in history so
/// the user can tell a free/offline on-device result from a cloud one.
enum DiagnosisSource { geminiVision, onDeviceEsp32Cam }

class DiagnosisResult {
  final int? id;
  final DiagnosisSource source;
  final String diseaseName;
  final double confidence;
  final String symptomDescription;
  final String correctiveMeasures;
  final String? imagePath;
  final DateTime timestamp;

  const DiagnosisResult({
    this.id,
    required this.source,
    required this.diseaseName,
    required this.confidence,
    required this.symptomDescription,
    required this.correctiveMeasures,
    this.imagePath,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': source.name,
      'diseaseName': diseaseName,
      'confidence': confidence,
      'symptomDescription': symptomDescription,
      'correctiveMeasures': correctiveMeasures,
      'imagePath': imagePath,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DiagnosisResult.fromMap(Map<String, dynamic> map) {
    return DiagnosisResult(
      id: map['id'] as int?,
      source: DiagnosisSource.values.firstWhere(
        (s) => s.name == map['source'],
        orElse: () => DiagnosisSource.geminiVision,
      ),
      diseaseName: map['diseaseName'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      symptomDescription: map['symptomDescription'] as String,
      correctiveMeasures: map['correctiveMeasures'] as String,
      imagePath: map['imagePath'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
