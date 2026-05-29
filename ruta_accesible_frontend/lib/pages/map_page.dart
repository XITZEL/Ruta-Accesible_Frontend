import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:convert';
import 'dart:math';
import 'dart:async'; // 👈 Necesario para StreamSubscription

// Pantallas secundarias asignadas a las categorías
import 'report_page.dart';
import 'gobierno_page.dart';
import 'hospital_page.dart';
import 'super_page.dart';
import 'banco_page.dart';

// ─────────────────────────────────────────────
//  PALETA DE COLORES - Alta visibilidad (Adultos Mayores)
// ─────────────────────────────────────────────
const Color _fondoGeneral   = Color(0xFFF5F7FA); // Gris muy claro
const Color _textoOscuro    = Color(0xFF0A192F); // Azul marino casi negro
const Color _fondoBotones   = Color(0xFF143278); // Azul rey oscuro
const Color _textoBotones   = Color(0xFFFFFFFF); // Blanco puro
const Color _colorObstaculo = Color(0xFFE65100); // Naranja fuerte para el botón de reporte
const Color _colorAlerta    = Color(0xFFF57F17); // Amarillo/Naranja advertencia para banners

class MapPage extends StatefulWidget {
  final LatLng? destino;
  final String? destinoNombre;
  const MapPage({super.key, this.destino, this.destinoNombre});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  // ── Controladores y Servicios ──────────────────────────
  GoogleMapController? mapController;
  final FlutterTts          _tts            = FlutterTts();
  final TextEditingController _searchCtrl   = TextEditingController();
  final stt.SpeechToText    _speech         = stt.SpeechToText();
  late AnimationController  _micAnimCtrl;
  late Animation<double>    _micPulse;

  // ── Estado del Mapa y Flujos ────────────────────────
  final LatLng _centroDefault = const LatLng(32.5149, -117.0382);
  Set<Polyline> _polylines   = {};
  Set<Marker>   _markers     = {};
  bool _permisosListos       = false;
  bool _escuchando           = false;
  bool _trazandoRuta         = false;

  // ── Navegación Asistida por Voz (TTS) ──────────
  List<String> _instrucciones = [];
  int _pasoActual             = 0;
  bool _leyendoRuta           = false;
  StreamSubscription<Position>? _posStream;

  // ── Monitoreo de Obstáculos ─────────────────────
  List<Map<String, dynamic>> _reportesCercanos = [];
  bool _mostrarBannerReporte = false;

  // ── Modelado de Categorías de Interés ────────────────────────────
  final List<_Categoria> _categorias = [
    _Categoria(label: 'Salud',    icono: Icons.local_hospital_rounded),
    _Categoria(label: 'Gobierno', icono: Icons.account_balance_rounded),
    _Categoria(label: 'Compras',  icono: Icons.shopping_cart_rounded),
    _Categoria(label: 'Banco',    icono: Icons.credit_card_rounded),
  ];

  // ─────────────────────────────────────────
  //  CICLO DE VIDA
  // ─────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Animación pulsante para el micrófono de adultos mayores
    _micAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _micPulse = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _micAnimCtrl, curve: Curves.easeInOut),
    );
    
    _configurarTTS();
    _solicitarPermisos();
  }

  @override
  void dispose() {
    _micAnimCtrl.dispose();
    _posStream?.cancel();
    _tts.stop();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  //  GESTIÓN DE PERMISOS
  // ─────────────────────────────────────────
  Future<void> _solicitarPermisos() async {
    final statuses = await [
      Permission.location,
      Permission.microphone,
    ].request();

    final ubicacionOk  = statuses[Permission.location]?.isGranted  ?? false;
    final microfonoOk  = statuses[Permission.microphone]?.isGranted ?? false;

    if (!mounted) return;

    if (!ubicacionOk) {
      _mostrarDialogoPermiso(
        titulo:  'Ubicación requerida',
        mensaje: 'Esta aplicación necesita conocer su ubicación para trazar rutas accesibles y seguras. Por favor actívela en Ajustes.',
        icono:   Icons.location_on,
      );
      return;
    }

    if (!microfonoOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sin micrófono no podrá usar los comandos de voz, pero puede escribir el destino.',
            style: TextStyle(fontSize: 16),
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }

    setState(() => _permisosListos = true);
    await _cargarReportes();

    if (widget.destino != null) {
      await _trazarRuta(widget.destino!, nombre: widget.destinoNombre);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(icono, color: _fondoBotones, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text(titulo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textoOscuro))),
        ]),
        content: Text(mensaje, style: const TextStyle(fontSize: 17, color: _textoOscuro, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); openAppSettings(); },
            child: const Text('Abrir Ajustes', style: TextStyle(fontSize: 17, color: _fondoBotones, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(fontSize: 17, color: _textoOscuro)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  SÍNTESIS DE VOZ (TTS)
  // ─────────────────────────────────────────
  void _configurarTTS() async {
    await _tts.setLanguage('es-MX');
    await _tts.setSpeechRate(0.40); // Velocidad reducida idónea para adultos mayores
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> _hablar(String texto) async {
    await _tts.stop();
    await _tts.speak(texto);
  }

  // ─────────────────────────────────────────
  //  RECONOCIMIENTO DE VOZ (STT)
  // ─────────────────────────────────────────
  Future<void> _toggleVoz() async {
    if (_escuchando) {
      await _speech.stop();
      _micAnimCtrl.stop();
      setState(() => _escuchando = false);
      return;
    }

    final disponible = await _speech.initialize(
      onError: (e) {
        setState(() => _escuchando = false);
        _micAnimCtrl.stop();
        _hablar('No logré escuchar correctamente. Por favor, intente de nuevo.');
      },
    );

    if (!disponible) {
      _hablar('El micrófono no está disponible en este momento.');
      return;
    }

    setState(() => _escuchando = true);
    _micAnimCtrl.repeat(reverse: true);
    await _hablar('¿A dónde quiere ir?');

    _speech.listen(
      localeId: 'es_MX',
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      onResult: (result) async {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          final texto = result.recognizedWords;
          setState(() {
            _searchCtrl.text = texto;
            _escuchando = false;
          });
          _micAnimCtrl.stop();
          await _speech.stop();
          await _buscarYRutear(texto);
        }
      },
    );
  }

  // ─────────────────────────────────────────
  //  MOTOR DE BÚSQUEDA Y GEOLOCALIZACIÓN
  // ─────────────────────────────────────────
  Future<void> _buscarYRutear(String query) async {
    if (query.trim().isEmpty) return;

    await _hablar('Buscando $query. Un momento por favor.');
    try {
      final pos = await Geolocator.getCurrentPosition();
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json'
        '?query=${Uri.encodeComponent(query)}'
        '&location=${pos.latitude},${pos.longitude}'
        '&radius=10000&language=es&key=${const String.fromEnvironment('GOOGLE_MAPS_API_KEY')}',
      );
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final place = results.first;
          final lat   = place['geometry']['location']['lat'] as double;
          final lng   = place['geometry']['location']['lng'] as double;
          final nombre= place['name'] as String;
          await _trazarRuta(LatLng(lat, lng), nombre: nombre);
        } else {
          await _hablar('No encontré ningún lugar con ese nombre. Intente de nuevo.');
        }
      }
    } catch (e) {
      debugPrint('Error en la búsqueda de lugares: $e');
      await _hablar('Hubo un percance al buscar. Compruebe su conexión a internet.');
    }
  }

  // ─────────────────────────────────────────
  //  CARGA Y ANÁLISIS DE OBSTÁCULOS CERCANOS
  // ─────────────────────────────────────────
  Future<void> _cargarReportes() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final response = await http.get(
        Uri.parse('https://ruta-accesible.vercel.app/api/reportes'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final nuevosMarkers = <Marker>{};
        final cercanos      = <Map<String, dynamic>>[];

        for (var item in data) {
          if (item['estado'] == 'resuelto') continue;

          final rLat = (item['lat'] as num).toDouble();
          final rLng = (item['lng'] as num).toDouble();
          final dist = _calcularDistancia(pos.latitude, pos.longitude, rLat, rLng);

          final color = (item['estado'] == 'verificado')
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueOrange;

          nuevosMarkers.add(Marker(
            markerId: MarkerId('reporte_${item['id']}'),
            position: LatLng(rLat, rLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(color),
            infoWindow: InfoWindow(
              title: '⚠ Obstáculo: ${item['tipo']}',
              snippet: item['descripcion'],
            ),
          ));

          // Filtro proactivo de seguridad: Advertir si está a menos de 500 metros
          if (dist < 500) {
            cercanos.add({'tipo': item['tipo'], 'descripcion': item['descripcion']});
          }
        }

        setState(() {
          _markers.addAll(nuevosMarkers);
          _reportesCercanos       = cercanos;
          _mostrarBannerReporte   = cercanos.isNotEmpty;
        });

        if (cercanos.isNotEmpty) {
          final tipos = cercanos.map((r) => r['tipo']).join(', ');
          await _hablar(
            'Atención. Se detectaron ${cercanos.length} obstáculos en su perímetro cercano: $tipos. Avance con precaución.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error cargando reportes: $e');
    }
  }

  double _calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Radio de la Tierra en metros
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  // ─────────────────────────────────────────
  //  TRAZADO DE RUTA E INSTRUCCIONES EN VIVO
  // ─────────────────────────────────────────
  Future<void> _trazarRuta(LatLng destino, {String? nombre}) async {
    if (_trazandoRuta) return;
    setState(() => _trazandoRuta = true);

    try {
      final pos   = await Geolocator.getCurrentPosition();
      final inicio = LatLng(pos.latitude, pos.longitude);

      final url = Uri.parse(
        'https://ruta-accesible.vercel.app/api/route'
        '?originLat=${inicio.latitude}&originLng=${inicio.longitude}'
        '&destLat=${destino.latitude}&destLng=${destino.longitude}',
      );
      final response = await http.get(url);
      if (!mounted) return;

      List<LatLng> coords       = [inicio, destino];
      List<String> instrucciones = [];

      if (response.statusCode == 200) {
        final data    = json.decode(response.body);
        final encoded = data['data']?['points'] as String? ?? '';
        if (encoded.isNotEmpty) {
          coords = PolylinePoints()
              .decodePolyline(encoded)
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList();
        }
        
        final steps = data['data']?['steps'] as List? ?? [];
        instrucciones = steps
            .map<String>((s) => s['instructions']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }

      if (instrucciones.isEmpty) {
        instrucciones = [
          'Ruta trazada hacia ${nombre ?? 'su destino'}.',
          'Continúe avanzando en la dirección indicada en la pantalla.',
          'Ha llegado exitosamente a su destino: ${nombre ?? 'el lugar seleccionado'}.',
        ];
      }

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('ruta'),
            points: coords,
            color: _fondoBotones,
            width: 6,
          ),
        };
        _markers.add(Marker(
          markerId: const MarkerId('destino'),
          position: destino,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: nombre ?? 'Destino'),
        ));
        _instrucciones = instrucciones;
        _pasoActual    = 0;
        _leyendoRuta   = true;
      });

      if (mapController != null && coords.length > 1) {
        final bounds = _calcularBounds(coords);
        mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      }

      await _hablar(_instrucciones[0]);
      _iniciarSeguimientoRuta(coords);

    } catch (e) {
      debugPrint('Error trazando ruta: $e');
      await _hablar('No fue posible estructurar la ruta. Compruebe la red.');
    } finally {
      if (mounted) setState(() => _trazandoRuta = false);
    }
  }

  LatLngBounds _calcularBounds(List<LatLng> coords) {
    double minLat = coords.first.latitude,  maxLat = coords.first.latitude;
    double minLng = coords.first.longitude, maxLng = coords.first.longitude;
    for (final c in coords) {
      if (c.latitude  < minLat) minLat = c.latitude;
      if (c.latitude  > maxLat) maxLat = c.latitude;
      if (c.longitude < minLng) minLng = c.longitude;
      if (c.longitude > maxLng) maxLng = c.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _iniciarSeguimientoRuta(List<LatLng> coords) {
    _posStream?.cancel();
    if (_instrucciones.length <= 1) return;

    final segmentos = _instrucciones.length;
    final paso      = coords.length ~/ segmentos;

    final waypoints = List.generate(
      segmentos,
      (i) => coords[min(i * paso, coords.length - 1)],
    );

    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    ).listen((pos) async {
      if (!_leyendoRuta || _pasoActual >= _instrucciones.length - 1) return;
      final siguiente = waypoints[_pasoActual + 1];
      final dist = _calcularDistancia(
        pos.latitude, pos.longitude,
        siguiente.latitude, siguiente.longitude,
      );
      if (dist < 40) {
        setState(() => _pasoActual++);
        await _hablar(_instrucciones[_pasoActual]);
        if (_pasoActual == _instrucciones.length - 1) {
          _posStream?.cancel();
          setState(() => _leyendoRuta = false);
        }
      }
    });
  }

  void _leerInstruccionActual() => _hablar(_instrucciones[_pasoActual]);

  void _siguienteInstruccion() {
    if (_pasoActual < _instrucciones.length - 1) {
      setState(() => _pasoActual++);
      _hablar(_instrucciones[_pasoActual]);
    }
  }

  void _anteriorInstruccion() {
    if (_pasoActual > 0) {
      setState(() => _pasoActual--);
      _hablar(_instrucciones[_pasoActual]);
    }
  }

  // ─────────────────────────────────────────
  //  BOTÓN DE RE-CENTRADOS
  // ─────────────────────────────────────────
  Future<void> _centrarEnUsuario() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 18),
      );
      _hablar('Mapa centrado en su ubicación actual.');
    } catch (e) {
      debugPrint('Error al centrar mapa: $e');
    }
  }

  // ─────────────────────────────────────────
  //  RUTEOS POR CATEGORÍA INTERNA
  // ─────────────────────────────────────────
  void _navegarCategoria(int index) {
    final pages = [
      HospitalPage(),
      GobiernoPage(),
      SuperPage(),
      BancoPage(),
    ];
    _hablar('Mostrando establecimientos de ${_categorias[index].label} próximos a usted.');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => pages[index]),
    );
  }

  // ─────────────────────────────────────────
  //  DISEÑO GENERAL DE LA INTERFAZ (UI)
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_permisosListos) {
      return Scaffold(
        backgroundColor: _fondoGeneral,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: _fondoBotones, strokeWidth: 5),
              const SizedBox(height: 20),
              const Text(
                'Preparando el mapa de accesibilidad…',
                style: TextStyle(fontSize: 19, color: _textoOscuro, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _fondoGeneral,
      body: Stack(
        children: [
          // Capa Base: El Mapa de Google
          GoogleMap(
            onMapCreated: (ctrl) {
              mapController = ctrl;
              if (widget.destino != null && _polylines.isEmpty) {
                _trazarRuta(widget.destino!, nombre: widget.destinoNombre);
              }
            },
            initialCameraPosition: CameraPosition(target: _centroDefault, zoom: 17.5),
            myLocationEnabled:        true,
            myLocationButtonEnabled:  false,
            zoomControlsEnabled:      false,
            polylines: _polylines,
            markers:   _markers,
          ),

          // Capa Superior 1: Caja de Búsqueda Integrada con Botón de Voz Inteligente
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 14,
            right: 14,
            child: _construirBarraBusqueda(),
          ),

          // Capa Superior 2: Alertas de Obstáculos en ruta directa
          if (_mostrarBannerReporte)
            Positioned(
              top: MediaQuery.of(context).padding.top + 88,
              left: 14,
              right: 14,
              child: _construirBannerReportes(),
            ),

          // Capa Superior 3: Panel Dinámico de Control de Guiado
          if (_leyendoRuta && _instrucciones.isNotEmpty)
            Positioned(
              bottom: 220,
              left: 14,
              right: 14,
              child: _construirPanelInstrucciones(),
            ),

          // Capa Superior 4: Botón Grande Flotante para Ubicación Directa
          Positioned(
            bottom: (_leyendoRuta && _instrucciones.isNotEmpty) ? 410 : 220,
            right: 14,
            child: _construirBotonCentrar(),
          ),

          // Capa Superior 5: Pantalla de Carga de Ruta Tapando Mapa Temporalmente
          if (_trazandoRuta)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white, strokeWidth: 5),
                      SizedBox(height: 16),
                      Text('Trazando camino accesible…', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),

          // Capa Superior 6: Hoja Baja Accesible permanente
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _construirHojaInferior(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  //  MÓDULOS DE WIDGETS AUXILIARES
  // ─────────────────────────────────────────
  Widget _construirBarraBusqueda() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.search, color: _fondoBotones, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 18, color: _textoOscuro, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '¿A dónde desea ir?',
                hintStyle: TextStyle(fontSize: 18, color: Color(0xFF78909C), fontWeight: FontWeight.w500),
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => _buscarYRutear(v),
            ),
          ),
          GestureDetector(
            onTap: _toggleVoz,
            child: AnimatedBuilder(
              animation: _micPulse,
              builder: (_, child) => Transform.scale(
                scale: _escuchando ? _micPulse.value : 1.0,
                child: child,
              ),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _escuchando ? Colors.red.shade800 : _fondoBotones,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _escuchando ? Icons.mic_off : Icons.mic,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBannerReportes() {
    return GestureDetector(
      onTap: () {
        final texto = _reportesCercanos.map((r) => '${r['tipo']}: ${r['descripcion']}').join('. ');
        _hablar('Obstáculos detectados: $texto');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _colorAlerta,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 8)],
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hay ${_reportesCercanos.length} peligro${_reportesCercanos.length > 1 ? 's' : ''} cerca. Presione aquí para oír.',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.volume_up, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _construirPanelInstrucciones() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fondoBotones,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x3D000000), blurRadius: 14, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.navigation_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                'Instrucción ${_pasoActual + 1} de ${_instrucciones.length}',
                style: const TextStyle(color: Color(0xFFE3F2FD), fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              IconButton(
                onPressed: _leerInstruccionActual,
                icon: const Icon(Icons.volume_up, color: Colors.white, size: 26),
                tooltip: 'Repetir audio',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _instrucciones[_pasoActual],
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold, height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pasoActual > 0 ? _anteriorInstruccion : null,
                  icon: const Icon(Icons.arrow_back, size: 22),
                  label: const Text('Anterior', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white60, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pasoActual < _instrucciones.length - 1 ? _siguienteInstruccion : null,
                  icon: const Icon(Icons.arrow_forward, size: 22),
                  label: const Text('Siguiente', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white60, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirBotonCentrar() {
    return FloatingActionButton.large(
      heroTag: 're_centrar_user',
      onPressed: _centrarEnUsuario,
      backgroundColor: Colors.white,
      elevation: 6,
      child: const Icon(Icons.my_location, color: _fondoBotones, size: 34),
    );
  }

  Widget _construirHojaInferior() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 45, height: 5,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: const Color(0xFFB0BEC5), borderRadius: BorderRadius.circular(10)),
          ),
          // Botón de Reportar
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: () {
                _hablar('Abriendo formulario para reportar un obstáculo.');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReportePage(categoria: 'general')),
                );
              },
              icon: const Icon(Icons.warning_amber_rounded, size: 26, color: Colors.white),
              label: const Text('REPORTAR OBSTÁCULO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorObstaculo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Fila de Categorías Accesibles
          Row(
            children: List.generate(_categorias.length, (i) {
              final cat = _categorias[i];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: i == 0 ? 0 : 4, 
                    right: i == _categorias.length - 1 ? 0 : 4
                  ),
                  child: _construirBotonCategoria(cat, i),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _construirBotonCategoria(_Categoria cat, int index) {
    return InkWell(
      onTap: () => _navegarCategoria(index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC5D4EE), width: 1.8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cat.icono, color: _fondoBotones, size: 30),
            const SizedBox(height: 6),
            Text(
              cat.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _textoOscuro),
            ),
          ],
        ),
      ),
    );
  }
}

class _Categoria {
  final String label;
  final IconData icono;
  const _Categoria({required this.label, required this.icono});
}