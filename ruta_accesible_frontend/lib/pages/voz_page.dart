import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class MapPage extends StatefulWidget {
  final LatLng? destino;
  const MapPage({super.key, this.destino});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  Future<void> _iniciarBusquedaPorVoz() async {
    bool disponible = await _speech.initialize();
    if (disponible) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) async {
        if (result.finalResult) {
          setState(() => _isListening = false);
          _procesarTexto(result.recognizedWords.toLowerCase());
        }
      });
    }
  }

  void _procesarTexto(String texto) async {
    String cat = "";
    if (texto.contains("hospital")) {
      cat = "hospital";
    } else if (texto.contains("banco"))
      cat = "banco";
    else if (texto.contains("gobierno"))
      cat = "gobierno";
    else if (texto.contains("super")) cat = "super";

    if (cat.isNotEmpty) {
      Position pos = await Geolocator.getCurrentPosition();
      final url = Uri.parse(
          'https://ruta-accesible.vercel.app/api/places?lat=${pos.latitude}&lng=${pos.longitude}&category=$cat');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'];
        if (data.isNotEmpty) {
          final lugar = data[0]; // Tomar el más cercano
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      MapPage(destino: LatLng(lugar['lat'], lugar['lng']))));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
            target: widget.destino ?? const LatLng(32.5149, -117.0382),
            zoom: 15),
        markers: widget.destino != null
            ? {
                Marker(
                    markerId: const MarkerId('dest'), position: widget.destino!)
              }
            : {},
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _isListening ? Colors.red : const Color(0xFF143278),
        onPressed: _iniciarBusquedaPorVoz,
        child:
            Icon(_isListening ? Icons.mic_off : Icons.mic, color: Colors.white),
      ),
    );
  }
}
