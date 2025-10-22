import 'package:flutter/material.dart';
import '../models/driving_event.dart';
import '../services/data_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DataService _dataService = DataService();
  List<DrivingEvent> _events = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, today, week, month

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    
    List<DrivingEvent> events;
    switch (_filter) {
      case 'today':
        events = await _dataService.getTodayEvents();
        break;
      case 'week':
        events = await _dataService.getWeekEvents();
        break;
      case 'month':
        events = await _dataService.getMonthEvents();
        break;
      default:
        events = await _dataService.getEvents(limit: 100);
    }
    
    setState(() {
      _events = events;
      _isLoading = false;
    });
  }

  Future<void> _clearAllEvents() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('¿Estás seguro de eliminar todos los eventos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dataService.clearEvents();
      _loadEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eventos eliminados')),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearAllEvents();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Eliminar todo'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            padding: const EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Todos',
                    isSelected: _filter == 'all',
                    onTap: () {
                      setState(() => _filter = 'all');
                      _loadEvents();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Hoy',
                    isSelected: _filter == 'today',
                    onTap: () {
                      setState(() => _filter = 'today');
                      _loadEvents();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Esta semana',
                    isSelected: _filter == 'week',
                    onTap: () {
                      setState(() => _filter = 'week');
                      _loadEvents();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Este mes',
                    isSelected: _filter == 'month',
                    onTap: () {
                      setState(() => _filter = 'month');
                      _loadEvents();
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // Lista de eventos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No hay eventos registrados',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadEvents,
                        child: ListView.builder(
                          itemCount: _events.length,
                          itemBuilder: (context, index) {
                            final event = _events[index];
                            return _EventCard(
                              event: event,
                              color: _getEventColor(event.type),
                              icon: _getEventIcon(event.type),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final DrivingEvent event;
  final Color color;
  final IconData icon;

  const _EventCard({
    required this.event,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          event.type,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${event.timestamp.toString().substring(0, 19)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Velocidad: ${event.speed.toStringAsFixed(1)} km/h',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(event.type),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DetailRow('Fecha', event.timestamp.toString().substring(0, 19)),
                      _DetailRow('Velocidad', '${event.speed.toStringAsFixed(1)} km/h'),
                      _DetailRow('Latitud', event.latitude.toStringAsFixed(6)),
                      _DetailRow('Longitud', event.longitude.toStringAsFixed(6)),
                      const Divider(),
                      const Text('Acelerómetro:', style: TextStyle(fontWeight: FontWeight.bold)),
                      _DetailRow('X', '${event.accelX.toStringAsFixed(2)} m/s²'),
                      _DetailRow('Y', '${event.accelY.toStringAsFixed(2)} m/s²'),
                      _DetailRow('Z', '${event.accelZ.toStringAsFixed(2)} m/s²'),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}