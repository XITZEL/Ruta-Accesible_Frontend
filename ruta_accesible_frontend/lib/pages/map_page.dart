import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'report_page.dart';
// Importa tus páginas de destino
import 'gobierno_page.dart';
import 'hospital_page.dart';
import 'super_page.dart';
import 'banco_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  final LatLng _centroDefault = const LatLng(32.5149, -117.0382);
  final FlutterTts _tts = FlutterTts();
  
  // Colores de Alta Accesibilidad
  final Color _fondoGeneral = const Color(0xFFF5F7FA);
  final Color _fondoBotones = const Color(0xFF143278);
  final Color _textoBotones = const Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _configurarTTS();
  }

  void _configurarTTS() async {
    await _tts.setLanguage("es-MX");
    await _tts.setSpeechRate(0.45);
  }

  Future<void> _hablar(String texto) async => await _tts.speak(texto);

  // LÓGICA DE NAVEGACIÓN CENTRALIZADA
  // Al presionar una categoría, navegamos a la página específica.
  // La página destino (ej. HospitalPage) será la encargada de llamar a la API
  // usando la categoría que le corresponde.
  void _navegarACategoria(Widget paginaDestino) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => paginaDestino),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoGeneral,
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: CameraPosition(target: _centroDefault, zoom: 16.0),
            myLocationEnabled: true,
          ),

          // BUSCADOR (Interacción de Voz)
          Positioned(
            top: 50, left: 15, right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _fondoGeneral,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]
              ),
              child: Row(
                children: [
                  IconButton(icon: Icon(Icons.mic, color: _fondoBotones), onPressed: () => _hablar("¿Qué lugar buscas?")),
                  const Expanded(child: TextField(decoration: InputDecoration(border: InputBorder.none, hintText: '¿A dónde vamos?'))),
                ],
              ),
            ),
          ),

          // PANEL INFERIOR: Navegación entre categorías
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _fondoGeneral,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _botonReportar(),
                  const SizedBox(height: 15),
                  
                  // GRID DE NAVEGACIÓN
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.8,
                    children: [
                      _buildBotonCategoria(Icons.gavel, "Gobierno", GobiernoPage()),
                      _buildBotonCategoria(Icons.local_hospital, "Hospitales", HospitalPage()),
                      _buildBotonCategoria(Icons.shopping_cart, "Super", SuperPage()),
                      _buildBotonCategoria(Icons.account_balance, "Bancos", BancoPage()),
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
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportePage(categoria: 'general'))),
      icon: Icon(Icons.warning_amber_rounded, color: _textoBotones),
      label: const Text('REPORTAR OBSTÁCULO', style: TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[900], minimumSize: const Size(double.infinity, 50)),
    );
  }

  Widget _buildBotonCategoria(IconData icono, String texto, Widget paginaDestino) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _fondoBotones,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => _navegarACategoria(paginaDestino),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 20, color: _textoBotones),
          const SizedBox(width: 5),
          Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}