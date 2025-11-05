import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

const MAPBOX_ACCESS_TOKEN =
    'pk.eyJ1IjoiZnJhbmtzamF2aWVydmlsY2FxdWlzcGUiLCJhIjoiY21obDcwcjR3MDA1NTJqcHZxYmg1ZnJpZyJ9.fmZzofFm535AG8TUP_ur_A';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  double _currentZoom = 18.0;
  LatLng? myPosition;
  bool isLoading = true;
  String currentSpeed = '0 km/h';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLocationUpdates();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Verificar si los servicios de ubicación están habilitados
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          isLoading = false;
        });
        _showLocationServiceDialog();
        return;
      }

      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            isLoading = false;
          });
          _showPermissionDeniedDialog();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          isLoading = false;
        });
        _showPermissionDeniedDialog();
        return;
      }

      // Obtener ubicación actual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        myPosition = LatLng(position.latitude, position.longitude);
        isLoading = false;
      });

      // Centrar el mapa en la ubicación actual
      if (myPosition != null) {
        _mapController.move(myPosition!, _currentZoom);
      }
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      setState(() {
        myPosition = LatLng(40.697488, -73.979681); // Ubicación por defecto
        isLoading = false;
      });
    }
  }

  void _startLocationUpdates() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Actualizar cada 10 metros
      ),
    ).listen((Position position) {
      setState(() {
        myPosition = LatLng(position.latitude, position.longitude);
        // Calcular velocidad en km/h
        currentSpeed = '${(position.speed * 3.6).toStringAsFixed(0)} km/h';
      });
    });
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Servicios de ubicación desactivados'),
        content: const Text(
            'Por favor, activa los servicios de ubicación para usar esta función.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permisos de ubicación denegados'),
        content: const Text(
            'Esta app necesita permisos de ubicación para funcionar correctamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(5.0, 25.0);
    });
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(5.0, 25.0);
    });
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _centerLocation() {
    if (myPosition != null) {
      _mapController.move(myPosition!, _currentZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Obteniendo ubicación...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (myPosition == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudo obtener la ubicación',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
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
              MarkerLayer(
                markers: [
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
                ],
              ),
            ],
          ),

          // Header superior
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
                        'Live Route',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          _showSettings(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Indicadores de velocidad y GPS
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _buildInfoCard(
                  icon: Icons.speed,
                  iconColor: Colors.cyan,
                  label: 'Velocidad',
                  value: currentSpeed,
                ),
                const SizedBox(width: 12),
                _buildInfoCard(
                  icon: Icons.gps_fixed,
                  iconColor: Colors.green,
                  label: 'GPS',
                  value: 'Conectado',
                ),
              ],
            ),
          ),

          // Botones de zoom y ubicación
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 150,
            child: Column(
              children: [
                _buildCircleButton(
                  icon: Icons.add,
                  onPressed: _zoomIn,
                ),
                const SizedBox(height: 8),
                _buildCircleButton(
                  icon: Icons.remove,
                  onPressed: _zoomOut,
                ),
                const SizedBox(height: 16),
                _buildCircleButton(
                  icon: Icons.my_location,
                  onPressed: _centerLocation,
                  color: Colors.blue,
                  iconColor: Colors.white,
                ),
              ],
            ),
          ),

          // Panel inferior con información de la ruta
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Indicador de arrastre
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Información de la ruta
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Ruta Actual',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const Text(
                            '12.5 km',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Actual → Aeropuerto',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            'falta 18 min',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Safety Score
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Puntuacion de seguridad',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const Text(
                            '78/100',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Botones de acción
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _showEndRouteDialog(context);
                              },
                              icon: const Icon(Icons.stop, size: 20),
                              label: const Text(
                                'Terminar Ruta',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E3A8A),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _shareRoute(context);
                              },
                              icon: const Icon(Icons.share, size: 20),
                              label: const Text(
                                'Share',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1E3A8A),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFF1E3A8A),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color color = Colors.white,
    Color iconColor = Colors.black87,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
      ),
    );
  }

  void _showEndRouteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar Ruta'),
        content:
            const Text('¿Estás seguro de que quieres finalizar esta ruta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
            child: const Text('Terminar Ruta'),
          ),
        ],
      ),
    );
  }

  void _shareRoute(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compartiendo ruta...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Configuración del Mapa',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Tipo de mapa'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.navigation),
              title: const Text('Opciones de navegación'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notificaciones'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}