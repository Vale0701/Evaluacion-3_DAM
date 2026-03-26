// ─────────────────────────────────────────────────────────────
// main.dart
// Punto de entrada de la aplicación Paquexpress.
// Define el tema visual y las rutas de navegación.
// Cada ruta '/xxx' corresponde a una pantalla distinta.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'login.dart';        // Pantalla de inicio de sesión
import 'menu.dart';         // Menú principal del agente
import 'paquete_list.dart'; // Lista de paquetes asignados

void main() {
  runApp(const ApiApp());
}

class ApiApp extends StatelessWidget {
  const ApiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Quita el banner "DEBUG" en la esquina
      title: 'Paquexpress',
      theme: ThemeData(
        // Color principal azul corporativo en toda la app
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      initialRoute: '/', // La app siempre inicia en el Login
      routes: {
        '/':         (context) => const LoginPage(),   // Login
        '/menu':     (context) => const MenuPage(),    // Menú principal
        '/paquetes': (context) => const PaqueteList(), // Lista de paquetes
        // EntregaScreen no va aquí porque recibe parámetros (el paquete),
        // se navega con Navigator.push() directamente desde paquete_list.dart
      },
    );
  }
}