import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'api_service.dart';

class EntregaScreen extends StatefulWidget {
  final Map paquete;
  const EntregaScreen({super.key, required this.paquete});

  @override
  State<EntregaScreen> createState() => _EntregaScreenState();
}

class _EntregaScreenState extends State<EntregaScreen> {
  Uint8List? fotoBytes; // Usamos bytes en vez de File (compatible con web)
  String? fotoNombre;
  double? latGPS;
  double? lngGPS;
  bool cargando = false;

  // ── 1. CÁMARA / GALERÍA ───────────────────────────────────
  Future tomarFoto() async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(
      source:
          ImageSource.gallery, // En web no hay cámara directa, usamos galería
      imageQuality: 70,
    );
    if (imagen != null) {
      final bytes = await imagen.readAsBytes();
      setState(() {
        fotoBytes = bytes;
        fotoNombre = imagen.name;
      });
    }
  }

  // ── 2. GPS (simulado en web) ──────────────────────────────
  // En web el GPS real requiere HTTPS. Usamos las coordenadas del paquete
  // como ubicación de entrega, que es lo que realmente importa.
  Future obtenerUbicacion() async {
    final lat = (widget.paquete['latitud'] as num?)?.toDouble() ?? 20.5881;
    final lng = (widget.paquete['longitud'] as num?)?.toDouble() ?? -100.3899;

    setState(() {
      latGPS = lat;
      lngGPS = lng;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Ubicación obtenida"),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ── 3. ENTREGAR ───────────────────────────────────────────
  Future entregar() async {
    if (fotoBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Necesitas seleccionar una foto como evidencia")),
      );
      return;
    }
    if (latGPS == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Necesitas obtener la ubicación GPS")),
      );
      return;
    }

    setState(() => cargando = true);

    try {
      final token = await ApiService.obtenerToken();
      final idPaq = widget.paquete['id_paq'];

      // Paso 1: POST /paquetes con multipart (foto + coordenadas)
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/paquetes'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['direc_dest'] = widget.paquete['direc_dest'] ?? '';
      request.fields['latitud'] = latGPS.toString();
      request.fields['longitud'] = lngGPS.toString();
      if (widget.paquete['id_cli'] != null) {
        request.fields['id_cli'] = widget.paquete['id_cli'].toString();
      }

      // Adjunta la foto como bytes (compatible con web)
      request.files.add(
        http.MultipartFile.fromBytes(
          'foto',
          fotoBytes!,
          filename: fotoNombre ?? 'evidencia.jpg',
        ),
      );
      await request.send();

      // Paso 2: PATCH /paquetes/{id}/status → cambia a "Entregado"
      await http.patch(
        Uri.parse('${ApiService.baseUrl}/paquetes/$idPaq/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': 'Entregado'}),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Paquete entregado correctamente!"),
          backgroundColor: Colors.green,
        ),
      );

      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error al registrar la entrega")),
      );
    } finally {
      setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = (widget.paquete['latitud'] as num?)?.toDouble() ?? 20.5881;
    final lng = (widget.paquete['longitud'] as num?)?.toDouble() ?? -100.3899;

    return Scaffold(
      appBar: AppBar(
        title: Text("Paquete #${widget.paquete['id_paq']}"),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Dirección de destino ──────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF1565C0)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Dirección de destino",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            widget.paquete['direc_dest'] ?? '—',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Mapa interactivo ──────────────────────────
            const Text("Mapa de entrega",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 220,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.paquexpress',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(lat, lng),
                          child: const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Foto de evidencia ─────────────────────────
            const Text("Evidencia fotográfica",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: tomarFoto,
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Seleccionar foto"),
                ),
                const SizedBox(width: 12),
                if (fotoBytes != null)
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 4),
                      Text("Foto lista", style: TextStyle(color: Colors.green)),
                    ],
                  ),
              ],
            ),
            if (fotoBytes != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  fotoBytes!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // ── Ubicación GPS ─────────────────────────────
            const Text("Ubicación GPS",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 6),
            ElevatedButton.icon(
              onPressed: obtenerUbicacion,
              icon: const Icon(Icons.gps_fixed),
              label: const Text("Obtener ubicación"),
            ),
            if (latGPS != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    "Lat: ${latGPS!.toStringAsFixed(6)}\n"
                    "Lng: ${lngGPS!.toStringAsFixed(6)}",
                    style: const TextStyle(color: Colors.green, fontSize: 13),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // ── Botón principal ───────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: cargando ? null : entregar,
                icon: const Icon(Icons.check_circle_outline),
                label: cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text("Paquete entregado",
                        style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
