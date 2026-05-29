import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'report_page.dart';
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
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  
  // PALETA AZUL APLICADA
  final Color _fondoGeneral = const Color(0xFFF5F7FA);
  final Color _textoPrincipal = const Color(0xFF0A192F);
  final Color _fondoBotones = const Color(0xFF143278);
  final Color _textoBotones = const Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _configurarTTS();
    _speech.initialize();
  }

  void _configurarTTS() async {
    await _tts.setLanguage("es-MX");
    await _tts.setSpeechRate(0.45);
  }

  Future<void> _hablar(String texto) async => await _tts.speak(texto);

  void _escucharBusqueda() async {
    if (!_isListening) {
      bool disponible = await _speech.initialize();
      if (disponible) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (result) {
          if (result.finalResult) {
            setState(() => _isListening = false);
            _procesarComandoVoz(result.recognizedWords.toLowerCase());
          }
        });
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  void _procesarComandoVoz(String texto) {
    Widget? destino;
    if (texto.contains("gobierno")) destino = const GobiernoPage();
    else if (texto.contains("hospital")) destino = const HospitalPage();
    else if (texto.contains("banco")) destino = const BancoPage();
    else if (texto.contains("super")) destino = const SuperPage();
    
    if (destino != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => destino!));
    } else {
      _hablar("No encontré esa categoría, intenta decir Gobierno, Hospital, Banco o Super.");
    }
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

          Positioned(
            top: 50, left: 15, right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _fondoGeneral,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(_isListening ? Icons.mic_off : Icons.mic, color: _isListening ? Colors.red : _fondoBotones), 
                    onPressed: _escucharBusqueda
                  ),
                  Expanded(
                    child: TextField(
                      style: TextStyle(color: _textoPrincipal),
                      decoration: InputDecoration(
                        border: InputBorder.none, 
                        hintText: '¿A dónde vamos?',
                        hintStyle: TextStyle(color: _textoPrincipal.withOpacity(0.5))
                      )
                    )
                  ),
                ],
              ),
            ),
          ),

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
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportePage(categoria: 'general'))),
                    icon: Icon(Icons.warning_amber_rounded, color: _textoBotones),
                    label: const Text('REPORTAR OBSTÁCULO', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[900], minimumSize: const Size(double.infinity, 50)),
                  ),
                  const SizedBox(height: 15),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.8,
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

  Widget _buildBotonCategoria(IconData icono, String texto, Widget paginaDestino) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _fondoBotones,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => paginaDestino)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 20, color: _textoBotones),
          const SizedBox(width: 5),
          Text(texto, style: TextStyle(fontSize: 13, color: _textoBotones, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}