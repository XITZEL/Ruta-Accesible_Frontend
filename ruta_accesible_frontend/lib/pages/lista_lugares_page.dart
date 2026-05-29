import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_page.dart';

class ListaLugaresPage extends StatefulWidget {
  final String titulo;
  final String categoria;
  final String? query;
  const ListaLugaresPage({super.key, required this.titulo, required this.categoria, this.query});

  @override
  State<ListaLugaresPage> createState() => _ListaLugaresPageState();
}

class _ListaLugaresPageState extends State<ListaLugaresPage> {
  List<dynamic> _lugares = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();

      final Uri url;
      if (widget.query != null && widget.query!.isNotEmpty) {
        url = Uri.parse(
            'https://ruta-accesible.vercel.app/api/search?q=${Uri.encodeComponent(widget.query!)}&lat=${pos.latitude}&lng=${pos.longitude}');
      } else {
        url = Uri.parse(
            'https://ruta-accesible.vercel.app/api/places?lat=${pos.latitude}&lng=${pos.longitude}&category=${widget.categoria}');
      }

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _lugares = data['data'] ?? [];
            _cargando = false;
          });
        }
      } else {
        if (mounted) setState(() => _cargando = false);
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: Text(widget.titulo)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _lugares.isEmpty
              ? const Center(child: Text('No se encontraron lugares cercanos'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lugares.length,
                  itemBuilder: (context, index) {
                    final item = _lugares[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: ListTile(
                        title: Text(item['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(item['address'] ?? 'Sin dirección'),
                        trailing: const Icon(Icons.directions,
                            color: Color(0xFF143278)),
                        onTap: () => Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => MapPage(
                              destino: LatLng(
                                (item['lat'] as num).toDouble(),
                                (item['lng'] as num).toDouble(),
                              ),
                              destinoNombre: item['name'],
                            ),
                          ),
                          (route) => route.isFirst,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
