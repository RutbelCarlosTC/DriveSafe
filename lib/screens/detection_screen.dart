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
  
  // Control de alerta visible
  bool _showAlert = false;
  String _currentAlertEvent = '';
  Timer? _alertTimer;

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
    
    // Mostrar alerta en la UI
    _showDangerousAlert(eventType);
    
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

  void _showDangerousAlert(String eventType) {
    _alertTimer?.cancel();
    
    setState(() {
      _showAlert = true;
      _currentAlertEvent = eventType;
    });
    
    _alertTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showAlert = false;
        });
      }
    });
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
    _alertTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Detección',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _isMqttConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isMqttConnected ? Colors.green : Colors.grey[400],
              size: 22,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // Velocímetro circular
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador vertical (simulando aguja)
                  Container(
                    width: 6,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _speed > 80 ? const Color(0xFFFF5757) : const Color(0xFFFF9F43),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Velocidad
                  Text(
                    '${_speed.toInt()}',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w300,
                      color: _speed > 80 ? const Color(0xFFFF5757) : Colors.black87,
                      height: 1,
                    ),
                  ),
                  const Text(
                    'km/h',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            const Text(
              'Velocidad actual',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black45,
                fontWeight: FontWeight.w400,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Alerta de conducción peligrosa
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _showAlert ? null : 0,
              curve: Curves.easeInOut,
              child: _showAlert
                  ? Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5757),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5757).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Conducción Peligrosa Detectada',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _currentAlertEvent,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            
            // Sección de Aceleración
            _buildMinimalSection(
              title: 'Aceleración',
              children: [
                _buildAccelCard('X', _accelX, const Color(0xFF4ECDC4)),
                const SizedBox(height: 12),
                _buildAccelCard('Y', _accelY, const Color(0xFFFF9F43)),
                const SizedBox(height: 12),
                _buildAccelCard('Z', _accelZ, const Color(0xFF95E1D3)),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Botón de control
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isDetecting ? _stopDetection : _startDetection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDetecting 
                      ? const Color(0xFFFF5757) 
                      : const Color(0xFF2E4374),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _isDetecting ? 'DETENER DETECCIÓN' : 'INICIAR DETECCIÓN',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Stats minimalistas
            if (_isDetecting)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('Eventos', '$_eventCount'),
                  Container(width: 1, height: 30, color: Colors.grey[200]),
                  _buildStatItem('Estado', _isMqttConnected ? 'Sync' : 'Local'),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMinimalSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
  
  Widget _buildAccelCard(String axis, double value, Color color) {
    final isHigh = value.abs() > 25;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHigh ? color.withOpacity(0.5) : Colors.grey[200]!,
          width: isHigh ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                axis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${value.toStringAsFixed(2)} m/s²',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isHigh ? color : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Eje $axis',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Barra de intensidad
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(2),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: (value.abs() / 40.0).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: isHigh ? const Color(0xFFFF5757) : color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}