import 'package:flutter/material.dart';

class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 600;
    return Scaffold(
      backgroundColor: const Color(0xFFCDD6F3), // Fondo color CDD6F3
      body: SafeArea(
        child: Center( // Centrar todo el contenido
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: isSmallScreen ? 20 : 40),
                
                // Logo desde assets
                Image.asset(
                  'assets/imgs/logo.png',
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                ),
                
                const SizedBox(height: 40),
                
                // Texto de bienvenida con Poppins Extra Bold
                Text(
                  "Te damos la bienvenida",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800, // Extra Bold
                    color: const Color(0xFF1A1F71), // Azul oscuro
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Subtítulo
                Text(
                  "a tu glucómetro no invasivo",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w400, // Regular
                    color: const Color(0xFF1A1F71), // Azul oscuro
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 40 : 60),
                
                // Botón "Iniciar sesión"
                SizedBox(
                  width: 220,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navegar a la pantalla de inicio de sesión
                      Navigator.pushNamed(context, '/login');
                    },
                    icon: const Icon(Icons.person),
                    label: const Text("Iniciar sesión"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A74ED), // Botón color 5A74ED
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Botón "Crear cuenta"
                SizedBox(
                  width: 220,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navegar a la pantalla de registro
                      Navigator.pushNamed(context, '/register');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Crear cuenta"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1530AE), // Botón color 1530AE
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: isSmallScreen ? 20 : 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}