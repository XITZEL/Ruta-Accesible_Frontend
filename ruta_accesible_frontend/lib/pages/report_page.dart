import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:io';

const _c = Color(0xFF143278);
const _v = Color(0xFF1B8A4C);

class ReportePage extends StatefulWidget {
  final String categoria;
  const ReportePage({super.key, required this.categoria});
  @override
  State<ReportePage> createState() => _ReportePageState();
}

class _ReportePageState extends State<ReportePage> {
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _desc = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _tipo, _fotoUrl, _aiDesc, _aiPeligro;
  File? _fotoFile;
  bool _enviando = false, _analizando = false;
  double? _lat, _lng;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("es-MX");
    _obtenerLoc();
    if (widget.categoria != 'general') _tipo = widget.categoria;
  }

  Future<void> _obtenerLoc() async {
    Position p = await Geolocator.getCurrentPosition();
    setState(() { _lat = p.latitude; _lng = p.longitude; });
  }

  Future<void> _tomarFoto() async {
    final XFile? f = await _picker.pickImage(source: ImageSource.camera);
    if (f == null) return;
    setState(() { _fotoFile = File(f.path); _analizando = true; });
    
    var req = http.MultipartRequest('POST', Uri.parse('https://ruta-accesible.vercel.app/api/ai/describe-photo'));
    req.files.add(await http.MultipartFile.fromPath('photo', f.path, contentType: MediaType('image', 'jpeg')));
    var res = await req.send();
    if (res.statusCode == 200) {
      var d = json.decode(await res.stream.bytesToString())['data'];
      setState(() { _tipo = d['tipo_barrera']; _aiDesc = d['descripcion']; _aiPeligro = d['nivel_peligro']; _desc.text = _aiDesc ?? ''; });
    }
    setState(() => _analizando = false);
  }

  Future<void> _enviar() async {
    if (_tipo == null || _desc.text.isEmpty) return;
    setState(() => _enviando = true);
    
    var body = {'userId': 'user_${DateTime.now().millisecondsSinceEpoch}', 'lat': _lat, 'lng': _lng, 'tipo_barrera': _tipo, 'descripcion': _desc.text};
    var res = await http.post(Uri.parse('https://ruta-accesible.vercel.app/api/reports'), 
        headers: {'Content-Type': 'application/json'}, body: json.encode(body));
    
    if (res.statusCode == 201 && mounted) Navigator.pop(context);
    setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NUEVO REPORTE')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        GestureDetector(onTap: _tomarFoto, child: Container(height: 150, color: Colors.grey[200], 
            child: _analizando ? const Center(child: CircularProgressIndicator()) : const Icon(Icons.camera_alt, size: 50))),
        Wrap(spacing: 10, children: ['bache', 'rampa_bloqueada', 'banqueta', 'semaforo'].map((t) => ChoiceChip(
            label: Text(t), selected: _tipo == t, onSelected: (s) => setState(() => _tipo = t))).toList()),
        TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(hintText: 'Descripción')),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _enviando ? null : _enviar, style: ElevatedButton.styleFrom(backgroundColor: _v), 
            child: _enviando ? const CircularProgressIndicator() : const Text('ENVIAR'))
      ]),
    );
  }
}