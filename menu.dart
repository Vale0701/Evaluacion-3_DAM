// ─────────────────────────────────────────────────────────────
// menu.dart
// Menú principal del agente después de iniciar sesión.
// Solo tiene dos opciones:
//  - Ver sus paquetes asignados
//  - Cerrar sesión (elimina el token del celular)
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'api_service.dart'; // Para eliminar el token al cerrar sesión

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Paquexpress"),
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        // Sin botón de regreso — el agente no puede volver al login con "atrás"
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const SizedBox(height: 20),

          // Ícono central decorativo
          const Center(
            child: Icon(Icons.local_shipping, size: 80, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              "Agente de Entregas",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 30),

          // Opción 1: Ver paquetes asignados → navega a /paquetes
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2, color: Color(0xFF1565C0)),
              title: const Text("Mis Paquetes"),
              subtitle: const Text("Ver y gestionar entregas asignadas"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(context, '/paquetes');
              },
            ),
          ),
          const SizedBox(height: 8),

          // Opción 2: Cerrar sesión
          // Elimina el token del celular y regresa al login
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Cerrar sesión"),
              onTap: () async {
                await ApiService.eliminarToken(); // Borra el JWT guardado
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ),
        ],
      ),
    );
  }
}