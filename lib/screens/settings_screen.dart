import 'package:flutter/material.dart';

/// Pantalla de Settings
/// 
/// TODO para el desarrollador:
/// - Configuración de umbrales de detección:
///   * Umbral de frenada brusca
///   * Umbral de aceleración repentina
///   * Umbral de giro fuerte
///   * Límite de velocidad
/// - Configuración de conexión MQTT:
///   * Servidor/broker
///   * Puerto
///   * Usuario/contraseña
///   * Tópicos
/// - Preferencias de notificaciones
/// - Gestión de perfil de usuario
/// - Opción de logout
/// - Exportar/importar configuración
/// - Información de la aplicación (versión, licencias)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Text(
          'Settings Screen\n\nPendiente de implementación',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}