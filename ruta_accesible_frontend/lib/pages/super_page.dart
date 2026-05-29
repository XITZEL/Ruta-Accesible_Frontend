import 'package:flutter/material.dart';
import 'lista_lugares_page.dart';

class SuperPage extends StatelessWidget {
  const SuperPage({super.key});
  @override
  Widget build(BuildContext context) => ListaLugaresPage(titulo: "Supermercados", categoria: "super");
}