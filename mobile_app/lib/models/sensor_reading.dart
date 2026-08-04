class SensorReading {
  final double? temperature;
  final double? humidity;
  final int soilMoisture;
  final bool pumpOn;
  final String mode;
  final DateTime timestamp;

  const SensorReading({
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
    required this.pumpOn,
    required this.mode,
    required this.timestamp,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      soilMoisture: (json['soilMoisture'] as num?)?.toInt() ?? 0,
      pumpOn: json['pumpOn'] as bool? ?? false,
      mode: json['mode'] as String? ?? 'auto',
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'soilMoisture': soilMoisture,
      'pumpOn': pumpOn ? 1 : 0,
      'mode': mode,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory SensorReading.fromMap(Map<String, dynamic> map) {
    return SensorReading(
      temperature: (map['temperature'] as num?)?.toDouble(),
      humidity: (map['humidity'] as num?)?.toDouble(),
      soilMoisture: map['soilMoisture'] as int? ?? 0,
      pumpOn: (map['pumpOn'] as int? ?? 0) == 1,
      mode: map['mode'] as String? ?? 'auto',
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
