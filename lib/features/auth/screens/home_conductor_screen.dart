import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:py55/features/auth/auth_provider.dart';

/// Pantalla provisional para el conductor autenticado.
class HomeConductorScreen extends StatelessWidget {
  const HomeConductorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Conductor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.two_wheeler_rounded, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '¡Bienvenido, conductor!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              'Aquí se mostrará el mapa y las solicitudes entrantes.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
