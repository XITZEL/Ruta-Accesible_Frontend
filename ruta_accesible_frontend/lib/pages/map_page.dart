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
import 'dart:async';

import 'report_page.dart';
import 'gobierno_page.dart';
import 'hospital_page.dart';
import 'super_page.dart';
import 'banco_page.dart';

const Color _fondoGeneral = Color(0xFFF5F7FA);
const Color _textoOscuro = Color(0xFF0A192F);
const Color _fondoBotones = Color(0xFF143278);
const Color _colorObstaculo = Color(0xFFE65100);

class MapPage extends StatefulWidget {
  final LatLng? destino;
  final String? destinoNombre;
  const MapPage({super.key, this.destino, this.destinoNombre});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  GoogleMapController? mapController;
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextEditingController _searchCtrl = TextEditingController();
  late AnimationController _micAnimCtrl;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  List<String> _instrucciones = [];
  int _pasoActual = 0;
  bool _trazandoRuta = false;
  bool _escuchando = false;

  final List<_Categoria> _categorias = [
    _Categoria(label: 'Salud', icono: Icons.local_hospital_rounded),
    _Categoria(label: 'Gobierno', icono: Icons.account_balance_rounded),
    _Categoria(label: 'Compras', icono: Icons.shopping_cart_rounded),
    _Categoria(label: 'Banco', icono: Icons.credit_card_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _micAnimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _tts.setLanguage('es-MX');
    _solicitarPermisos();
  }

  Future<void> _solicitarPermisos() async {
    await [Permission.location, Permission.microphone].request();
  }

  Future<void> _hablar(String texto) async => await _tts.speak(texto);

  Future<void> _toggleVoz() async {
    if (_escuchando) { await _speech.stop(); setState(() => _escuchando = false); return; }
    if (await _speech.initialize()) {
      setState(() => _escuchando = true);
      _speech.listen(onResult: (res) {
        if (res.finalResult) {
          _searchCtrl.text = res.recognizedWords;
          _buscarYRutear(res.recognizedWords);
          setState(() => _escuchando = false);
        }
      });
    }
  }

  Future<void> _buscarYRutear(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final pos = await Geolocator.getCurrentPosition();
      // Asegúrate de tener tu API KEY configurada en la variable de entorno o reemplázala aquí
      final url = Uri.parse('https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(query)}&location=${pos.latitude},${pos.longitude}&key=${const String.fromEnvironment('GOOGLE_MAPS_API_KEY')}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          await _trazarRuta(LatLng(loc['lat'], loc['lng']), nombre: data['results'][0]['name']);
        }
      }
    } catch (e) { debugPrint('Error búsqueda: $e'); }
  }

  Future<void> _trazarRuta(LatLng destino, {String? nombre}) async {
    setState(() => _trazandoRuta = true);
    try {
      final pos = await Geolocator.getCurrentPosition();
      final url = Uri.parse('https://ruta-accesible.vercel.app/api/route?originLat=${pos.latitude}&originLng=${pos.longitude}&destLat=${destino.latitude}&destLng=${destino.longitude}');
      final res = await http.get(url);
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final pts = PolylinePoints().decodePolyline(data['data']['points']);
        
        setState(() {
          _polylines = {Polyline(polylineId: const PolylineId('r'), points: pts.map((e) => LatLng(e.latitude, e.longitude)).toList(), color: _fondoBotones, width: 6)};
          _markers = {Marker(markerId: const MarkerId('dest'), position: destino, infoWindow: InfoWindow(title: nombre))};
          _instrucciones = (data['data']['steps'] as List).map((s) => s['instructions'] as String).toList();
          _pasoActual = 0;
        });

        mapController?.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(min(pos.latitude, destino.latitude), min(pos.longitude, destino.longitude)),
            northeast: LatLng(max(pos.latitude, destino.latitude), max(pos.longitude, destino.longitude)),
          ), 70
        ));
      }
    } catch (e) { debugPrint('Error ruta: $e'); }
    setState(() => _trazandoRuta = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoGeneral,
      body: Stack(children: [
        GoogleMap(
          onMapCreated: (c) => mapController = c,
          initialCameraPosition: const CameraPosition(target: LatLng(32.5149, -117.0382), zoom: 16),
          polylines: _polylines,
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
        ),
        Positioned(top: 50, left: 15, right: 15, child: _construirBarraBusqueda()),
        if (_instrucciones.isNotEmpty) Positioned(bottom: 150, left: 15, right: 15, child: _construirPanelInstrucciones()),
        Positioned(bottom: 0, left: 0, right: 0, child: _construirHojaInferior()),
        Positioned(right: 15, bottom: 270, child: FloatingActionButton(
          backgroundColor: Colors.white,
          onPressed: () async {
            Position pos = await Geolocator.getCurrentPosition();
            mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 17));
          },
          child: const Icon(Icons.my_location, color: _fondoBotones),
        )),
      ]),
    );
  }

  Widget _construirBarraBusqueda() {
    return Container(
      height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(blurRadius: 10)]),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        IconButton(icon: Icon(_escuchando ? Icons.mic_off : Icons.mic, color: _fondoBotones), onPressed: _toggleVoz),
        Expanded(child: TextField(controller: _searchCtrl, decoration: const InputDecoration(hintText: '¿A dónde vamos?', border: InputBorder.none))),
        IconButton(icon: const Icon(Icons.search, color: _fondoBotones), onPressed: () => _buscarYRutear(_searchCtrl.text)),
      ]),
    );
  }

  Widget _construirPanelInstrucciones() {
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _fondoBotones, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Expanded(child: Text(_instrucciones[_pasoActual], style: const TextStyle(color: Colors.white))),
        IconButton(onPressed: () => _hablar(_instrucciones[_pasoActual]), icon: const Icon(Icons.volume_up, color: Colors.white)),
      ]),
    );
  }

  Widget _construirHojaInferior() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ElevatedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportePage(categoria: 'general'))),
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
          label: const Text('REPORTAR OBSTÁCULO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: _colorObstaculo, minimumSize: const Size(double.infinity, 50)),
        ),
        const SizedBox(height: 15),
        Row(children: List.generate(_categorias.length, (i) => Expanded(child: _botonCat(_categorias[i], i)))),
      ]),
    );
  }

  Widget _botonCat(_Categoria cat, int i) {
    return InkWell(onTap: () {
      final pages = [HospitalPage(), GobiernoPage(), SuperPage(), BancoPage()];
      Navigator.push(context, MaterialPageRoute(builder: (_) => pages[i]));
    }, child: Column(children: [Icon(cat.icono, color: _fondoBotones), Text(cat.label)]));
  }
}

class _Categoria { final String label; final IconData icono; const _Categoria({required this.label, required this.icono}); }