import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'report_page.dart';
import 'lista_lugares_page.dart';
import 'gobierno_page.dart';
import 'hospital_page.dart';
import 'super_page.dart';
import 'banco_page.dart';

class MapPage extends StatefulWidget {
  final LatLng? destino;
  final String? destinoNombre;
  const MapPage({super.key, this.destino, this.destinoNombre});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  final LatLng _centroDefault = const LatLng(32.5149, -117.0382);
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _searchController = TextEditingController();

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  final Color _fondoGeneral = const Color(0xFFF5F7FA);
  final Color _fondoBotones = const Color(0xFF143278);
  final Color _textoBotones = const Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _configurarTTS();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _configurarTTS() async {
    await _tts.setLanguage("es-MX");
    await _tts.setSpeechRate(0.45);
  }

  Future<void> _hablar(String texto) async => await _tts.speak(texto);

  Future<void> _trazarRuta(LatLng destino) async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      final inicio = LatLng(pos.latitude, pos.longitude);

      final url = Uri.parse(
          'https://ruta-accesible.vercel.app/api/route?originLat=${inicio.latitude}&originLng=${inicio.longitude}&destLat=${destino.latitude}&destLng=${destino.longitude}');
      final response = await http.get(url);

      if (!mounted) return;

      List<LatLng> coords = [inicio, destino];
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final encoded = data['data']['points'] as String? ?? '';
        if (encoded.isNotEmpty) {
          coords = PolylinePoints()
              .decodePolyline(encoded)
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
        }
      }

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('ruta'),
            points: coords,
            color: const Color(0xFF143278),
            width: 5,
          )
        };
        _markers = {
          Marker(
            markerId: const MarkerId('destino'),
            position: destino,
            infoWindow: InfoWindow(title: widget.destinoNombre ?? 'Destino'),
          )
        };
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController?.showMarkerInfoWindow(const MarkerId('destino'));
      });

      mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              inicio.latitude < destino.latitude ? inicio.latitude : destino.latitude,
              inicio.longitude < destino.longitude ? inicio.longitude : destino.longitude,
            ),
            northeast: LatLng(
              inicio.latitude > destino.latitude ? inicio.latitude : destino.latitude,
              inicio.longitude > destino.longitude ? inicio.longitude : destino.longitude,
            ),
          ),
          80,
        ),
      );
    } catch (e) {
      print('Error trazando ruta: $e');
    }
  }

  void _buscar(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return;

    _searchController.clear();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListaLugaresPage(
          titulo: 'Resultados: $t',
          categoria: '',
          query: t,
        ),
      ),
    );
  }

  void _navegarACategoria(Widget paginaDestino) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => paginaDestino));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoGeneral,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
              if (widget.destino != null) {
                _trazarRuta(widget.destino!);
              }
            },
            initialCameraPosition: CameraPosition(target: _centroDefault, zoom: 16.0),
            myLocationEnabled: true,
            polylines: _polylines,
            markers: _markers,
          ),

          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Container(
              height: 55, 
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: _fondoGeneral,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.mic, color: _fondoBotones),
                    onPressed: () => _hablar("¿Qué lugar buscas?"),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '¿A dónde vamos?',
                      ),
                      onSubmitted: _buscar,
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search, color: _fondoBotones),
                    onPressed: () => _buscar(_searchController.text),
                  ),
                ],
              ),
            ),
          ),

          // BANNER DE DESTINO
          if (widget.destinoNombre != null)
            Positioned(
              top: 120,
              left: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
                ),
                child: Text(
                  'Yendo a: ${widget.destinoNombre}',
                  style: TextStyle(color: _fondoBotones, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
