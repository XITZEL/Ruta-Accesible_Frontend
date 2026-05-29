import 'package:flutter_test/flutter_test.dart';

// Asegúrate de que este import apunte correctamente a tu main.dart
import 'package:ruta_accesible_frontend/main.dart'; 

void main() {
  testWidgets('Counter visibility test', (WidgetTester tester) async {
    // CAMBIA AQUÍ: Cambia RutaAccesibleApp() por MyApp()
    await tester.pumpWidget(const MyApp()); 

    // El resto de tu código de prueba...
  });
}