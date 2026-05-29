import 'package:flutter/material.dart';
import 'package:flutter/services.dart';          // ← MethodChannel nativo
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:io';

// ─── PALETA OFICIAL ───────────────────────────────────────────
const _fondo      = Color(0xFFF5F7FA); // Fondo general
const _textoPrin  = Color(0xFF0A192F); // Texto principal
const _boton      = Color(0xFF143278); // Botones
const _textoBtn   = Color(0xFFFFFFFF); // Texto botones
const _verde      = Color(0xFF1B8A4C); // Solo botón Enviar
// ──────────────────────────────────────────────────────────────

// ─── CANAL TTS NATIVO ANDROID ────────────────────────────────
const _ttsChannel = MethodChannel('com.rutaaccesible/tts');

Future<void> _hablar(String texto) async {
  try {
    await _ttsChannel.invokeMethod('hablar', {'texto': texto});
  } catch (e) {
    debugPrint('TTS error: $e');
  }
}

Future<void> _detenerVoz() async {
  try {
    await _ttsChannel.invokeMethod('detener');
  } catch (e) {
    debugPrint('TTS detener error: $e');
  }
}
// ──────────────────────────────────────────────────────────────

class ReportePage extends StatefulWidget {
  final String categoria;
  const ReportePage({super.key, required this.categoria});
  @override
  State<ReportePage> createState() => _ReportePageState();
}

class _ReportePageState extends State<ReportePage> {
  final TextEditingController _desc = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _tipo, _aiDesc, _aiPeligro;
  File? _fotoFile;
  bool _enviando = false, _analizando = false;
  double? _lat, _lng;

  final List<Map<String, String>> _tipos = [
    {'valor': 'bache',           'etiqueta': 'Bache',           'icono': '🕳️'},
    {'valor': 'rampa_bloqueada', 'etiqueta': 'Rampa Bloqueada', 'icono': '🚧'},
    {'valor': 'banqueta',        'etiqueta': 'Banqueta Dañada', 'icono': '🧱'},
    {'valor': 'semaforo',        'etiqueta': 'Semáforo',        'icono': '🚦'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.categoria != 'general') _tipo = widget.categoria;
    _obtenerLoc();
    // Saludo al entrar a la pantalla
    Future.delayed(const Duration(milliseconds: 600), () {
      _hablar('Pantalla de nuevo reporte. '
          'Primero agregue una foto, luego seleccione el tipo de problema '
          'y escriba una descripción.');
    });
  }

  @override
  void dispose() {
    _detenerVoz();
    _desc.dispose();
    super.dispose();
  }

  // ─── UBICACIÓN ──────────────────────────────────────────────
  Future<void> _obtenerLoc() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final p = await Geolocator.getCurrentPosition();
      setState(() { _lat = p.latitude; _lng = p.longitude; });
    } catch (e) {
      debugPrint('Error ubicación: $e');
    }
  }

  // ─── FOTO ────────────────────────────────────────────────────
  Future<void> _seleccionarFoto(ImageSource fuente) async {
    final XFile? f = await _picker.pickImage(
      source: fuente, imageQuality: 85, maxWidth: 1200,
    );
    if (f == null) return;

    setState(() { _fotoFile = File(f.path); _analizando = true; });
    await _hablar('Analizando la foto, por favor espere.');

    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('https://ruta-accesible.vercel.app/api/ai/describe-photo'),
      );
      req.files.add(await http.MultipartFile.fromPath(
        'photo', f.path, contentType: MediaType('image', 'jpeg'),
      ));
      final res = await req.send();

      if (res.statusCode == 200) {
        final d = json.decode(await res.stream.bytesToString())['data'];
        setState(() {
          _tipo      = d['tipo_barrera'];
          _aiDesc    = d['descripcion'];
          _aiPeligro = d['nivel_peligro'];
          _desc.text = _aiDesc ?? '';
        });
        await _hablar(
          'Foto analizada. Se detectó: ${_aiDesc ?? "una barrera"}. '
          'Revise la descripción y presione Enviar cuando esté listo.',
        );
      }
    } catch (_) {
      await _hablar(
        'No se pudo analizar la foto automáticamente. '
        'Por favor describa el problema con sus palabras.',
      );
    }
    setState(() => _analizando = false);
  }

  void _mostrarOpcionesFoto() {
    _hablar('Elija cómo agregar la foto: cámara o galería.');
    showModalBottomSheet(
      context: context,
      backgroundColor: _fondo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tirador
              Center(
                child: Container(
                  width: 44, height: 5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _textoPrin.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Text(
                '¿Cómo desea agregar la foto?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: _textoPrin,
                ),
              ),
              const SizedBox(height: 24),

              // Botón cámara
              _BotonSheet(
                icono: Icons.camera_alt_rounded,
                etiqueta: 'Tomar foto ahora',
                sub: 'Abrir la cámara',
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarFoto(ImageSource.camera);
                },
              ),
              const SizedBox(height: 14),

              // Botón galería
              _BotonSheet(
                icono: Icons.photo_library_rounded,
                etiqueta: 'Elegir de la galería',
                sub: 'Buscar en mis fotos',
                onTap: () {
                  Navigator.pop(context);
                  _seleccionarFoto(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 14),

              TextButton(
                onPressed: () {
                  _hablar('Cancelado.');
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontSize: 20, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── ENVIAR ──────────────────────────────────────────────────
  Future<void> _enviar() async {
    if (_tipo == null) {
      await _hablar('Por favor seleccione el tipo de problema.');
      _snack('Seleccione el tipo de problema.');
      return;
    }
    if (_desc.text.trim().isEmpty) {
      await _hablar('Por favor escriba una descripción del problema.');
      _snack('Escriba una descripción.');
      return;
    }

    setState(() => _enviando = true);
    await _hablar('Enviando su reporte, por favor espere.');

    try {
      final res = await http.post(
        Uri.parse('https://ruta-accesible.vercel.app/api/reports'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': 'user_${DateTime.now().millisecondsSinceEpoch}',
          'lat': _lat,
          'lng': _lng,
          'tipo_barrera': _tipo,
          'descripcion': _desc.text.trim(),
          if (_aiPeligro != null) 'nivel_peligro': _aiPeligro,
        }),
      );

      if (res.statusCode == 201 && mounted) {
        await _hablar('¡Reporte enviado con éxito! Muchas gracias por ayudar a mejorar la ciudad.');
        Navigator.pop(context);
      } else {
        await _hablar('Hubo un error al enviar. Por favor intente de nuevo.');
        _snack('Error al enviar. Intente de nuevo.');
      }
    } catch (_) {
      await _hablar('No hay conexión a internet. Por favor intente más tarde.');
      _snack('Sin conexión. Intente más tarde.');
    }

    if (mounted) setState(() => _enviando = false);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 18)),
      backgroundColor: Colors.red[700],
      duration: const Duration(seconds: 3),
    ),
  );

  // ─────────────────────────────── BUILD ───────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _boton,
        foregroundColor: _textoBtn,
        elevation: 0,
        title: const Text(
          'NUEVO REPORTE',
          style: TextStyle(
            color: _textoBtn, fontSize: 22,
            fontWeight: FontWeight.bold, letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, size: 32, color: _textoBtn),
            tooltip: 'Escuchar instrucciones',
            onPressed: () => _hablar(
              'Instrucciones: Paso uno, agregue una foto del problema. '
              'Paso dos, seleccione el tipo de problema. '
              'Paso tres, escriba o revise la descripción. '
              'Paso cuatro, presione el botón verde Enviar Reporte.',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        children: [

          // ── PASO 1: FOTO ─────────────────────────────────────
          _Seccion(
            numero: '1', titulo: 'Foto del problema',
            child: GestureDetector(
              onTap: _mostrarOpcionesFoto,
              child: Container(
                height: 210,
                decoration: BoxDecoration(
                  color: _textoBtn,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _boton.withOpacity(0.35), width: 2),
                  boxShadow: [BoxShadow(
                    color: _textoPrin.withOpacity(0.07),
                    blurRadius: 8, offset: const Offset(0, 3),
                  )],
                ),
                child: _analizando
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircularProgressIndicator(color: _boton, strokeWidth: 3),
                          SizedBox(height: 16),
                          Text('Analizando foto…',
                              style: TextStyle(fontSize: 18, color: _boton)),
                        ],
                      )
                    : _fotoFile != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(_fotoFile!, fit: BoxFit.cover),
                              ),
                              Positioned(
                                bottom: 10, right: 10,
                                child: ElevatedButton.icon(
                                  onPressed: _mostrarOpcionesFoto,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _boton,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(Icons.refresh, color: _textoBtn, size: 22),
                                  label: const Text('Cambiar foto',
                                      style: TextStyle(fontSize: 16, color: _textoBtn)),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo_rounded, size: 70, color: _boton),
                              SizedBox(height: 14),
                              Text('Toque aquí para agregar foto',
                                  style: TextStyle(
                                    fontSize: 20, color: _boton,
                                    fontWeight: FontWeight.bold,
                                  )),
                              SizedBox(height: 6),
                              Text('Puede usar la cámara o su galería',
                                  style: TextStyle(fontSize: 16, color: Colors.grey)),
                            ],
                          ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── PASO 2: TIPO ─────────────────────────────────────
          _Seccion(
            numero: '2', titulo: 'Tipo de problema',
            child: Column(
              children: _tipos.map((t) {
                final sel = _tipo == t['valor'];
                return GestureDetector(
                  onTap: () {
                    setState(() => _tipo = t['valor']);
                    _hablar('Seleccionado: ${t['etiqueta']}.');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: sel ? _boton : _textoBtn,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel ? _boton : Colors.grey.shade300,
                        width: sel ? 2 : 1,
                      ),
                      boxShadow: sel
                          ? [BoxShadow(color: _boton.withOpacity(0.3),
                              blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Text(t['icono']!, style: const TextStyle(fontSize: 30)),
                        const SizedBox(width: 16),
                        Text(
                          t['etiqueta']!,
                          style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600,
                            color: sel ? _textoBtn : _textoPrin,
                          ),
                        ),
                        const Spacer(),
                        if (sel)
                          const Icon(Icons.check_circle, color: _textoBtn, size: 28),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 28),

          // ── PASO 3: DESCRIPCIÓN ──────────────────────────────
          _Seccion(
            numero: '3', titulo: 'Descripción del problema',
            child: Container(
              decoration: BoxDecoration(
                color: _textoBtn,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [BoxShadow(
                  color: _textoPrin.withOpacity(0.05),
                  blurRadius: 6, offset: const Offset(0, 2),
                )],
              ),
              child: TextField(
                controller: _desc,
                maxLines: 4,
                style: const TextStyle(fontSize: 20, color: _textoPrin, height: 1.5),
                decoration: const InputDecoration(
                  hintText: 'Describa el problema con sus palabras…',
                  hintStyle: TextStyle(fontSize: 18, color: Colors.grey),
                  contentPadding: EdgeInsets.all(18),
                  border: InputBorder.none,
                ),
                onTap: () => _hablar('Campo de descripción. Escriba el problema con sus palabras.'),
              ),
            ),
          ),

          // Nivel de peligro IA
          if (_aiPeligro != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nivel de peligro detectado: $_aiPeligro',
                      style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600, color: _textoPrin,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 36),

          // ── BOTÓN ENVIAR ─────────────────────────────────────
          SizedBox(
            height: 72,
            child: ElevatedButton.icon(
              onPressed: _enviando ? null : _enviar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                disabledBackgroundColor: Colors.grey.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
              icon: _enviando
                  ? const SizedBox(
                      width: 28, height: 28,
                      child: CircularProgressIndicator(color: _textoBtn, strokeWidth: 3),
                    )
                  : const Icon(Icons.send_rounded, color: _textoBtn, size: 32),
              label: Text(
                _enviando ? 'Enviando…' : 'ENVIAR REPORTE',
                style: const TextStyle(
                  fontSize: 23, fontWeight: FontWeight.bold,
                  color: _textoBtn, letterSpacing: 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

// ─── WIDGETS AUXILIARES ───────────────────────────────────────

class _Seccion extends StatelessWidget {
  final String numero, titulo;
  final Widget child;
  const _Seccion({required this.numero, required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: _boton,
              child: Text(numero,
                  style: const TextStyle(
                    color: _textoBtn, fontWeight: FontWeight.bold, fontSize: 17,
                  )),
            ),
            const SizedBox(width: 10),
            Text(titulo,
                style: const TextStyle(
                  fontSize: 21, fontWeight: FontWeight.bold, color: _textoPrin,
                )),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _BotonSheet extends StatelessWidget {
  final IconData icono;
  final String etiqueta, sub;
  final VoidCallback onTap;
  const _BotonSheet({
    required this.icono, required this.etiqueta,
    required this.sub, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: _boton.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _boton.withOpacity(0.35), width: 2),
        ),
        child: Row(
          children: [
            Icon(icono, color: _boton, size: 40),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta,
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: _textoPrin,
                    )),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: _boton, size: 30),
          ],
        ),
      ),
    );
  }
}