import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 1. Importa esto
import 'login_page.dart';

// 2. Cambia a 'Future<void> main()' para poder usar 'async'
Future<void> main() async {
  // 3. Necesario para inicializar Flutter antes de cargar el archivo .env
  WidgetsFlutterBinding.ensureInitialized();
  
  // 4. Carga el archivo .env (debe estar en la raíz de tu proyecto)
  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ruta Accesible',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const LoginPage(), 
    );
  }
}