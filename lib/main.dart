import 'package:flutter/material.dart';
import 'package:py55/core/firebase_init.dart';
import 'package:py55/core/theme.dart';

void main() async {
  await initializeFirebase();
  runApp(const Py55App());
}

class Py55App extends StatelessWidget {
  const Py55App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Py55',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}

/// Pantalla inicial temporal – se reemplazará por el flujo de auth.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Py55 - vehículo en tiempo real',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
