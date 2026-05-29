import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'pages/map_page.dart'; 

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  // Flutter TTS setup, adjusted to avoid creating a new instance per press
  // This is better practice for performance and state management.
  // Note: For a true production app, you'd likely initialize this in
  // an initState-like logic, but for a Stateless example that just works,
  // we can use a Future-based approach for properties that need to be awaited.
  static final FlutterTts _flutterTts = FlutterTts();

  static Future<void> _configureTts() async {
    await _flutterTts.setLanguage("es-MX");
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _hablar(String texto) async {
    await _configureTts();
    await _flutterTts.speak(texto);
  }

  @override
  Widget build(BuildContext context) {
    const colorFondo = Color(0xFFF8FAFC);
    const colorBoton = Color(0xFF143278);
    const colorTextoPrimario = Color(0xFF0F172A);
    const colorTextoSecundario = Color(0xFF64748B);
    const colorIconoHeader = Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: colorFondo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              const SizedBox(height: 50), // Added top padding for header

              // --- New Header Section Inspired by image_0.png ---
              Column(
                children: [
                  // Placeholder/Icon container
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: colorIconoHeader,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Icon(
                      Icons.alt_route, // A path-like icon
                      size: 80,
                      color: colorTextoSecundario,
                    ),
                  ),
                  const SizedBox(height: 36), // Spacing below icon

                  // Title Text: "Ruta Accesible"
                  const Text(
                    'Ruta Accesible',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: colorTextoPrimario,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12), // Spacing below title

                  // Subtitle Text: "Navegación accesible y guiada para todos"
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Navegación accesible y guiada para todos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: colorTextoSecundario,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              // --- End New Header Section ---

              const Spacer(flex: 2),

              // Botón: Navegación Asistida
              _buildModoBoton(
                context: context,
                titulo: 'Navegación\nasistida',
                descripcion: 'Sugerido para adultos mayores y personas con problemas motrices',
                colorBoton: colorBoton,
                colorTexto: colorTextoPrimario,
                esAsistido: true, // Adjusted: Now correctly set to true to speak
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) =>  MapPage()),
                  );
                },
              ),
              const SizedBox(height: 36),

              // Botón: Navegación Estándar
              _buildModoBoton(
                context: context,
                titulo: 'Navegación\nestándar',
                descripcion: 'Sugerido para navegación estándar',
                colorBoton: colorBoton,
                colorTexto: colorTextoPrimario,
                esAsistido: false, // Adjusted: Stays false, won't speak description
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) =>  MapPage()),
                  );
                },
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModoBoton({
    required BuildContext context,
    required String titulo,
    required String descripcion,
    required Color colorBoton,
    required Color colorTexto,
    required bool esAsistido,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 95,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorBoton,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            onPressed: () async {
              if (esAsistido) {
                // If asistido is true, it speaks the description.
                await _hablar(descripcion);
                // In your existing logic, it waits for 3 seconds after speaking.
                // If you want it to navigate immediately after speaking *finishes*,
                // you would use flutterTts.awaitSpeakCompletion(true).
                // However, I will keep your fixed delay logic.
                await Future.delayed(const Duration(seconds: 3));
              }
              onPressed(); 
            },
            child: Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            descripcion,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorTexto.withAlpha(230), height: 1.2),
          ),
        ),
      ],
    );
  }
}