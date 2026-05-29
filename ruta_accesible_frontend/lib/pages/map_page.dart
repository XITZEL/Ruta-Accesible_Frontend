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
<<<<<<< Updated upstream
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  
=======
  final TextEditingController _searchController = TextEditingController();

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

>>>>>>> Stashed changes
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

<<<<<<< Updated upstream
  void _procesarComandoVoz(String texto) {
    Widget? destino;
    if (texto.contains("gobierno")) destino = const GobiernoPage();
    else if (texto.contains("hospital")) destino = const HospitalPage();
    else if (texto.contains("banco")) destino = const BancoPage();
    else if (texto.contains("super")) destino = const SuperPage();
    
    if (destino != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => destino!));
    } else {
      _hablar("No encontré esa categoría.");
    }
=======
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
>>>>>>> Stashed changes
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

<<<<<<< Updated upstream
          // BUSCADOR BLINDADO CONTRA OVERFLOW
=======
          // BUSCADOR
>>>>>>> Stashed changes
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Container(
              height: 55, // Altura fija para evitar saltos
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: _fondoGeneral,
                borderRadius: BorderRadius.circular(15),
<<<<<<< Updated upstream
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]
=======
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
>>>>>>> Stashed changes
              ),
              child: Row(
                children: [
                  IconButton(
<<<<<<< Updated upstream
                    icon: Icon(_isListening ? Icons.mic_off : Icons.mic, 
                               color: _isListening ? Colors.red : _fondoBotones), 
                    onPressed: _escucharBusqueda,
                    constraints: const BoxConstraints(minWidth: 40), // Tamaño fijo
=======
                    icon: Icon(Icons.mic, color: _fondoBotones),
                    onPressed: () => _hablar("¿Qué lugar buscas?"),
>>>>>>> Stashed changes
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '¿A dónde vamos?',
<<<<<<< Updated upstream
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        hintStyle: TextStyle(color: _textoPrincipal.withOpacity(0.5))
                      )
                    )
=======
                      ),
                      onSubmitted: _buscar,
                      textInputAction: TextInputAction.search,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search, color: _fondoBotones),
                    onPressed: () => _buscar(_searchController.text),
>>>>>>> Stashed changes
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
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF143278), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.destinoNombre!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // PANEL INFERIOR
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _fondoGeneral,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _botonReportar(),
                  const SizedBox(height: 15),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 3.0, // Aumentado ligeramente para mejor ajuste
                    children: [
                      _buildBotonCategoria(Icons.gavel, "Gobierno", const GobiernoPage()),
                      _buildBotonCategoria(Icons.local_hospital, "Hospitales", const HospitalPage()),
                      _buildBotonCategoria(Icons.shopping_cart, "Super", const SuperPage()),
                      _buildBotonCategoria(Icons.account_balance, "Bancos", const BancoPage()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonReportar() {
    return ElevatedButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ReportePage(categoria: 'general')),
      ),
      icon: Icon(Icons.warning_amber_rounded, color: _textoBotones),
      label: const Text('REPORTAR OBSTÁCULO', style: TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[900],
        minimumSize: const Size(double.infinity, 50),
      ),
    );
  }

  Widget _buildBotonCategoria(IconData icono, String texto, Widget paginaDestino) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _fondoBotones,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 5),
      ),
<<<<<<< Updated upstream
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => paginaDestino)),
      child: FittedBox( // Esto evita que el texto se salga del botón
        fit: BoxFit.scaleDown,
        child: Row(
          children: [
            Icon(icono, size: 18, color: _textoBotones),
            const SizedBox(width: 5),
            Text(texto, style: TextStyle(fontSize: 12, color: _textoBotones, fontWeight: FontWeight.bold)),
          ],
        ),
=======
      onPressed: () => _navegarACategoria(paginaDestino),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 20, color: _textoBotones),
          const SizedBox(width: 5),
          Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _textoBotones)),
        ],
>>>>>>> Stashed changes
      ),
    );
  }
}
