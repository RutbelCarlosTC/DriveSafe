import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/detection_service.dart';
import '../services/mqtt_service.dart';


///TODO
///+ Verificar el broker y su funcionamiento 
///+ boton log out
///+ guardar configuraciones con shared preferences

/// Pantalla de configuración de la aplicación
/// Permite ajustar umbrales de detección y configuración MQTT
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Servicios
  final DetectionService _detectionService = DetectionService();
  final MqttService _mqttService = MqttService();
  
  // Umbrales de detección (valores por defecto)
  double _hardBrakeThreshold = 30.0; // m/s²
  double _hardAccelThreshold = 30.0; // m/s²
  double _sharpTurnThreshold = 25.0; // m/s²
  double _speedLimit = 80.0; // km/h
  
  // Configuración MQTT
  final TextEditingController _brokerController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  
  // Estado
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTestingConnection = false;
  String? _connectionMessage;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  /// Carga la configuración guardada
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        // Cargar umbrales
        _hardBrakeThreshold = prefs.getDouble('hardBrakeThreshold') ?? 30.0;
        _hardAccelThreshold = prefs.getDouble('hardAccelThreshold') ?? 30.0;
        _sharpTurnThreshold = prefs.getDouble('sharpTurnThreshold') ?? 25.0;
        _speedLimit = prefs.getDouble('speedLimit') ?? 80.0;
        
        // Cargar configuración MQTT
        _brokerController.text = prefs.getString('mqttBroker') ?? 'broker.hivemq.com';
        _topicController.text = prefs.getString('mqttTopic') ?? 'driving/events';
        
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar configuración: $e');
      setState(() => _isLoading = false);
    }
  }
  
  /// Guarda la configuración actual
  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Guardar umbrales
      await prefs.setDouble('hardBrakeThreshold', _hardBrakeThreshold);
      await prefs.setDouble('hardAccelThreshold', _hardAccelThreshold);
      await prefs.setDouble('sharpTurnThreshold', _sharpTurnThreshold);
      await prefs.setDouble('speedLimit', _speedLimit);
      
      // Guardar configuración MQTT
      await prefs.setString('mqttBroker', _brokerController.text);
      await prefs.setString('mqttTopic', _topicController.text);
      
      // Actualizar umbrales en el servicio de detección
      _detectionService.updateThresholds(
        hardBrake: _hardBrakeThreshold,
        hardAccel: _hardAccelThreshold,
        sharpTurn: _sharpTurnThreshold,
        speedLimit: _speedLimit,
      );
      
      // Mostrar confirmación
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Configuración guardada'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }
  
  /// Prueba la conexión MQTT
  Future<void> _testMqttConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionMessage = null;
    });
    
    try {
      final connected = await _mqttService.connect();
      
      setState(() {
        if (connected) {
          _connectionMessage = '✅ Conexión exitosa al broker MQTT';
        } else {
          _connectionMessage = '❌ No se pudo conectar al broker';
        }
      });
      
      // Desconectar después de probar
      await Future.delayed(const Duration(seconds: 2));
      _mqttService.disconnect();
      
    } catch (e) {
      setState(() {
        _connectionMessage = '❌ Error: $e';
      });
    } finally {
      setState(() => _isTestingConnection = false);
    }
  }
  
  /// Cierra sesión del usuario
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
  
  @override
  void dispose() {
    _brokerController.dispose();
    _topicController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: _isSaving 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, color: Colors.blue),
            onPressed: _isSaving ? null : _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== DETECTION THRESHOLDS ==========
            _buildSectionCard(
              icon: Icons.sensors,
              iconColor: Colors.blue,
              title: 'Limites de Detección',
              children: [
                _buildSliderSetting(
                  label: 'Frenada Brusca',
                  value: _hardBrakeThreshold,
                  min: 10.0,
                  max: 50.0,
                  divisions: 40,
                  unit: 'm/s²',
                  onChanged: (value) {
                    setState(() => _hardBrakeThreshold = value);
                  },
                ),
                const SizedBox(height: 16),
                _buildSliderSetting(
                  label: 'Aceleración Brusca',
                  value: _hardAccelThreshold,
                  min: 10.0,
                  max: 50.0,
                  divisions: 40,
                  unit: 'm/s²',
                  onChanged: (value) {
                    setState(() => _hardAccelThreshold = value);
                  },
                ),
                const SizedBox(height: 16),
                _buildSliderSetting(
                  label: 'Giro Cerrado',
                  value: _sharpTurnThreshold,
                  min: 10.0,
                  max: 40.0,
                  divisions: 30,
                  unit: 'm/s²',
                  onChanged: (value) {
                    setState(() => _sharpTurnThreshold = value);
                  },
                ),
                const SizedBox(height: 16),
                _buildSliderSetting(
                  label: 'Límite de Velocidad excedida',
                  value: _speedLimit,
                  min: 40.0,
                  max: 120.0,
                  divisions: 80,
                  unit: 'km/h',
                  onChanged: (value) {
                    setState(() => _speedLimit = value);
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // ========== MQTT CONFIGURATION ==========
            _buildSectionCard(
              icon: Icons.router,
              iconColor: Colors.deepPurple,
              title: 'MQTT Configuration',
              children: [
                _buildTextField(
                  controller: _brokerController,
                  label: 'MQTT Broker',
                  hint: 'broker.hivemq.com',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _topicController,
                  label: 'MQTT Topic',
                  hint: 'driving/events',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isTestingConnection ? null : _testMqttConnection,
                    icon: _isTestingConnection
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.power, color: Colors.white),
                    label: Text(
                      _isTestingConnection ? 'Testing...' : 'Test Connection',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E4374),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (_connectionMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _connectionMessage!.contains('✅')
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _connectionMessage!.contains('✅')
                            ? Colors.green
                            : Colors.red,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _connectionMessage!,
                      style: TextStyle(
                        color: _connectionMessage!.contains('✅')
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 20),
            
            // ========== ACCOUNT SECTION ==========
            _buildSectionCard(
              icon: Icons.person,
              iconColor: Colors.orange,
              title: 'Account',
              children: [
                ListTile(
                  leading: const Icon(Icons.email, color: Colors.grey),
                  title: const Text('Email'),
                  subtitle: Text(
                    FirebaseAuth.instance.currentUser?.email ?? 'No email',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                  onTap: _logout,
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // ========== APP INFO ==========
            Center(
              child: Column(
                children: [
                  Text(
                    'Driving Monitor v1.0.0',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '© 2024 - All rights reserved',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 10,
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
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
  
  /// Widget para un slider de configuración
  Widget _buildSliderSetting({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    final percentage = ((value - min) / (max - min) * 100).round();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            Text(
              '${value.toStringAsFixed(0)} $unit',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.blue,
            inactiveTrackColor: Colors.grey[300],
            thumbColor: Colors.blue,
            overlayColor: Colors.blue.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            trackHeight: 4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
  
  /// Widget para un campo de texto
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}