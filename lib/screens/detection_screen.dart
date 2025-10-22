import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math';
import '../services/detection_service.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({Key? key}) : super(key: key);

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  final DetectionService _detectionService = DetectionService();
  bool _isDetecting = false;
  bool _isMqttConnected = false;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<Position>? _positionSubscription;
  
  // Datos del acelerómetro
  double _accelX = 0.0;
  double _accelY = 0.0;
  double _accelZ = 0.0;
  
  // Datos GPS
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _speed = 0.0;
  
  // Eventos detectados
  String _lastEvent = 'Ninguno';
  int _eventCount = 0;
  
  // Control de eventos
  DateTime? _lastEventTime;
  final int _minEventIntervalMs = 1000; // 1 segundo entre eventos en UI

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeService();
  }

  Future<void> _requestPermissions() async {
    await Geolocator.requestPermission();
  }

  Future<void> _initializeService() async {
    await _detectionService.initialize();
    
    // Configurar callback de conexión MQTT
    _detectionService.setConnectionCallback((isConnected) {
      if (mounted) {
        setState(() {
          _isMqttConnected = isConnected;
        });
      }
    });
    
    // Actualizar estado inicial de MQTT
    setState(() {
      _isMqttConnected = _detectionService.isMqttConnected;
    });
    
    // Ajustar umbrales para tu dispositivo
    _detectionService.updateThresholds(
      hardBrake: 30.0,
      hardAccel: 30.0,
      sharpTurn: 25.0,
      speedLimit: 80.0,
    );
  }

  void _startDetection() async {
    setState(() {
      _isDetecting = true;
      _eventCount = 0;
      _lastEvent = 'Iniciando...';
      _lastEventTime = null;
    });

    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _accelX = event.x;
        _accelY = event.y;
        _accelZ = event.z;
      });
      
      final detectedEvent = _detectionService.detectEvents(event);
      if (detectedEvent != null) {
        _registerEvent(detectedEvent);
      }
    });

    LocationSettings locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings
    ).listen((Position position) {
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _speed = position.speed * 3.6;
      });
      
      final speedEvent = _detectionService.checkSpeed(_speed);
      if (speedEvent != null) {
        _registerEvent(speedEvent);
      }
    });
  }

  void _registerEvent(String eventType) {
    // Filtrar eventos muy frecuentes en la UI también
    final now = DateTime.now();
    if (_lastEventTime != null) {
      final diff = now.difference(_lastEventTime!).inMilliseconds;
      if (diff < _minEventIntervalMs) {
        // Ignorar evento en la UI si fue hace menos de 1 segundo
        return;
      }
    }
    _lastEventTime = now;
    
    setState(() {
      _lastEvent = '$eventType - ${now.toString().substring(11, 19)}';
      _eventCount++;
    });
    
    // Registrar evento en el servicio (esto también tiene su propio filtro)
    _detectionService.logEvent(
      eventType, 
      _accelX, 
      _accelY, 
      _accelZ, 
      _latitude, 
      _longitude, 
      _speed
    );
  }

  void _stopDetection() {
    setState(() {
      _isDetecting = false;
      _lastEvent = 'Detenido';
    });
    
    _accelerometerSubscription?.cancel();
    _positionSubscription?.cancel();
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection'),
        actions: [
          // Indicador de estado MQTT
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Icon(
                  _isMqttConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _isMqttConnected ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _isMqttConnected ? 'MQTT' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isMqttConnected ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isDetecting ? _stopDetection : _startDetection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDetecting ? Colors.red : Colors.green,
                ),
                child: Text(
                  _isDetecting ? 'DETENER DETECCIÓN' : 'INICIAR DETECCIÓN',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _isDetecting ? 'DETECTANDO' : 'INACTIVO',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _isDetecting ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Eventos detectados: $_eventCount'),
                    Text('Último evento: $_lastEvent'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isMqttConnected ? Icons.wifi : Icons.wifi_off,
                          size: 16,
                          color: _isMqttConnected ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isMqttConnected ? 'Sincronizando' : 'Solo local',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isMqttConnected ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Acelerómetro:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('X: ${_accelX.toStringAsFixed(2)} m/s²'),
                    Text('Y: ${_accelY.toStringAsFixed(2)} m/s²'),
                    Text('Z: ${_accelZ.toStringAsFixed(2)} m/s²'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_accelY.abs() / 40.0).clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _accelY.abs() > 30 ? Colors.red : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GPS:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Latitud: ${_latitude.toStringAsFixed(6)}'),
                    Text('Longitud: ${_longitude.toStringAsFixed(6)}'),
                    Text('Velocidad: ${_speed.toStringAsFixed(1)} km/h'),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // Información adicional
            Text(
              'Umbral: Aceleración ±30 m/s², Giros ±25 m/s²',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}