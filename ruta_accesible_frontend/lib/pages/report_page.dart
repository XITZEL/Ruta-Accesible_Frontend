import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class ReportePage extends StatefulWidget {
  final String categoria;
  const ReportePage({super.key, required this.categoria});

  @override
  State<ReportePage> createState() => _ReportePageState();
}

class _ReportePageState extends State<ReportePage> {
  bool _cargando = false;
  String _mensajeEstado = "Presione el botón para analizar";
  
  // Colores de la paleta solicitada
  final Color _fondoGris = const Color(0xFFF5F7FA);
  final Color _textoOscuro = const Color(0xFF0A192F);
  final Color _azulBotones = const Color(0xFF143278);

  // Simulación de llamada a POST /api/ai/describe-photo
  Future<void> _analizarImagen() async {
    setState(() {
      _cargando = true;
      _mensajeEstado = "Analizando peligro con IA...";
    });

    // Aquí iría tu lógica real de cámara + multipart/form-data a /api/ai/describe-photo
    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      _cargando = false;
      _mensajeEstado = "Peligro detectado: ${widget.categoria}. ¿Desea enviar reporte?";
    });
  }

  // Envío final a POST /api/reports
  Future<void> _enviarReporte() async {
    setState(() => _cargando = true);

    final body = {
      "userId": "usuario_anonimo_123", // Cambiar por auth real
      "tipo_barrera": widget.categoria,
      "descripcion": "Obstáculo detectado automáticamente",
      "metodo_ingreso": "IA",
      "lat": 32.5149,
      "lng": -117.0382,
    };

    try {
      final response = await http.post(
        Uri.parse('https://ruta-accesible.vercel.app/api/reports'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );

      if (response.statusCode == 201 && mounted) {
        _mostrarExito();
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarExito() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¡Reporte enviado!"),
        content: const Text("Gracias por ayudar a mejorar la ciudad."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Aceptar"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoGris,
      appBar: AppBar(
        title: const Text("Nuevo Reporte", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _azulBotones,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              "Reportar: ${widget.categoria.toUpperCase()}",
              style: TextStyle(fontSize: 22, color: _textoOscuro, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            
            // Área de Feedback visual grande
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child: Center(
                child: _cargando 
                  ? const CircularProgressIndicator() 
                  : Text(_mensajeEstado, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: _textoOscuro)),
              ),
            ),
            const Spacer(),

            // Botones grandes y accesibles
            SizedBox(
              width: double.infinity,
              height: 65,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _azulBotones),
                onPressed: _cargando ? null : _analizarImagen,
                child: const Text("TOMAR FOTO Y ANALIZAR", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 65,
              child: OutlinedButton(
                onPressed: _cargando ? null : _enviarReporte,
                child: Text("CONFIRMAR Y ENVIAR", style: TextStyle(fontSize: 18, color: _azulBotones)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}