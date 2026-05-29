import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'pages/map_page.dart'; 

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  // Mover la instancia aquí dentro soluciona el error de "const"
  Future<void> _hablar(String texto) async {
    FlutterTts flutterTts = FlutterTts();
    await flutterTts.setLanguage("es-MX");
    await flutterTts.setPitch(1.0);
    await flutterTts.speak(texto);
  }

  @override
  Widget build(BuildContext context) {
    const colorFondo = Color(0xFFF8FAFC);
    const colorBoton = Color(0xFF143278);
    const colorTextoPrimario = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: colorFondo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Botón: Navegación Asistida
              _buildModoBoton(
                context: context,
                titulo: 'Navegación\nasistida',
                descripcion: 'Sugerido para adultos mayores y personas con problemas motrices',
                colorBoton: colorBoton,
                colorTexto: colorTextoPrimario,
                esAsistido: false,
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
                esAsistido: false,
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
                await _hablar(descripcion);
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