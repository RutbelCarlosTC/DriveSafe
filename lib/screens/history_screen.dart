import 'package:flutter/material.dart';
import '../models/driving_event.dart';
import '../services/data_service.dart';
import '../services/firebase_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DataService _dataService = DataService();
  final FirebaseService _firebaseService = FirebaseService();
  
  List<DrivingEvent> _events = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _filter = 'all';
  String _syncMessage = '';

  @override
  void initState() {
    super.initState();
    _setupSyncCallbacks();
    _loadEvents();
  }

  void _setupSyncCallbacks() {
    _firebaseService.onSyncStatusChanged = (isSyncing) {
      if (mounted) {
        setState(() {
          _isSyncing = isSyncing;
        });
      }
    };

    _firebaseService.onSyncMessage = (message) {
      if (mounted) {
        setState(() {
          _syncMessage = message;
        });
      }
    };
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

  Future<void> _syncWithCloud() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = 'Sincronizando...';
    });

    try {
      final isOnline = await _firebaseService.isOnline();
      
      if (!isOnline) {
        _showSnackBar('Sin conexión a internet', Colors.orange);
        return;
      }

      await _firebaseService.fullSync();
      await _loadEvents();
      
      _showSnackBar('✅ Sincronización completada', Colors.green);
      
    } catch (e) {
      print('Error en sincronización: $e');
      _showSnackBar('❌ Error al sincronizar', Colors.red);
    } finally {
      setState(() {
        _isSyncing = false;
        _syncMessage = '';
      });
    }
  }

  Future<void> _clearAllEvents() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Confirmar eliminación'),
        content: const Text(
          '¿Eliminar eventos localmente y en la nube?\n\n'
          'Esta acción no se puede deshacer.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Eliminar todo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      
      await _dataService.clearEvents();
      await _firebaseService.clearCloudEvents();
      
      _loadEvents();
      _showSnackBar('🗑️ Todos los eventos eliminados', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showCloudStats() async {
    final stats = await _firebaseService.getCloudStats();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Estadísticas en la Nube'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow(
                icon: Icons.event,
                label: 'Total de eventos',
                value: '${stats['totalEvents'] ?? 0}',
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                'Por tipo:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...((stats['eventsByType'] as Map<String, int>?) ?? {}).entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _getEventColor(entry.key),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(entry.key, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (stats['lastSync'] != null) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.update, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Última sincronización:\n${stats['lastSync']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
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
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'History',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        actions: [
          // Botón de sincronización
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                  : const Icon(Icons.cloud_sync, color: Colors.blue),
              onPressed: _isSyncing ? null : _syncWithCloud,
              tooltip: 'Sincronizar con la nube',
            ),
          ),
          // Menú de opciones
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'clear') {
                _clearAllEvents();
              } else if (value == 'stats') {
                _showCloudStats();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.cloud, color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Text('Estadísticas nube'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 12),
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
          // Indicador de sincronización
          if (_isSyncing || _syncMessage.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.blue.shade200, width: 1),
                ),
              ),
              child: Row(
                children: [
                  if (_isSyncing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _syncMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Filtros mejorados
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
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
              ],
            ),
          ),
          
          // Divisor
          Container(height: 8, color: Colors.grey[50]),
          
          // Lista de eventos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _syncWithCloud();
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _events.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'No hay eventos registrados',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los eventos de conducción aparecerán aquí',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _syncWithCloud,
            icon: const Icon(Icons.cloud_download, color: Colors.white),
            label: const Text(
              'Sincronizar desde la nube',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E4374),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E4374) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
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
    return InkWell(
      onTap: () => _showEventDetails(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
        child: Row(
          children: [
            // Icono del evento
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            
            const SizedBox(width: 16),
            
            // Información del evento
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.type,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        event.timestamp.toString().substring(11, 19),
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.speed, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${event.speed.toStringAsFixed(1)} km/h',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.timestamp.toString().substring(0, 10),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            
            // Botón de detalles
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetails(BuildContext context) {
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
              child: Text(
                event.type,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionTitle('Información General'),
              const SizedBox(height: 8),
              _DetailRow(Icons.calendar_today, 'Fecha', event.timestamp.toString().substring(0, 10)),
              _DetailRow(Icons.access_time, 'Hora', event.timestamp.toString().substring(11, 19)),
              _DetailRow(Icons.speed, 'Velocidad', '${event.speed.toStringAsFixed(1)} km/h'),
              
              const SizedBox(height: 16),
              _buildSectionTitle('Ubicación GPS'),
              const SizedBox(height: 8),
              _DetailRow(Icons.my_location, 'Latitud', event.latitude.toStringAsFixed(6)),
              _DetailRow(Icons.place, 'Longitud', event.longitude.toStringAsFixed(6)),
              
              const SizedBox(height: 16),
              _buildSectionTitle('Datos del Acelerómetro'),
              const SizedBox(height: 8),
              _DetailRow(Icons.arrow_forward, 'Eje X', '${event.accelX.toStringAsFixed(2)} m/s²', valueColor: Colors.red),
              _DetailRow(Icons.arrow_upward, 'Eje Y', '${event.accelY.toStringAsFixed(2)} m/s²', valueColor: Colors.green),
              _DetailRow(Icons.arrow_downward, 'Eje Z', '${event.accelZ.toStringAsFixed(2)} m/s²', valueColor: Colors.purple),
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
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }

  Widget _DetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}