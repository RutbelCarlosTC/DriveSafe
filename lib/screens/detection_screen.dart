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
  final int _minEventIntervalMs = 1000;

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
    
    _detectionService.setConnectionCallback((isConnected) {
      if (mounted) {
        setState(() {
          _isMqttConnected = isConnected;
        });
      }
    });
    
    setState(() {
      _isMqttConnected = _detectionService.isMqttConnected;
    });
    
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
    final now = DateTime.now();
    if (_lastEventTime != null) {
      final diff = now.difference(_lastEventTime!).inMilliseconds;
      if (diff < _minEventIntervalMs) {
        return;
      }
    }
    _lastEventTime = now;
    
    setState(() {
      _lastEvent = '$eventType - ${now.toString().substring(11, 19)}';
      _eventCount++;
    });
    
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Detection',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isMqttConnected 
                  ? Colors.green.withOpacity(0.1) 
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isMqttConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _isMqttConnected ? Colors.green : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  _isMqttConnected ? 'MQTT' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isMqttConnected ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ========== BOTÓN PRINCIPAL ==========
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _isDetecting ? _stopDetection : _startDetection,
                icon: Icon(
                  _isDetecting ? Icons.stop : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
                label: Text(
                  _isDetecting ? 'DETENER DETECCIÓN' : 'INICIAR DETECCIÓN',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDetecting 
                      ? Colors.red 
                      : const Color(0xFF2E4374),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // ========== ESTADO DE DETECCIÓN ==========
            _buildSectionCard(
              icon: _isDetecting ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              iconColor: _isDetecting ? Colors.green : Colors.grey,
              title: 'Estado',
              children: [
                _buildStatusRow(
                  label: 'Estado actual',
                  value: _isDetecting ? 'DETECTANDO' : 'INACTIVO',
                  valueColor: _isDetecting ? Colors.green : Colors.grey,
                  isBold: true,
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  label: 'Eventos detectados',
                  value: '$_eventCount',
                  valueColor: Colors.blue,
                ),
                const SizedBox(height: 12),
                _buildStatusRow(
                  label: 'Último evento',
                  value: _lastEvent,
                  valueColor: Colors.black87,
                  isMultiline: true,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isMqttConnected 
                        ? Colors.green.shade50 
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isMqttConnected 
                          ? Colors.green.shade200 
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isMqttConnected ? Icons.sync : Icons.sync_disabled,
                        size: 20,
                        color: _isMqttConnected ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isMqttConnected ? 'Sincronizando con servidor' : 'Guardando solo localmente',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _isMqttConnected ? Colors.green.shade800 : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // ========== ACELERÓMETRO ==========
            _buildSectionCard(
              icon: Icons.speed,
              iconColor: Colors.blue,
              title: 'Acelerómetro',
              children: [
                _buildSensorRow(
                  label: 'Eje X',
                  value: _accelX,
                  unit: 'm/s²',
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                _buildSensorRow(
                  label: 'Eje Y',
                  value: _accelY,
                  unit: 'm/s²',
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                _buildSensorRow(
                  label: 'Eje Z',
                  value: _accelZ,
                  unit: 'm/s²',
                  color: Colors.purple,
                ),
                const SizedBox(height: 16),
                // Barra de progreso de aceleración Y
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Intensidad (Eje Y)',
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        Text(
                          '${(_accelY.abs() / 40.0 * 100).round()}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _accelY.abs() > 30 ? Colors.red : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_accelY.abs() / 40.0).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _accelY.abs() > 30 ? Colors.red : Colors.blue,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // ========== GPS ==========
            _buildSectionCard(
              icon: Icons.location_on,
              iconColor: Colors.deepOrange,
              title: 'GPS',
              children: [
                _buildGpsRow(
                  icon: Icons.my_location,
                  label: 'Latitud',
                  value: _latitude.toStringAsFixed(6),
                ),
                const SizedBox(height: 12),
                _buildGpsRow(
                  icon: Icons.place,
                  label: 'Longitud',
                  value: _longitude.toStringAsFixed(6),
                ),
                const SizedBox(height: 12),
                _buildGpsRow(
                  icon: Icons.speed,
                  label: 'Velocidad',
                  value: '${_speed.toStringAsFixed(1)} km/h',
                  valueColor: _speed > 80 ? Colors.red : Colors.green,
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // ========== INFORMACIÓN ==========
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Umbrales: Aceleración ±30 m/s² • Giros ±25 m/s² • Velocidad 80 km/h',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  /// Widget para una tarjeta de sección
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
  
  /// Widget para fila de estado
  Widget _buildStatusRow({
    required String label,
    required String value,
    required Color valueColor,
    bool isBold = false,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
  
  /// Widget para fila de sensor
  Widget _buildSensorRow({
    required String label,
    required double value,
    required String unit,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)} $unit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
  
  /// Widget para fila de GPS
  Widget _buildGpsRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.deepOrange.shade300),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}