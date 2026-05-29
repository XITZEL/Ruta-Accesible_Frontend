import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart'; // 👈 NUEVO
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

  bool _permisosListos = false; // 👈 NUEVO: controla si ya tenemos permisos

  final Color _fondoGeneral = const Color(0xFFF5F7FA);
  final Color _fondoBotones = const Color(0xFF143278);
  final Color _textoBotones = const Color(0xFFFFFFFF);

  // ─────────────────────────────────────────────
  //  CICLO DE VIDA
  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _configurarTTS();
    _solicitarPermisos(); // 👈 Primero pedimos permisos
  }

  // ─────────────────────────────────────────────
  //  PERMISOS (ubicación + micrófono)
  // ─────────────────────────────────────────────
  Future<void> _solicitarPermisos() async {
    // Pedimos ubicación y micrófono al mismo tiempo
    final statuses = await [
      Permission.location,
      Permission.microphone,
    ].request();

    final ubicacionOk = statuses[Permission.location]?.isGranted ?? false;
    final microfonoOk = statuses[Permission.microphone]?.isGranted ?? false;

    if (!mounted) return;

    if (!ubicacionOk) {
      // Sin ubicación no podemos trazar rutas → mostramos aviso
      _mostrarDialogoPermiso(
        titulo: 'Ubicación requerida',
        mensaje:
            'Esta app necesita acceso a tu ubicación para trazar rutas accesibles. '
            'Por favor actívala en Ajustes.',
        icono: Icons.location_on,
      );
      return;
    }

    if (!microfonoOk) {
      // Micrófono opcional → avisamos pero continuamos
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Sin micrófono no podrás usar comandos de voz, '
              'pero la app sigue funcionando.'),
          duration: Duration(seconds: 4),
        ),
      );
    }

    setState(() => _permisosListos = true);
    await _cargarReportes();

    // Si ya venimos con un destino, trazamos la ruta
    if (widget.destino != null) {
      _trazarRuta(widget.destino!);
    }
  }

  void _mostrarDialogoPermiso({
    required String titulo,
    required String mensaje,
    required IconData icono,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(icono, color: _fondoBotones),
          const SizedBox(width: 8),
          Text(titulo),
        ]),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // Abre ajustes del sistema
            },
            child: const Text('Abrir Ajustes'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  TTS
  // ─────────────────────────────────────────────
  void _configurarTTS() async {
    await _tts.setLanguage("es-MX");
    await _tts.setSpeechRate(0.45);
  }

  Future<void> _hablar(String texto) async => await _tts.speak(texto);

  // ─────────────────────────────────────────────
  //  REPORTES
  // ─────────────────────────────────────────────
  Future<void> _cargarReportes() async {
    try {
      final response = await http
          .get(Uri.parse('https://ruta-accesible.vercel.app/api/reportes'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          for (var item in data) {
            _markers.add(Marker(
              markerId: MarkerId(item['id'].toString()),
              position: LatLng(item['lat'], item['lng']),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange),
              infoWindow: InfoWindow(
                title: "Obstáculo: ${item['tipo']}",
                snippet: item['descripcion'],
              ),
            ));
          }
        });
      }
    } catch (e) {
      debugPrint("Error cargando reportes: $e");
    }
  }

  // ─────────────────────────────────────────────
  //  RUTA
  // ─────────────────────────────────────────────
  Future<void> _trazarRuta(LatLng destino) async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      final inicio = LatLng(pos.latitude, pos.longitude);
      final url = Uri.parse(
          'https://ruta-accesible.vercel.app/api/route'
          '?originLat=${inicio.latitude}&originLng=${inicio.longitude}'
          '&destLat=${destino.latitude}&destLng=${destino.longitude}');
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
            color: _fondoBotones,
            width: 5,
          )
        };
        _markers.add(Marker(
          markerId: const MarkerId('destino'),
          position: destino,
          infoWindow:
              InfoWindow(title: widget.destinoNombre ?? 'Destino'),
        ));
      });
      _hablar(
          "Ruta trazada hacia ${widget.destinoNombre ?? 'tu destino'}");
    } catch (e) {
      debugPrint('Error trazando ruta: $e');
    }
  }

  // ─────────────────────────────────────────────
  //  UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Mientras no tenemos permisos mostramos pantalla de carga
    if (!_permisosListos) {
      return Scaffold(
        backgroundColor: _fondoGeneral,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _fondoBotones),
              const SizedBox(height: 16),
              const Text('Solicitando permisos…'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _fondoGeneral,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              mapController = controller;
              // La ruta ya se traza en _solicitarPermisos()
              // pero si el mapa tardó más, la volvemos a trazar aquí
              if (widget.destino != null && _polylines.isEmpty) {
                _trazarRuta(widget.destino!);
              }
            },
            initialCameraPosition:
                CameraPosition(target: _centroDefault, zoom: 16.0),
            myLocationEnabled: true,
            polylines: _polylines,
            markers: _markers,
          ),

          // Botón reportar obstáculo
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: () {
                // ✅ Sin 'const' porque ReportePage tiene estado interno
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ReportePage(categoria: 'general'), // 👈 sin const
                  ),
                );
              },
              icon: Icon(Icons.warning_amber_rounded, color: _textoBotones),
              label: const Text('REPORTAR OBSTÁCULO'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[900]),
            ),
          ),
        ],
      ),
    );
  }
}