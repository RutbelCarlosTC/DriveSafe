// services/detection_service.dart (ACTUALIZADO)
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import '../models/driving_event.dart';
import 'mqtt_service.dart';
import 'data_service.dart';
import 'firebase_service.dart'; // 👈 NUEVO
import 'package:firebase_auth/firebase_auth.dart';

class DetectionService {
  static final DetectionService _instance = DetectionService._internal();
  factory DetectionService() => _instance;
  DetectionService._internal();

  final MqttService _mqttService = MqttService();
  final DataService _dataService = DataService();
  final FirebaseService _firebaseService = FirebaseService(); // 👈 NUEVO
  
  double _hardBrakeThreshold = 30.0;
  double _hardAccelThreshold = 30.0;
  double _sharpTurnThreshold = 25.0;
  double _speedLimit = 80.0;
  
  DateTime? _lastHardBrakeEvent;
  DateTime? _lastHardAccelEvent;
  DateTime? _lastSharpTurnEvent;
  DateTime? _lastSpeedingEvent;
  final int _minEventIntervalMs = 3000;
  
  bool _isMqttConnected = false;
  Function(bool)? _connectionCallback;
  
  final List<DrivingEvent> _events = [];

  Future<void> initialize() async {
    print('🚀 Inicializando DetectionService...');
    
    _mqttService.onConnectionChanged = (isConnected) {
      _isMqttConnected = isConnected;
      _connectionCallback?.call(isConnected);
      print('📡 MQTT Estado: ${isConnected ? "Conectado" : "Desconectado"}');
    };
    
    final connected = await _mqttService.connect();
    _isMqttConnected = connected;
    
    // 👇 NUEVA: Sincronización automática al iniciar
    await _firebaseService.syncPendingEvents();
    
    print('✅ DetectionService inicializado');
  }
  
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
  }
  
  String? detectEvents(AccelerometerEvent event) {
    final now = DateTime.now();
    
    if (event.y < -_hardBrakeThreshold) {
      if (_canRegisterEvent(_lastHardBrakeEvent, now)) {
        _lastHardBrakeEvent = now;
        return 'Frenada Brusca';
      }
    }
    
    if (event.y > _hardAccelThreshold) {
      if (_canRegisterEvent(_lastHardAccelEvent, now)) {
        _lastHardAccelEvent = now;
        return 'Aceleración Repentina';
      }
    }
    
    if (event.x.abs() > _sharpTurnThreshold) {
      if (_canRegisterEvent(_lastSharpTurnEvent, now)) {
        _lastSharpTurnEvent = now;
        return 'Giro Fuerte';
      }
    }
    
    return null;
  }
  
  String? checkSpeed(double speedKmh) {
    if (speedKmh > _speedLimit) {
      final now = DateTime.now();
      if (_canRegisterEvent(_lastSpeedingEvent, now)) {
        _lastSpeedingEvent = now;
        return 'Exceso de Velocidad';
      }
    }
    return null;
  }
  
  bool _canRegisterEvent(DateTime? lastEvent, DateTime now) {
    if (lastEvent == null) return true;
    final diff = now.difference(lastEvent).inMilliseconds;
    return diff >= _minEventIntervalMs;
  }
  
  /// 👇 MÉTODO ACTUALIZADO con sincronización a Firebase
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
    
    _events.add(event);
    if (_events.length > 100) {
      _events.removeAt(0);
    }
    
    print('📝 Evento registrado: $eventType');
    
    // 1️⃣ Guardar en SQLite (siempre)
    await _dataService.saveEvent(event);
    
    // 2️⃣ Intentar guardar en Firebase
    final savedToCloud = await _firebaseService.saveEventToCloud(event);
    
    if (savedToCloud) {
      print('☁️ Evento sincronizado con Firebase');
    } else {
      print('📴 Evento guardado solo localmente (se sincronizará después)');
    }
    
    // 3️⃣ Publicar a MQTT si está conectado
    if (_isMqttConnected) {
      await _publishToMqtt(event);
    }
  }
  
  Future<void> _publishToMqtt(DrivingEvent event) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
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
  
  void setConnectionCallback(Function(bool) callback) {
    _connectionCallback = callback;
  }
  
  bool get isMqttConnected => _isMqttConnected;
  List<DrivingEvent> get events => List.unmodifiable(_events);
  
  void clearEvents() {
    _events.clear();
    print('🗑️ Historial de eventos limpiado');
  }
  
  Map<String, int> getEventStatistics() {
    final stats = <String, int>{
      'Frenada Brusca': 0,
      'Aceleración Repentina': 0,
      'Giro Fuerte': 0,
      'Exceso de Velocidad': 0,
    };
    
    for (final event in _events) {
      stats[event.type] = (stats[event.type] ?? 0) + 1;
    }
    
    return stats;
  }
  
  Future<void> publishStatistics() async {
    if (!_isMqttConnected) return;
    
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
  
  Future<bool> reconnectMqtt() async {
    print('🔄 Intentando reconectar a MQTT...');
    _mqttService.disconnect();
    await Future.delayed(const Duration(seconds: 1));
    return await _mqttService.connect();
  }
  
  void dispose() {
    _mqttService.disconnect();
    _events.clear();
    print('🛑 DetectionService cerrado');
  }
}