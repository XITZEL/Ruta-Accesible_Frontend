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
  bool analizando = false;
  File? _imagen; // Placeholder para la imagen
  final String _descripcionIA = "Descripción inicial";

  // Lógica de análisis con IA
  Future<void> _procesarFotoConIA() async {
    setState(() => analizando = true);
    await Future.delayed(const Duration(seconds: 3));
    setState(() => analizando = false);
  }

  // Envío a backend
  Future<void> _enviarReporteAFirebaseYBackend() async {
    final body = {
      "tipo_barrera": widget.categoria,
      "descripcion": _descripcionIA,
      "metodo_ingreso": "IA",
      "url_multimedia": "https://firebasestorage.googleapis.com/.../imagen.jpg",
      "lat": 32.5149,
      "lng": -117.0382,
    };

    final response = await http.post(
      Uri.parse('https://ruta-accesible.vercel.app/api/reports'),
      headers: {"Content-Type": "application/json"},
      body: json.encode(body),
    );

    if (response.statusCode == 201 && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Reportar: ${widget.categoria}")),
      body: Center(
        child: analizando
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _procesarFotoConIA,
                    child: const Text("Tomar foto y analizar"),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _enviarReporteAFirebaseYBackend,
                    child: const Text("Enviar Reporte"),
                  ),
                ],
              ),
      ),
    );
  }
}