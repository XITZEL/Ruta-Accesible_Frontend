import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart'; 
import 'package:flutter_polyline_points/flutter_polyline_points.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'report_page.dart'; 

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  final LatLng _centroDefault = const LatLng(32.5149, -117.0382);
  
  Position? _posicionActual;
  Set<Marker> marcadoresElementos = {};
  Set<Polyline> _polylines = {}; 
  
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _searchController = TextEditingController();

  // Trae la API Key guardada de forma segura en tu archivo .env
  final String _googleApiKey = dotenv.get('GOOGLE_MAPS_API_KEY', fallback: '');

  // Tu paleta de colores oficial WCAG AAA (Lectura ultra clara)
  final Color _fondoGeneral = const Color(0xFFF5F7FA);     // Gris muy claro
  final Color _textoPrincipal = const Color(0xFF0A192F);   // Azul marino casi negro
  final Color _fondoBotones = const Color(0xFF143278);     // Azul rey oscuro
  final Color _textoBotones = const Color(0xFFFFFFFF);     // Blanco puro

  @override
  void initState() {
    super.initState();
    _configurarTTS();
    _determinarUbicacion();
  }

  void _configurarTTS() async {
    await _tts.setLanguage("es-MX"); 
    await _tts.setSpeechRate(0.45); // Velocidad pausada y cómoda
    await _tts.setVolume(1.0);
    _hablar("Bienvenido. Presiona un botón abajo para buscar lugares seguros.");
  }

  Future<void> _hablar(String texto) async {
    await _tts.speak(texto);
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // Obtiene la ubicación real por GPS
  Future<void> _determinarUbicacion() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _hablar("Por favor, activa el GPS de tu teléfono.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    _posicionActual = await Geolocator.getCurrentPosition();
    if (_posicionActual != null) {
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_posicionActual!.latitude, _posicionActual!.longitude), 15.0),
      );
    }
  }

  // PETICIÓN REAL A TU ENDPOINT DE VERCEL (/api/places)
  Future<void> _cargarPuntosInteres({required String categoriaApi}) async {
    if (_posicionActual == null) {
      _hablar("Buscando tu señal de GPS, por favor espera un momento.");
      return;
    }

    _hablar("Buscando opciones cercanas.");

    final url = Uri.parse(
      'https://ruta-accessible.vercel.app/api/places?'
      'lat=${_posicionActual!.latitude}'
      '&lng=${_posicionActual!.longitude}'
      '&category=$categoriaApi'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          Set<Marker> nuevosMarcadores = {};

          for (var lugar in data['data']) {
            double lat = double.parse(lugar['lat'].toString());
            double lng = double.parse(lugar['lng'].toString());
            String nombreLugar = lugar['name'].toString();
            String direccion = lugar['address'] ?? 'Dirección no disponible';

            nuevosMarcadores.add(Marker(
              markerId: MarkerId(lugar['id'].toString()),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              onTap: () {
                _mostrarDetalleYTrazaRuta(nombreLugar, direccion, LatLng(lat, lng));
              },
            ));
          }

          setState(() {
            marcadoresElementos = nuevosMarcadores;
          });

          if (nuevosMarcadores.isEmpty) {
            _hablar("No encontré lugares de esa categoría cerca de ti.");
          } else {
            _hablar("Hecho. Presiona los puntos rojos en el mapa para ver la ruta.");
          }
        }
      }
    } catch (e) {
      debugPrint('Error de conexión con Vercel: $e');
      _hablar("Hubo un problema al conectar con el servidor.");
    }
  }

  // MUESTRA DETALLES Y TRAZA LA LÍNEA REAL EN LAS CALLES
  void _mostrarDetalleYTrazaRuta(String titulo, String direccion, LatLng destino) {
    _hablar("Calculando el camino más accesible hacia $titulo.");
    
    _obtenerRutaGoogleMapsReal(destino);

    showModalBottomSheet(
      context: context,
      backgroundColor: _fondoGeneral,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titulo, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textoPrincipal)),
              const SizedBox(height: 8),
              Text(direccion, style: TextStyle(fontSize: 18, color: _textoPrincipal.withValues(alpha: 0.8))),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _fondoBotones, 
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: () => Navigator.pop(context),
                child: Text("Ver Ruta en Mapa", style: TextStyle(fontSize: 20, color: _textoBotones, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }

  // MÈTODO DE GOOGLE DIRECTIONS CORREGIDO (NUEVA SINTAXIS)
  Future<void> _obtenerRutaGoogleMapsReal(LatLng destino) async {
    if (_posicionActual == null) return;

    LatLng origen = LatLng(_posicionActual!.latitude, _posicionActual!.longitude);

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${origen.latitude},${origen.longitude}&destination=${destino.latitude},${destino.longitude}&mode=walking&key=$_googleApiKey'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        
        if (jsonResponse['status'] == 'OK') {
          String puntosCodificados = jsonResponse['routes'][0]['overview_polyline']['points'];
          
          // Ajustado perfectamente a la última versión de tu librería:
          PolylinePoints polylinePoints = PolylinePoints(apiKey: _googleApiKey);
          List<PointLatLng> puntosDecodificados = PolylinePoints.decodePolyline(puntosCodificados);

          List<LatLng> coordenadasRuta = puntosDecodificados
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();

          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId("ruta_real_google"),
                points: coordenadasRuta,
                color: _fondoBotones, 
                width: 8, // Grueso y visible para personas mayores
              )
            };
          });

          mapController?.animateCamera(CameraUpdate.newLatLngZoom(origen, 16.0));
        }
      }
    } catch (e) {
      debugPrint("Error Directions API: $e");
    }
  }

  void _escucharVoz() {
    _hablar("Dime qué categoría buscas.");
    Future.delayed(const Duration(seconds: 3), () {
      _searchController.text = "Hospitales";
      _cargarPuntosInteres(categoriaApi: "hospital");
    });
  }

  void _irAPantallaDeReporte(BuildContext context, String categoria) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReportePage(categoria: categoria)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoGeneral,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(target: _centroDefault, zoom: 16.0),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: marcadoresElementos,
            polylines: _polylines, 
          ),

          // BUSCADOR SUPERIOR
          Positioned(
            top: 50, left: 15, right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _fondoGeneral, 
                borderRadius: BorderRadius.circular(15), 
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.mic, size: 35, color: _fondoBotones),
                    onPressed: _escucharVoz, 
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textoPrincipal),
                      decoration: InputDecoration(
                        hintText: '¿A dónde vamos?',
                        hintStyle: TextStyle(color: _textoPrincipal.withValues(alpha: 0.5)),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (value) => _cargarPuntosInteres(categoriaApi: value.trim().toLowerCase()),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.search, size: 35, color: _fondoBotones),
                    onPressed: () => _cargarPuntosInteres(categoriaApi: _searchController.text.trim().toLowerCase()),
                  ),
                ],
              ),
            ),
          ),

          // PANEL INFERIOR ACCESIBLE CON LAS 4 CATEGORÍAS REALES
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 15, bottom: 25, left: 15, right: 15),
              decoration: BoxDecoration(
                color: _fondoGeneral, 
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 3)]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _irAPantallaDeReporte(context, 'general'),
                    icon: Icon(Icons.warning_amber_rounded, color: _textoBotones, size: 28),
                    label: Text('REPORTAR OBSTÁCULO', style: TextStyle(fontSize: 20, color: _textoBotones, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[900], 
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                  ),
                  const SizedBox(height: 15),

                  Text(
                    "Accesos rápidos:", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textoPrincipal)
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _buildBotonCategoria(Icons.gavel, "Gobierno", "gobierno"),
                      _buildBotonCategoria(Icons.local_hospital, "Hospitales", "hospital"),
                      _buildBotonCategoria(Icons.shopping_cart, "Supermercados", "super"),
                      _buildBotonCategoria(Icons.account_balance, "Bancos", "banco"),
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

  Widget _buildBotonCategoria(IconData icono, String texto, String parametroApi) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _fondoBotones, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 3,
      ),
      onPressed: () {
        _searchController.text = texto;
        _cargarPuntosInteres(categoriaApi: parametroApi);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 36, color: _textoBotones), 
          const SizedBox(height: 6),
          Text(texto, style: TextStyle(fontSize: 17, color: _textoBotones, fontWeight: FontWeight.bold), textAlign: TextAlign.center)
        ],
      ),
    );
  }
}