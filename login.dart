// ─────────────────────────────────────────────────────────────
// login.dart
// Pantalla de inicio de sesión para el agente.
//
// Flujo:
//  1. El agente escribe su email y contraseña
//  2. Se hace POST a /auth/login con esas credenciales
//  3. La API responde con un JWT (access_token)
//  4. Se guarda el token en el celular con ApiService
//  5. Se navega al menú principal
//
// Endpoint usado: POST /auth/login
// Body:     { "email": "...", "password": "..." }
// Respuesta:{ "access_token": "...", "token_type": "bearer" }
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart'; // Para guardar el token después del login

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controladores para leer lo que escribe el agente en los campos
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();

  // Controla si mostrar el indicador de carga en el botón
  bool cargando = false;

  Future<void> login() async {
    setState(() => cargando = true);

    // Endpoint de autenticación de tu API FastAPI
    final url = Uri.parse('${ApiService.baseUrl}/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':    emailController.text.trim(), // .trim() quita espacios accidentales
          'password': passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Login exitoso → guardar el JWT en el celular
        await ApiService.guardarToken(data['access_token']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Bienvenido"),
            backgroundColor: Colors.green,
          ),
        );

        // Pequeño delay para que el agente vea el mensaje antes de navegar
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pushReplacementNamed(context, '/menu');
        });

      } else {
        // La API respondió 401 → credenciales incorrectas
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email o contraseña incorrectos")),
        );
      }
    } catch (e) {
      // Error de red: API apagada, IP incorrecta, sin WiFi, etc.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error conectando con la API")),
      );
    } finally {
      // Siempre quitar el indicador de carga al terminar
      setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar con gradiente azul corporativo
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              "Paquexpress",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ícono representativo
                    const Icon(Icons.local_shipping, size: 80, color: Color(0xFF1565C0)),
                    const SizedBox(height: 10),
                    const Text(
                      "Iniciar Sesión",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Campo email — teclado tipo email
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Campo contraseña — obscureText oculta los caracteres
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: "Contraseña",
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón — se deshabilita mientras carga para evitar doble envío
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: cargando ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: cargando
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Ingresar", style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}