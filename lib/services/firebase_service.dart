// services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/driving_event.dart';
import 'data_service.dart';
import 'dart:async';

/// Servicio para sincronización con Firebase Firestore
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DataService _dataService = DataService();

  StreamSubscription<QuerySnapshot>? _eventsSubscription;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Callback para notificar cambios de sincronización
  Function(bool)? onSyncStatusChanged;
  Function(String)? onSyncMessage;

  /// Guarda un evento en Firestore
  Future<bool> saveEventToCloud(DrivingEvent event) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ No hay usuario autenticado');
        return false;
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .doc(event.id)
          .set(event.toJson());

      print('☁️ Evento guardado en Firebase: ${event.type}');
      return true;
    } catch (e) {
      print('❌ Error al guardar en Firebase: $e');
      return false;
    }
  }

  /// Sincroniza eventos locales pendientes con Firebase
  Future<void> syncPendingEvents() async {
    if (_isSyncing) {
      print('⏳ Sincronización ya en progreso...');
      return;
    }

    try {
      _isSyncing = true;
      onSyncStatusChanged?.call(true);
      onSyncMessage?.call('Sincronizando eventos...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('⚠️ No hay usuario autenticado');
        return;
      }

      // Obtener eventos locales
      final localEvents = await _dataService.getEvents();

      if (localEvents.isEmpty) {
        print('✅ No hay eventos para sincronizar');
        onSyncMessage?.call('Todo sincronizado');
        return;
      }

      // Obtener IDs de eventos ya en Firebase
      final cloudSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .get();

      final cloudEventIds = cloudSnapshot.docs.map((doc) => doc.id).toSet();

      // Filtrar eventos que NO están en la nube
      final eventsToSync = localEvents
          .where((event) => !cloudEventIds.contains(event.id))
          .toList();

      print('📤 Sincronizando ${eventsToSync.length} eventos nuevos...');

      // Subir eventos en lotes (batch)
      final batch = _firestore.batch();
      int count = 0;

      for (var event in eventsToSync) {
        final docRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('events')
            .doc(event.id);

        batch.set(docRef, event.toJson());
        count++;

        // Firestore permite máximo 500 operaciones por batch
        if (count >= 500) {
          await batch.commit();
          count = 0;
          print('📦 Lote de 500 eventos sincronizado');
        }
      }

      // Commit del último lote
      if (count > 0) {
        await batch.commit();
      }

      _lastSyncTime = DateTime.now();
      print('✅ Sincronización completada: ${eventsToSync.length} eventos');
      onSyncMessage?.call('${eventsToSync.length} eventos sincronizados');
    } catch (e) {
      print('❌ Error en sincronización: $e');
      onSyncMessage?.call('Error en sincronización');
    } finally {
      _isSyncing = false;
      onSyncStatusChanged?.call(false);
    }
  }

  /// Descarga eventos desde Firebase y los guarda localmente
  Future<void> downloadEventsFromCloud() async {
    try {
      onSyncMessage?.call('Descargando eventos...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final cloudSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .orderBy('timestamp', descending: true)
          .get();

      print(
        '📥 Descargando ${cloudSnapshot.docs.length} eventos de Firebase...',
      );

      for (var doc in cloudSnapshot.docs) {
        final event = DrivingEvent.fromJson(doc.data());

        // Verificar si ya existe localmente
        final localEvents = await _dataService.getEvents(limit: 1);
        final exists = localEvents.any((e) => e.id == event.id);

        if (!exists) {
          await _dataService.saveEvent(event);
        }
      }

      print('✅ Eventos descargados correctamente');
      onSyncMessage?.call('Eventos descargados');
    } catch (e) {
      print('❌ Error al descargar eventos: $e');
      onSyncMessage?.call('Error al descargar');
    }
  }

  /// Sincronización bidireccional completa
  Future<void> fullSync() async {
    try {
      print('🔄 Iniciando sincronización completa...');

      // 1. Subir eventos locales
      await syncPendingEvents();

      // 2. Descargar eventos de la nube
      await downloadEventsFromCloud();

      print('✅ Sincronización completa finalizada');
      onSyncMessage?.call('Sincronización completa');
    } catch (e) {
      print('❌ Error en sincronización completa: $e');
    }
  }

  /// Escucha cambios en tiempo real de Firebase
  void listenToCloudEvents() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _eventsSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('events')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) {
          print('🔔 ${snapshot.docs.length} eventos en tiempo real');

          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final event = DrivingEvent.fromJson(change.doc.data()!);
              _dataService.saveEvent(event);
            }
          }
        });
  }

  /// Detiene la escucha en tiempo real
  void stopListening() {
    _eventsSubscription?.cancel();
    _eventsSubscription = null;
  }

  /// Elimina un evento de Firebase
  Future<bool> deleteEventFromCloud(String eventId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .doc(eventId)
          .delete();

      print('🗑️ Evento eliminado de Firebase');
      return true;
    } catch (e) {
      print('❌ Error al eliminar de Firebase: $e');
      return false;
    }
  }

  /// Limpia todos los eventos del usuario en Firebase
  Future<void> clearCloudEvents() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('🗑️ Todos los eventos eliminados de Firebase');
    } catch (e) {
      print('❌ Error al limpiar eventos: $e');
    }
  }

  /// Obtiene estadísticas del usuario desde Firebase
  Future<Map<String, dynamic>> getCloudStats() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('events')
          .get();

      final Map<String, int> eventsByType = {};
      for (var doc in snapshot.docs) {
        final type = doc.data()['type'] as String;
        eventsByType[type] = (eventsByType[type] ?? 0) + 1;
      }

      return {
        'totalEvents': snapshot.docs.length,
        'eventsByType': eventsByType,
        'lastSync': _lastSyncTime?.toIso8601String(),
      };
    } catch (e) {
      print('❌ Error al obtener estadísticas: $e');
      return {};
    }
  }

  /// Verifica si hay conexión a internet
  Future<bool> isOnline() async {
    try {
      await _firestore.runTransaction((t) async {});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Obtiene el estado de sincronización
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Guarda perfil del usuario
  Future<void> saveUserProfile({
    required String name,
    required String email,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('👤 Perfil guardado en Firebase');
    } catch (e) {
      print('❌ Error al guardar perfil: $e');
    }
  }

  /// Obtiene perfil del usuario
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (e) {
      print('❌ Error al obtener perfil: $e');
      return null;
    }
  }
}
