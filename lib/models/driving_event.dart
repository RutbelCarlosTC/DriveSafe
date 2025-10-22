/// Modelo de datos para un evento de conducción
class DrivingEvent {
  final String id;
  final String type; // 'hard_brake', 'hard_accel', 'sharp_turn', 'speeding'
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speed;
  final double accelX;
  final double accelY;
  final double accelZ;

  DrivingEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'accelX': accelX,
      'accelY': accelY,
      'accelZ': accelZ,
    };
  }

  factory DrivingEvent.fromJson(Map<String, dynamic> json) {
    return DrivingEvent(
      id: json['id'],
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
      latitude: json['latitude'],
      longitude: json['longitude'],
      speed: json['speed'],
      accelX: json['accelX'],
      accelY: json['accelY'],
      accelZ: json['accelZ'],
    );
  }
}