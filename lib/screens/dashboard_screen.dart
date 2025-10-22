import 'package:flutter/material.dart';

/// Pantalla de Dashboard
/// 
/// TODO para el desarrollador:
/// - Mostrar estadísticas generales de conducción
/// - Gráficos de eventos por tipo (frenadas, aceleraciones, giros, velocidad)
/// - Resumen de viajes recientes
/// - Puntuación de conducción
/// - Integrar con el servicio de datos (ver services/data_service.dart)
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: const Center(
        child: Text(
          'Dashboard Screen\n\nPendiente de implementación',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}