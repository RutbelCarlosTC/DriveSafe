import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';
import '../models/driving_event.dart';
import 'mqtt_service.dart';
import 'data_service.dart';

/// Servicio encargado de la lógica de detección de eventos peligrosos
class DetectionService {
  final MqttService _mqttService = MqttService();
  final DataService _dataService = DataService();
  
  // Umbrales de detección (pueden ser configurables desde Settings)
  double hardBrakeThreshold = 30.0;
  double hardAccelThreshold = 30.0;
  double sharpTurnThreshold = 25.0;
  double speedLimitKmh = 80.0;

  String? _userId;
  DateTime? _lastEventTime;
  final int _minEventIntervalMs = 1000; // Mínimo 1 segundo entre eventos

  /// Inicializa el servicio de detección
  Future<void> initialize() async {
    // Obtener ID de usuario
    _userId = await _dataService.getUserId();
    if (_userId == null) {
      // Generar un ID único si no existe
      _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      await _dataService.saveUserId(_userId!);
    }
    
    // Conectar al broker MQTT (sin bloquear si falla)
    _mqttService.connect().catchError((error) {
      print('⚠️ MQTT no disponible, continuando en modo offline');
    });
  }

  /// Detecta eventos basándose en los datos del acelerómetro
  String? detectEvents(AccelerometerEvent event) {
    // Detectar frenada brusca (aceleración negativa fuerte en Y)
    if (event.y < -hardBrakeThreshold) {
      return 'Frenada Brusca';
    }
    
    // Detectar aceleración repentina (aceleración positiva fuerte en Y)
    if (event.y > hardAccelThreshold) {
      return 'Aceleración Repentina';
    }
    
    // Detectar giro fuerte (aceleración lateral fuerte en X)
    if (event.x.abs() > sharpTurnThreshold) {
      return 'Giro Fuerte';
    }
    
    return null;
  }

  /// Verifica si se está excediendo el límite de velocidad
  String? checkSpeed(double speedKmh) {
    if (speedKmh > speedLimitKmh) {
      return 'Exceso de Velocidad';
    }
    return null;
  }

  /// Registra el evento (MQTT + almacenamiento local)
  Future<void> logEvent(
    String eventType,
    double accelX,
    double accelY,
    double accelZ,
    double latitude,
    double longitude,
    double speed,
  ) async {
    // Filtrar eventos muy frecuentes
    final now = DateTime.now();
    if (_lastEventTime != null) {
      final diff = now.difference(_lastEventTime!).inMilliseconds;
      if (diff < _minEventIntervalMs) {
        // Ignorar evento si fue hace menos de 1 segundo
        return;
      }
    }
    _lastEventTime = now;

    print('=== Evento Detectado ===');
    print('Tipo: $eventType');
    print('Acelerómetro - X: $accelX, Y: $accelY, Z: $accelZ');
    print('GPS - Lat: $latitude, Lon: $longitude');
    print('Velocidad: $speed km/h');
    print('Timestamp: $now');
    print('========================');
    
    // Crear objeto DrivingEvent
    final event = DrivingEvent(
      id: 'evt_${now.millisecondsSinceEpoch}',
      type: eventType,
      timestamp: now,
      latitude: latitude,
      longitude: longitude,
      speed: speed,
      accelX: accelX,
      accelY: accelY,
      accelZ: accelZ,
    );
    
    // Guardar localmente
    await _dataService.saveEvent(event);
    
    // Enviar al broker MQTT solo si está conectado
    if (_mqttService.isConnected && _userId != null) {
      try {
        await _mqttService.publishEvent(
          userId: _userId!,
          eventType: eventType,
          accelX: accelX,
          accelY: accelY,
          accelZ: accelZ,
          latitude: latitude,
          longitude: longitude,
          speed: speed,
        );
      } catch (e) {
        print('⚠️ Error al publicar en MQTT: $e');
      }
    }
  }

  /// Actualiza los umbrales de detección
  void updateThresholds({
    double? hardBrake,
    double? hardAccel,
    double? sharpTurn,
    double? speedLimit,
  }) {
    if (hardBrake != null) hardBrakeThreshold = hardBrake;
    if (hardAccel != null) hardAccelThreshold = hardAccel;
    if (sharpTurn != null) sharpTurnThreshold = sharpTurn;
    if (speedLimit != null) speedLimitKmh = speedLimit;
  }

  /// Publica estadísticas periódicas
  Future<void> publishStats() async {
    if (!_mqttService.isConnected || _userId == null) return;
    
    final stats = await _dataService.getStats();
    final eventsByType = Map<String, int>.from(
      stats.map((key, value) => MapEntry(
        key,
        value is int ? value : 0,
      ))..remove('total')..remove('lastUpdate')
    );
    
    await _mqttService.publishStats(
      userId: _userId!,
      totalEvents: stats['total'] ?? 0,
      eventsByType: eventsByType,
    );
  }

  /// Desconecta del broker MQTT
  void disconnect() {
    _mqttService.disconnect();
  }

  /// Getter para estado de conexión MQTT
  bool get isMqttConnected => _mqttService.isConnected;

  /// Configura callback para cambios de conexión MQTT
  void setConnectionCallback(Function(bool) callback) {
    _mqttService.onConnectionChanged = callback;
  }
}