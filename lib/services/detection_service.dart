// services/detection_service.dart
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import '../models/driving_event.dart';
import 'mqtt_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio para detectar eventos de conducción basados en sensores
class DetectionService {
  // Singleton pattern
  static final DetectionService _instance = DetectionService._internal();
  factory DetectionService() => _instance;
  DetectionService._internal();

  // Servicio MQTT
  final MqttService _mqttService = MqttService();
  
  // Umbrales configurables
  double _hardBrakeThreshold = 30.0; // m/s²
  double _hardAccelThreshold = 30.0; // m/s²
  double _sharpTurnThreshold = 25.0; // m/s²
  double _speedLimit = 80.0; // km/h
  
  // Control de eventos para evitar spam
  DateTime? _lastHardBrakeEvent;
  DateTime? _lastHardAccelEvent;
  DateTime? _lastSharpTurnEvent;
  DateTime? _lastSpeedingEvent;
  final int _minEventIntervalMs = 3000; // 3 segundos entre eventos del mismo tipo
  
  // Estado de conexión MQTT
  bool _isMqttConnected = false;
  Function(bool)? _connectionCallback;
  
  // Historial de eventos
  final List<DrivingEvent> _events = [];
  
  /// Inicializa el servicio y conecta a MQTT
  Future<void> initialize() async {
    print('🚀 Inicializando DetectionService...');
    
    // Configurar callback de conexión MQTT
    _mqttService.onConnectionChanged = (isConnected) {
      _isMqttConnected = isConnected;
      _connectionCallback?.call(isConnected);
      print('📡 MQTT Estado: ${isConnected ? "Conectado" : "Desconectado"}');
    };
    
    // Intentar conectar a MQTT
    final connected = await _mqttService.connect();
    _isMqttConnected = connected;
    
    print('✅ DetectionService inicializado. MQTT: ${connected ? "OK" : "Offline"}');
  }
  
  /// Actualiza los umbrales de detección
  void updateThresholds({
    required double hardBrake,
    required double hardAccel,
    required double sharpTurn,
    required double speedLimit,
  }) {
    _hardBrakeThreshold = hardBrake;
    _hardAccelThreshold = hardAccel;
    _sharpTurnThreshold = sharpTurn;
    _speedLimit = speedLimit;
    
    print('⚙️ Umbrales actualizados:');
    print('   Hard Brake: $_hardBrakeThreshold m/s²');
    print('   Hard Accel: $_hardAccelThreshold m/s²');
    print('   Sharp Turn: $_sharpTurnThreshold m/s²');
    print('   Speed Limit: $_speedLimit km/h');
  }
  
  /// Detecta eventos basados en datos del acelerómetro
  String? detectEvents(AccelerometerEvent event) {
    final now = DateTime.now();
    
    // Detectar frenada brusca (aceleración negativa en Y)
    if (event.y < -_hardBrakeThreshold) {
      if (_canRegisterEvent(_lastHardBrakeEvent, now)) {
        _lastHardBrakeEvent = now;
        return 'hard_brake';
      }
    }
    
    // Detectar aceleración fuerte (aceleración positiva en Y)
    if (event.y > _hardAccelThreshold) {
      if (_canRegisterEvent(_lastHardAccelEvent, now)) {
        _lastHardAccelEvent = now;
        return 'hard_accel';
      }
    }
    
    // Detectar giro cerrado (aceleración lateral en X)
    if (event.x.abs() > _sharpTurnThreshold) {
      if (_canRegisterEvent(_lastSharpTurnEvent, now)) {
        _lastSharpTurnEvent = now;
        return 'sharp_turn';
      }
    }
    
    return null;
  }
  
  /// Verifica velocidad y detecta exceso
  String? checkSpeed(double speedKmh) {
    if (speedKmh > _speedLimit) {
      final now = DateTime.now();
      if (_canRegisterEvent(_lastSpeedingEvent, now)) {
        _lastSpeedingEvent = now;
        return 'speeding';
      }
    }
    return null;
  }
  
  /// Verifica si puede registrar un evento (evita spam)
  bool _canRegisterEvent(DateTime? lastEvent, DateTime now) {
    if (lastEvent == null) return true;
    final diff = now.difference(lastEvent).inMilliseconds;
    return diff >= _minEventIntervalMs;
  }
  
  /// Registra un evento de conducción
  Future<void> logEvent(
    String eventType,
    double accelX,
    double accelY,
    double accelZ,
    double latitude,
    double longitude,
    double speed,
  ) async {
    final event = DrivingEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: eventType,
      timestamp: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      speed: speed,
      accelX: accelX,
      accelY: accelY,
      accelZ: accelZ,
    );
    
    // Agregar al historial local
    _events.add(event);
    
    // Limitar historial a últimos 100 eventos
    if (_events.length > 100) {
      _events.removeAt(0);
    }
    
    print('📝 Evento registrado: $eventType');
    
    // Intentar enviar a MQTT si está conectado
    if (_isMqttConnected) {
      await _publishToMqtt(event);
    } else {
      print('📴 Evento guardado solo localmente (MQTT offline)');
    }
  }
  
  /// Publica evento a MQTT
  Future<void> _publishToMqtt(DrivingEvent event) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ No hay usuario autenticado para enviar a MQTT');
        return;
      }
      
      await _mqttService.publishEvent(
        userId: user.uid,
        eventType: event.type,
        accelX: event.accelX,
        accelY: event.accelY,
        accelZ: event.accelZ,
        latitude: event.latitude,
        longitude: event.longitude,
        speed: event.speed,
      );
      
      print('📤 Evento enviado a MQTT: ${event.type}');
    } catch (e) {
      print('❌ Error al enviar evento a MQTT: $e');
    }
  }
  
  /// Configura callback para cambios de conexión MQTT
  void setConnectionCallback(Function(bool) callback) {
    _connectionCallback = callback;
  }
  
  /// Obtiene el estado de conexión MQTT
  bool get isMqttConnected => _isMqttConnected;
  
  /// Obtiene el historial de eventos
  List<DrivingEvent> get events => List.unmodifiable(_events);
  
  /// Limpia el historial de eventos
  void clearEvents() {
    _events.clear();
    print('🗑️ Historial de eventos limpiado');
  }
  
  /// Obtiene estadísticas de eventos
  Map<String, int> getEventStatistics() {
    final stats = <String, int>{
      'hard_brake': 0,
      'hard_accel': 0,
      'sharp_turn': 0,
      'speeding': 0,
    };
    
    for (final event in _events) {
      stats[event.type] = (stats[event.type] ?? 0) + 1;
    }
    
    return stats;
  }
  
  /// Publica estadísticas a MQTT
  Future<void> publishStatistics() async {
    if (!_isMqttConnected) {
      print('📴 No se pueden publicar estadísticas (MQTT offline)');
      return;
    }
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final stats = getEventStatistics();
      
      await _mqttService.publishStats(
        userId: user.uid,
        totalEvents: _events.length,
        eventsByType: stats,
      );
      
      print('📊 Estadísticas publicadas a MQTT');
    } catch (e) {
      print('❌ Error al publicar estadísticas: $e');
    }
  }
  
  /// Reconecta a MQTT
  Future<bool> reconnectMqtt() async {
    print('🔄 Intentando reconectar a MQTT...');
    _mqttService.disconnect();
    await Future.delayed(const Duration(seconds: 1));
    return await _mqttService.connect();
  }
  
  /// Cierra conexiones y limpia recursos
  void dispose() {
    _mqttService.disconnect();
    _events.clear();
    print('🛑 DetectionService cerrado');
  }
}