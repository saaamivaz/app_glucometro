import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener estado del usuario actual
  Stream<User?> get user => _auth.authStateChanges();

  // Iniciar sesión con correo y contraseña
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error al iniciar sesión: ${e.message}');
      rethrow;
    }
  }

  // Registrar nuevo usuario con correo y contraseña
  Future<User?> registerWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null){
        final DatabaseReference ref = FirebaseDatabase.instance.ref("users/${userCredential.user!.uid}");
        await ref.set({
          "email":email,
          "createdAt": ServerValue.timestamp,
        });
      }
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Error al registrar usuario: ${e.message}');
      rethrow;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
      rethrow;
    }
  }
}