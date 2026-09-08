import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

// firebase_options.dart fue generado automáticamente por:
//   flutterfire configure
// Si necesitas regenerarlo (ej. tras agregar un servicio nuevo), ejecuta
// de nuevo el comando anterior en la raíz del proyecto.
import 'package:py55/firebase_options.dart';

/// Inicializa Firebase con las opciones de la plataforma actual.
///
/// Debe llamarse antes de [runApp] en main.dart.
Future<void> initializeFirebase() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
