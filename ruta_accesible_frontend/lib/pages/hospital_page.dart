import 'package:flutter/material.dart';
import 'lista_lugares_page.dart'; 

class HospitalPage extends StatelessWidget {
  const HospitalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListaLugaresPage(titulo: "Hospitales", categoria: "hospital");
  }
}