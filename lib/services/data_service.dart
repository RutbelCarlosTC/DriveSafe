import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/driving_event.dart';

/// Servicio para gestionar el almacenamiento de datos con SQLite
class DataService {
  static Database? _database;
  static const String _dbName = 'driving_detection.db';
  static const int _dbVersion = 1;

  // Nombres de tablas
  static const String _eventsTable = 'driving_events';
  static const String _settingsTable = 'settings';

  /// Obtiene la instancia de la base de datos (singleton)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inicializa la base de datos
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Crea las tablas de la base de datos
  Future<void> _onCreate(Database db, int version) async {
    // Tabla de eventos
    await db.execute('''
      CREATE TABLE $_eventsTable (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        speed REAL NOT NULL,
        accelX REAL NOT NULL,
        accelY REAL NOT NULL,
        accelZ REAL NOT NULL
      )
    ''');

    // Tabla de configuración
    await db.execute('''
      CREATE TABLE $_settingsTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Índices para mejorar el rendimiento
    await db.execute('''
      CREATE INDEX idx_events_timestamp ON $_eventsTable(timestamp DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_events_type ON $_eventsTable(type)
    ''');

    print('✅ Base de datos creada exitosamente');
  }

  /// Maneja actualizaciones de la base de datos
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Implementar migraciones futuras aquí
  }

  /// Guarda un evento de conducción
  Future<void> saveEvent(DrivingEvent event) async {
    try {
      final db = await database;
      await db.insert(
        _eventsTable,
        event.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('💾 Evento guardado en SQLite: ${event.type}');
    } catch (e) {
      print('❌ Error al guardar evento: $e');
    }
  }

  /// Obtiene todos los eventos (más recientes primero)
  Future<List<DrivingEvent>> getEvents({int? limit}) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _eventsTable,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return maps.map((map) => DrivingEvent.fromJson(map)).toList();
    } catch (e) {
      print('❌ Error al obtener eventos: $e');
      return [];
    }
  }

  /// Obtiene eventos filtrados por tipo
  Future<List<DrivingEvent>> getEventsByType(String type) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _eventsTable,
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'timestamp DESC',
      );

      return maps.map((map) => DrivingEvent.fromJson(map)).toList();
    } catch (e) {
      print('❌ Error al obtener eventos por tipo: $e');
      return [];
    }
  }

  /// Obtiene eventos de un rango de fechas
  Future<List<DrivingEvent>> getEventsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _eventsTable,
        where: 'timestamp BETWEEN ? AND ?',
        whereArgs: [
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ],
        orderBy: 'timestamp DESC',
      );

      return maps.map((map) => DrivingEvent.fromJson(map)).toList();
    } catch (e) {
      print('❌ Error al obtener eventos por rango: $e');
      return [];
    }
  }

  /// Obtiene eventos del día actual
  Future<List<DrivingEvent>> getTodayEvents() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return getEventsByDateRange(startOfDay, endOfDay);
  }

  /// Obtiene eventos de la semana actual
  Future<List<DrivingEvent>> getWeekEvents() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    
    return getEventsByDateRange(startOfDay, now);
  }

  /// Obtiene eventos del mes actual
  Future<List<DrivingEvent>> getMonthEvents() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    return getEventsByDateRange(startOfMonth, now);
  }

  /// Cuenta el total de eventos
  Future<int> getTotalEventsCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_eventsTable');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      print('❌ Error al contar eventos: $e');
      return 0;
    }
  }

  /// Obtiene estadísticas básicas
  Future<Map<String, dynamic>> getStats() async {
    try {
      final db = await database;
      
      // Total de eventos
      final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_eventsTable');
      final total = Sqflite.firstIntValue(totalResult) ?? 0;

      // Eventos por tipo
      final typeResult = await db.rawQuery('''
        SELECT type, COUNT(*) as count 
        FROM $_eventsTable 
        GROUP BY type
      ''');
      
      final Map<String, int> eventsByType = {};
      for (var row in typeResult) {
        eventsByType[row['type'] as String] = row['count'] as int;
      }

      // Último evento
      final lastEventResult = await db.query(
        _eventsTable,
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      
      String? lastUpdate;
      if (lastEventResult.isNotEmpty) {
        lastUpdate = lastEventResult.first['timestamp'] as String;
      }

      return {
        'total': total,
        'eventsByType': eventsByType,
        'lastUpdate': lastUpdate,
      };
    } catch (e) {
      print('❌ Error al obtener estadísticas: $e');
      return {'total': 0, 'eventsByType': {}, 'lastUpdate': null};
    }
  }

  /// Obtiene estadísticas detalladas
  Future<Map<String, dynamic>> getDetailedStats() async {
    try {
      final db = await database;
      
      // Eventos de hoy
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final todayEvents = await getEventsByDateRange(startOfDay, now);
      
      // Total de eventos
      final total = await getTotalEventsCount();
      
      // Eventos por tipo
      final typeResult = await db.rawQuery('''
        SELECT type, COUNT(*) as count 
        FROM $_eventsTable 
        GROUP BY type
      ''');
      
      final Map<String, int> eventsByType = {};
      for (var row in typeResult) {
        eventsByType[row['type'] as String] = row['count'] as int;
      }

      // Velocidad promedio
      final speedResult = await db.rawQuery('SELECT AVG(speed) as avgSpeed FROM $_eventsTable');
      final avgSpeed = (speedResult.first['avgSpeed'] as num?)?.toDouble() ?? 0.0;

      // Último evento
      final lastEventResult = await db.query(
        _eventsTable,
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      
      String? lastEvent;
      if (lastEventResult.isNotEmpty) {
        lastEvent = lastEventResult.first['timestamp'] as String;
      }

      return {
        'totalEvents': total,
        'todayEvents': todayEvents.length,
        'eventsByType': eventsByType,
        'averageSpeed': avgSpeed,
        'lastEvent': lastEvent,
      };
    } catch (e) {
      print('❌ Error al obtener estadísticas detalladas: $e');
      return {
        'totalEvents': 0,
        'todayEvents': 0,
        'eventsByType': {},
        'averageSpeed': 0.0,
        'lastEvent': null,
      };
    }
  }

  /// Limpia todos los eventos
  Future<void> clearEvents() async {
    try {
      final db = await database;
      await db.delete(_eventsTable);
      print('🗑️ Todos los eventos eliminados');
    } catch (e) {
      print('❌ Error al limpiar eventos: $e');
    }
  }

  /// Elimina eventos anteriores a una fecha
  Future<void> deleteEventsOlderThan(DateTime date) async {
    try {
      final db = await database;
      final deletedCount = await db.delete(
        _eventsTable,
        where: 'timestamp < ?',
        whereArgs: [date.toIso8601String()],
      );
      print('🗑️ $deletedCount eventos antiguos eliminados');
    } catch (e) {
      print('❌ Error al eliminar eventos antiguos: $e');
    }
  }

  /// Guarda una configuración
  Future<void> saveSetting(String key, String value) async {
    try {
      final db = await database;
      await db.insert(
        _settingsTable,
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('❌ Error al guardar configuración: $e');
    }
  }

  /// Obtiene una configuración
  Future<String?> getSetting(String key) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _settingsTable,
        where: 'key = ?',
        whereArgs: [key],
      );

      if (maps.isNotEmpty) {
        return maps.first['value'] as String;
      }
      return null;
    } catch (e) {
      print('❌ Error al obtener configuración: $e');
      return null;
    }
  }

  /// Guarda el ID del usuario
  Future<void> saveUserId(String userId) async {
    await saveSetting('user_id', userId);
  }

  /// Obtiene el ID del usuario
  Future<String?> getUserId() async {
    return await getSetting('user_id');
  }

  /// Calcula la puntuación de conducción (0-100)
  Future<double> calculateDrivingScore() async {
    final events = await getTodayEvents();
    
    if (events.isEmpty) return 100.0;
    
    double score = 100.0;
    
    // Penalizar por cada tipo de evento
    for (var event in events) {
      switch (event.type) {
        case 'Frenada Brusca':
          score -= 5.0;
          break;
        case 'Aceleración Repentina':
          score -= 5.0;
          break;
        case 'Giro Fuerte':
          score -= 3.0;
          break;
        case 'Exceso de Velocidad':
          score -= 10.0;
          break;
      }
    }
    
    return score.clamp(0.0, 100.0);
  }

  /// Cierra la base de datos
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}