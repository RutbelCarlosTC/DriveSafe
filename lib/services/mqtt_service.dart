//services/mqtt_service.dart
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';
import 'dart:math';

/// Servicio para gestionar la conexión MQTT con HiveMQ
class MqttService {
  MqttServerClient? _client;
  bool _isConnected = false;
  
  // Callback para notificar cambios de estado
  Function(bool)? onConnectionChanged;
  
  // Genera un ID único para el cliente
  String _generateClientId() {
    final random = Random();
    return 'flutter_driving_${random.nextInt(100000)}';
  }

  /// Conecta al broker MQTT de HiveMQ
  Future<bool> connect() async {
    try {
      final clientId = _generateClientId();
      _client = MqttServerClient('broker.hivemq.com', clientId);
      _client!.port = 1883;
      _client!.logging(on: false);
      _client!.keepAlivePeriod = 20;
      _client!.autoReconnect = true;
      _client!.connectTimeoutPeriod = 5000; // 5 segundos timeout
      
      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);
      
      _client!.connectionMessage = connMessage;

      // Configurar callbacks
      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onSubscribed = _onSubscribed;

      print('🔄 Intentando conectar a MQTT...');
      await _client!.connect();
      
      if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
        print('✅ Conectado al broker MQTT HiveMQ');
        _isConnected = true;
        onConnectionChanged?.call(true);
        return true;
      }
      
      print('⚠️ No se pudo conectar al broker MQTT');
      return false;
    } catch (e) {
      print('❌ Error al conectar con MQTT: $e');
      _isConnected = false;
      onConnectionChanged?.call(false);
      return false;
    }
  }

  /// Desconecta del broker MQTT
  void disconnect() {
    if (_client != null) {
      _client!.disconnect();
      _isConnected = false;
      onConnectionChanged?.call(false);
      print('🔌 Desconectado del broker MQTT');
    }
  }

  /// Publica un evento de conducción
  Future<void> publishEvent({
    required String userId,
    required String eventType,
    required double accelX,
    required double accelY,
    required double accelZ,
    required double latitude,
    required double longitude,
    required double speed,
  }) async {
    if (!_isConnected || _client == null) {
      print('⚠️ No conectado al broker MQTT');
      return;
    }

    try {
      final topic = 'driving/events/$userId';
      
      final payload = {
        'userId': userId,
        'eventType': eventType,
        'timestamp': DateTime.now().toIso8601String(),
        'accelerometer': {
          'x': accelX,
          'y': accelY,
          'z': accelZ,
        },
        'gps': {
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed,
        },
      };

      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(payload));

      _client!.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      print('📤 Evento publicado: $eventType');
    } catch (e) {
      print('❌ Error al publicar evento: $e');
    }
  }

  /// Suscribe a un tópico específico
  void subscribe(String topic) {
    if (_client == null || !_isConnected) return;
    
    _client!.subscribe(topic, MqttQos.atLeastOnce);
    print('📥 Suscrito a: $topic');
  }

  /// Callbacks de eventos MQTT
  void _onConnected() {
    print('✅ Callback: Conectado');
    _isConnected = true;
    onConnectionChanged?.call(true);
  }

  void _onDisconnected() {
    print('🔌 Callback: Desconectado');
    _isConnected = false;
    onConnectionChanged?.call(false);
  }

  void _onSubscribed(String topic) {
    print('📥 Suscrito exitosamente a: $topic');
  }

  /// Getter para verificar el estado de conexión
  bool get isConnected => _isConnected;

  /// Publica estadísticas de conducción periódicas
  Future<void> publishStats({
    required String userId,
    required int totalEvents,
    required Map<String, int> eventsByType,
  }) async {
    if (!_isConnected || _client == null) return;

    try {
      final topic = 'driving/stats/$userId';
      
      final payload = {
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'totalEvents': totalEvents,
        'eventsByType': eventsByType,
      };

      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(payload));

      _client!.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      print('📊 Estadísticas publicadas');
    } catch (e) {
      print('❌ Error al publicar estadísticas: $e');
    }
  }
}