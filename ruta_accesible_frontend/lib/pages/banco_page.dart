import 'package:flutter/material.dart';
import 'lista_lugares_page.dart';

class BancoPage extends StatelessWidget {
  const BancoPage({super.key});
  @override
  Widget build(BuildContext context) => ListaLugaresPage(titulo: "Bancos", categoria: "banco");
}