import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

class FirebaseConfig {
  static Future<void> initializeFirebase() async {
    try {
      debugPrint('⏳ Intentando inicializar Firebase...');
      
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      debugPrint('✅ Firebase inicializado correctamente');
    } catch (e) {
      debugPrint('❌ Error al inicializar Firebase: $e');
      
      // Más información para depuración
      if (e is FirebaseException) {
        debugPrint('  📌 Código de error: ${e.code}');
        debugPrint('  📄 Mensaje: ${e.message}');
        debugPrint('  🔍 Stack trace: ${e.stackTrace}');
      }
    }
  }
}