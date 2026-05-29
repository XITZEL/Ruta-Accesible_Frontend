import 'package:flutter/material.dart';
import 'lista_lugares_page.dart'; // Usaremos una clase base para no repetir código

class GobiernoPage extends StatelessWidget {
  const GobiernoPage({super.key});
  @override
  Widget build(BuildContext context) => ListaLugaresPage(titulo: "Gobierno", categoria: "gobierno");
}