import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/driving_event.dart';

const MAPBOX_ACCESS_TOKEN =
    'pk.eyJ1IjoiZnJhbmtzamF2aWVydmlsY2FxdWlzcGUiLCJhIjoiY21obDcwcjR3MDA1NTJqcHZxYmg1ZnJpZyJ9.fmZzofFm535AG8TUP_ur_A';

class MapEventsScreen extends StatefulWidget {
  const MapEventsScreen({super.key});

  @override
  State<MapEventsScreen> createState() => _MapEventsScreenState();
}

class _MapEventsScreenState extends State<MapEventsScreen> {
  final MapController _mapController = MapController();
  double _currentZoom = 15.0;
  LatLng? myPosition;
  bool isLoading = true;
  
  // Eventos desde Firestore
  List<DrivingEvent> _events = [];
  StreamSubscription<QuerySnapshot>? _eventsSubscription;
  bool showEvents = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLocationUpdates(); // Actualizar ubicación en tiempo real
    _listenToFirestoreEvents();
  }

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    super.dispose();
  }

  void _listenToFirestoreEvents() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ No hay usuario autenticado');
      return;
    }

    print('🔥 Cargando eventos desde Firestore...');
    
    _eventsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('events')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _events = snapshot.docs
              .map((doc) {
                try {
                  return DrivingEvent.fromJson(doc.data());
                } catch (e) {
                  print('Error al parsear evento: $e');
                  return null;
                }
              })
              .whereType<DrivingEvent>()
              .toList();
        });
        print('📍 ${_events.length} eventos cargados');
        
        // Ajustar vista para mostrar todos los eventos
        if (_events.isNotEmpty && myPosition != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _fitAllEvents();
            }
          });
        }
      }
    }, onError: (error) {
      print('❌ Error: $error');
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { isLoading = false; });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || 
          permission == LocationPermission.denied) {
        setState(() { isLoading = false; });
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      
      if (mounted) {
        setState(() {
          myPosition = LatLng(position.latitude, position.longitude);
          isLoading = false;
        });
        _mapController.move(myPosition!, _currentZoom);
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        setState(() {
          myPosition = LatLng(-16.409047, -71.537451); // Arequipa
          isLoading = false;
        });
      }
    }
  }

  // Actualizar ubicación en tiempo real
  void _startLocationUpdates() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Actualizar cada 10 metros
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          myPosition = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  // Centrar mapa en ubicación actual
  void _centerOnMyLocation() {
    if (myPosition != null) {
      _mapController.move(myPosition!, 18.0);
    }
  }

  void _fitAllEvents() {
    if (_events.isEmpty) return;

    double minLat = _events.first.latitude;
    double maxLat = _events.first.latitude;
    double minLng = _events.first.longitude;
    double maxLng = _events.first.longitude;

    for (var event in _events) {
      if (event.latitude < minLat) minLat = event.latitude;
      if (event.latitude > maxLat) maxLat = event.latitude;
      if (event.longitude < minLng) minLng = event.longitude;
      if (event.longitude > maxLng) maxLng = event.longitude;
    }

    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  Color _getEventColor(String eventType) {
    switch (eventType) {
      case 'Frenada Brusca':
        return Colors.red;
      case 'Aceleración Repentina':
        return Colors.orange;
      case 'Giro Fuerte':
        return Colors.blue;
      case 'Exceso de Velocidad':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'Frenada Brusca':
        return Icons.warning;
      case 'Aceleración Repentina':
        return Icons.speed;
      case 'Giro Fuerte':
        return Icons.turn_right;
      case 'Exceso de Velocidad':
        return Icons.speed;
      default:
        return Icons.info;
    }
  }

  void _showEventDetails(DrivingEvent event) {
    final color = _getEventColor(event.type);
    final icon = _getEventIcon(event.type);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(event.type, style: const TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Velocidad', '${event.speed.toStringAsFixed(1)} km/h'),
            _buildDetailRow('Fecha', event.timestamp.toString().substring(0, 16)),
            _buildDetailRow('Coordenadas',
                '${event.latitude.toStringAsFixed(5)}, ${event.longitude.toStringAsFixed(5)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _mapController.move(LatLng(event.latitude, event.longitude), 18.0);
            },
            child: const Text('Ir al punto'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (myPosition == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text('No se pudo obtener la ubicación'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Mapa
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: myPosition!,
              initialZoom: _currentZoom,
              minZoom: 5,
              maxZoom: 25,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}',
                additionalOptions: const {
                  'accessToken': MAPBOX_ACCESS_TOKEN,
                  'id': 'mapbox/streets-v12',
                },
              ),
              // Marcadores
              if (showEvents)
                MarkerLayer(
                  markers: [
                    // Ubicación actual
                    Marker(
                      point: myPosition!,
                      width: 60,
                      height: 60,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blueAccent,
                        size: 45,
                      ),
                    ),
                    // Eventos
                    ..._events.map((event) {
                      final color = _getEventColor(event.type);
                      final icon = _getEventIcon(event.type);
                      
                      return Marker(
                        point: LatLng(event.latitude, event.longitude),
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () => _showEventDetails(event),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: Colors.white, size: 24),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
            ],
          ),

          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Mapa de Eventos',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        '${_events.length} eventos',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Botones de zoom
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    _currentZoom = (_currentZoom + 1).clamp(5.0, 25.0);
                    _mapController.move(_mapController.camera.center, _currentZoom);
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    _currentZoom = (_currentZoom - 1).clamp(5.0, 25.0);
                    _mapController.move(_mapController.camera.center, _currentZoom);
                  },
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'fit_all',
                  onPressed: _fitAllEvents,
                  child: const Icon(Icons.fit_screen),
                ),
                const SizedBox(height: 16),
                // Botón para centrar en ubicación actual
                FloatingActionButton.small(
                  heroTag: 'my_location',
                  backgroundColor: Colors.blue,
                  onPressed: _centerOnMyLocation,
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
