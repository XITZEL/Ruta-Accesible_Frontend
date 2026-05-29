import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Colores exactos basados en tu diseño corporativo
    const colorFondo = Color(0xFFF8FAFC); // Un fondo grisáceo/azul muy claro y limpio
    const colorBoton = Color(0xFF143278); // El azul rey de los botones
    const colorTextoPrimario = Color(0xFF0F172A); // El azul oscuro/casi negro para los textos

    return Scaffold(
      backgroundColor: colorFondo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            children: [
              // Usamos Spacer para dar un margen dinámico arriba que empuje el contenido
              const Spacer(flex: 2),

              // Logo placeholder centrado
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF191F3D), // El tono oscuro del logo de la imagen
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Títulos principales
              const Text(
                'Ruta Accesible',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36, // Un poco más grande para igualar el impacto visual
                  fontWeight: FontWeight.w900,
                  color: colorTextoPrimario,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Navegación accesible y guiada para todos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorTextoPrimario,
                ),
              ),
              
              const Spacer(flex: 2), // Espacio intermedio maleable

              // Botón: Navegación Asistida
              _buildModoBoton(
                context: context,
                titulo: 'Navegación\nasistida',
                descripcion: 'Sugerido para adultos mayores y personas con problemas motrices',
                colorBoton: colorBoton,
                colorTexto: colorTextoPrimario,
                onPressed: () {
                  print("Ir a modo asistido");
                },
              ),
              const SizedBox(height: 36), // Separación generosa entre bloques de botón

              // Botón: Navegación Estándar (Corregido según el texto de la imagen)
              _buildModoBoton(
                context: context,
                titulo: 'Navegación\nestándar',
                descripcion: 'Sugerido para navegación estándar',
                colorBoton: colorBoton,
                colorTexto: colorTextoPrimario,
                onPressed: () {
                  print("Ir a modo estándar");
                },
              ),
              
              const Spacer(flex: 3), // Empuja todo hacia arriba de forma equilibrada
            ],
          ),
        ),
      ),
    );
  }

  // Widget optimizado para mantener la estructura limpia
  Widget _buildModoBoton({
    required BuildContext context,
    required String titulo,
    required String descripcion,
    required Color colorBoton,
    required Color colorTexto,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 95, // Altura ideal para que quepan las dos líneas cómodamente
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorBoton,
              elevation: 0, // En la imagen se ve un diseño plano sin sombras pronunciadas
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22), // Bordes más redondeados como el diseño original
              ),
            ),
            onPressed: onPressed,
            child: Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28, // Tamaño aumentado para máxima legibilidad
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.1, // Ajusta el interlineado del botón
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            descripcion,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorTexto.withValues(alpha: 0.9),
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}