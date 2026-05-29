import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Tus páginas modulares importadas
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
  final TextEditingController _searchController = TextEditingController();

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // Paleta estética original
  final Color _fondoGeneral = const Color(0xFFF5F7FA);
  final Color _fondoBotones = const Color(0xFF143278);

  @override
  void initState() {
    super.initState();
    // Si viene un destino desde otra pantalla al cargar, traza la ruta de inmediato
    if (widget.destino != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _trazarRuta(widget.destino!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // LÓGICA DE RUTEO: Decodifica de forma segura y dibuja la polilínea azul
  Future<void> _trazarRuta(LatLng destino) async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      final inicio = LatLng(pos.latitude, pos.longitude);

      final url = Uri.parse(
          'https://vercel.app{inicio.latitude}&originLng=${inicio.longitude}&destLat=${destino.latitude}&destLng=${destino.longitude}');
      final response = await http.get(url);

      List<LatLng> coords = [inicio, destino];
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(json.decode(response.body));
        if (data.containsKey('data') && data['data'] != null) {
          final Map<String, dynamic> dataRoute = Map<String, dynamic>.from(data['data']);
          final encoded = dataRoute['points'] as String? ?? '';
          
          if (encoded.isNotEmpty) {
            coords = PolylinePoints()
                .decodePolyline(encoded)
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList();
          }
        }
      }

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('ruta'),
            points: coords,
            color: const Color(0xFF143278), // Línea azul de ruta
            width: 6,
          )
        };
        _markers = {
          Marker(
            markerId: const MarkerId('inicio'),
            position: inicio,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: const InfoWindow(title: 'Mi Ubicación'),
          ),
          Marker(
            markerId: const MarkerId('destino'),
            position: destino,
            infoWindow: InfoWindow(title: widget.destinoNombre ?? 'Destino'),
          )
        };
      });

      // Mover la cámara para encuadrar la ruta
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
          90, // Margen de padding
        ),
      );
    } catch (e) {
      print('Error en ruteo: $e');
    }
  }

  // Búsqueda general de texto
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

  // Navegación rápida modular a las vistas de accesibilidad
  void _irACategoria(String tipo, Widget pagina) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => pagina));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoGeneral,
      body: Stack(
        children: [
          // 1. EL MAPA DE GOOGLE
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
              if (widget.destino != null) {
                _trazarRuta(widget.destino!);
              }
            },
            initialCameraPosition: CameraPosition(target: _centroDefault, zoom: 15.0),
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // Desactivado para no estorbar el diseño
            polylines: _polylines,
            markers: _markers,
          ),

          // BUSCADOR
          // 2. BARRA DE BÚSQUEDA FLOTANTE SUPERIOR
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Container(
              height: 55,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Colors.white,
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onSubmitted: _buscar,
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search, color: _fondoBotones),
                    onPressed: () => _buscar(_searchController.text),
                    constraints: const BoxConstraints(minWidth: 40),
                  ),
                ],
              ),
            ),
          ),

          // 3. BANNER DE INDICACIÓN DE DESTINO ACTIVO
          if (widget.destinoNombre != null)
            Positioned(
              top: 120,
              left: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _fondoBotones,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
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
