// ─────────────────────────────────────────────────────────────
// api_service.dart
// Servicio central para manejar el JWT token del agente.
// El token se guarda en el almacenamiento local del celular
// usando shared_preferences (como un mini almacén clave-valor).
// Todas las pantallas usan este archivo para leer el token
// y mandarlo en el header Authorization de cada petición.
// ─────────────────────────────────────────────────────────────

import 'package:shared_preferences/shared_preferences.dart';

class ApiService {

  // URL base de tu API FastAPI.
  // → Emulador Android: usa 10.0.2.2 (apunta al localhost de tu PC)
  // → Celular físico:   cambia por la IP de tu PC en la red WiFi
  //   Ejemplo: 'http://192.168.1.100:8000'
  //   Para saber tu IP corre en tu PC: ipconfig (Windows) o ifconfig (Mac/Linux)
  static const String baseUrl = 'http://127.0.0.1:8000';

  // Guarda el token JWT en el celular después del login exitoso.
  // Se llama una sola vez al iniciar sesión.
  static Future<void> guardarToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // Lee el token guardado para incluirlo en cada petición a la API.
  // Retorna null si no hay sesión activa.
  static Future<String?> obtenerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Elimina el token al cerrar sesión.
  // Después de esto el agente tiene que volver a hacer login.
  static Future<void> eliminarToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}