// ─────────────────────────────────────────────────────────────
// paquete_list.dart
// Lista todos los paquetes asignados al agente autenticado.
//
// Flujo:
//  1. Al abrir la pantalla, llama a GET /paquetes
//  2. La API filtra y devuelve solo los paquetes del agente
//     (gracias al JWT, sabe quién está preguntando)
//  3. Se muestran en tarjetas con color según su status
//  4. Al tocar un paquete, abre EntregaScreen para procesarlo
//  5. Al regresar de EntregaScreen, recarga la lista automáticamente
//
// Endpoint usado: GET /paquetes
// Header: Authorization: Bearer <token>
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';
import 'entrega_screen.dart';

class PaqueteList extends StatefulWidget {
  const PaqueteList({super.key});

  @override
  State<PaqueteList> createState() => _PaqueteListState();
}

class _PaqueteListState extends State<PaqueteList> {
  List paquetes = []; // Lista de paquetes recibidos de la API
  bool cargando = true;

  Future cargarPaquetes() async {
    setState(() => cargando = true);

    // Obtener el token guardado para mandarlo en el header
    final token = await ApiService.obtenerToken();
    final url = Uri.parse('${ApiService.baseUrl}/paquetes');

    final response = await http.get(
      url,
      headers: {
        // JWT en el header — sin esto la API rechaza la petición con 401
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        paquetes = jsonDecode(response.body);
        cargando = false;
      });
    } else {
      setState(() => cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al cargar paquetes")),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    cargarPaquetes(); // Carga automática al abrir la pantalla
  }

  // Retorna un color según el status del paquete para identificarlos visualmente
  Color _colorStatus(String? status) {
    switch (status) {
      case 'Entregado':
        return Colors.green;
      case 'En curso':
        return Colors.orange;
      case 'Detenido':
        return Colors.red;
      case 'Recogido':
        return Colors.blue;
      default:
        return Colors.grey; // Pendiente u otro
    }
  }

  // Ícono según el status
  IconData _iconStatus(String? status) {
    switch (status) {
      case 'Entregado':
        return Icons.check_circle;
      case 'En curso':
        return Icons.directions_run;
      case 'Detenido':
        return Icons.pause_circle;
      case 'Recogido':
        return Icons.inventory;
      default:
        return Icons.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Paquetes"),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          // Botón de recarga manual en la barra
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: cargarPaquetes,
          ),
        ],
      ),
      body: cargando
          // Mientras carga muestra spinner centrado
          ? const Center(child: CircularProgressIndicator())

          // Si no hay paquetes muestra mensaje amigable
          : paquetes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        "No tienes paquetes asignados",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )

              // Lista de paquetes
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: paquetes.length,
                  itemBuilder: (context, index) {
                    final p = paquetes[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        // Ícono con color según status
                        leading: Icon(
                          _iconStatus(p['status']),
                          color: _colorStatus(p['status']),
                          size: 32,
                        ),
                        title: Text(
                          "Paquete #${p['id_paq']}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(p['direc_dest'] ?? 'Sin dirección'),
                        // Chip de color con el status actual
                        trailing: Chip(
                          label: Text(
                            p['status'] ?? '—',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                          backgroundColor: _colorStatus(p['status']),
                        ),
                        // Al tocar abre EntregaScreen pasando el paquete completo
                        // .then() recarga la lista cuando el agente regresa
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EntregaScreen(paquete: p),
                            ),
                          ).then((_) => cargarPaquetes());
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
