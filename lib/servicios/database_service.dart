import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final String uid;
  late final DatabaseReference _userRef;
  late final DatabaseReference _glucoseReadingsRef;

  DatabaseService(this.uid) {
    _userRef = FirebaseDatabase.instance.ref('users/$uid');
    _glucoseReadingsRef = _userRef.child('readings');
  }

  // Crear o sobrescribir todos los datos del usuario (ideal para registro inicial)
  Future<void> setUserData(Map<String, dynamic> userData) async {
    try {
      await _userRef.set(userData);
      if (kDebugMode) {
        print('Datos completos del usuario guardados correctamente');
      }
    } catch (e) {
      throw Exception('Error al guardar datos del usuario: $e');
    }
  }

  // Actualizar campos específicos del usuario
  Future<void> updateUserData(Map<String, dynamic> userData) async {
    try {
      await _userRef.update(userData);
      if (kDebugMode) {
        print('Datos parciales del usuario actualizados');
      }
    } catch (e) {
      throw Exception('Error al actualizar datos: $e');
    }
  }

  // Obtener todos los datos del usuario
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final snapshot = await _userRef.get();
      return snapshot.exists ? Map<String, dynamic>.from(snapshot.value as Map) : null;
    } catch (e) {
      throw Exception('Error al obtener datos: $e');
    }
  }

  // Añadir nueva lectura de glucosa con clave única
  Future<void> addGlucoseReading(Map<String, dynamic> readingData) async {
    try {
      // Ahora readingData incluirá el campo 'measurementType'
      await _glucoseReadingsRef.push().set(readingData);
      if (kDebugMode) {
        print('Nueva medición registrada: ${readingData['measurementType']}');
      }
    } catch (e) {
      throw Exception('Error al guardar medición: $e');
    }
  }

  // Obtener stream de lecturas en tiempo real
  Stream<DatabaseEvent> get glucoseReadingsStream {
    return _glucoseReadingsRef.onValue;
  }
}