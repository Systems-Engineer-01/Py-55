import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/core/firebase_init.dart';
import 'package:py55/core/theme.dart';
import 'package:py55/features/auth/auth_provider.dart';
import 'package:py55/features/auth/screens/home_conductor_screen.dart';
import 'package:py55/features/auth/screens/home_pasajero_screen.dart';
import 'package:py55/features/auth/screens/phone_input_screen.dart';
import 'package:py55/features/auth/screens/role_selection_screen.dart';
import 'package:py55/features/verification/screens/document_upload_screen.dart';
import 'package:py55/features/verification/screens/passenger_verification_screen.dart';
import 'package:py55/features/verification/screens/verification_status_screen.dart';

void main() async {
  await initializeFirebase();
  runApp(const Py55App());
}

class Py55App extends StatelessWidget {
  const Py55App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Py55',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Widget raíz que decide qué pantalla mostrar según el estado de
/// autenticación y verificación.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Pantalla de carga mientras se resuelve el estado de sesión.
    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (auth.status) {
      case AuthStatus.unauthenticated:
        return const PhoneInputScreen();

      case AuthStatus.needsRole:
        return const RoleSelectionScreen();

      case AuthStatus.needsVerificationUpload:
        // Según el rol, muestra la pantalla de subida correspondiente.
        if (auth.userModel?.rol == AppConstants.rolMototaxista) {
          return const DocumentUploadScreen();
        }
        return const PassengerVerificationScreen();

      case AuthStatus.verificationPending:
        return const VerificationStatusScreen();

      case AuthStatus.authenticated:
        final rol = auth.userModel?.rol;
        if (rol == AppConstants.rolPasajero) {
          return const HomePasajeroScreen();
        }
        return const HomeConductorScreen();

      case AuthStatus.uninitialized:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
    }
  }
}
