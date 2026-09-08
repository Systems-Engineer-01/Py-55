import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:py55/features/auth/auth_service.dart';
import 'package:py55/shared/models/user_model.dart';

/// Estado de alto nivel de la sesión del usuario.
enum AuthStatus {
  /// Aún no se sabe si hay sesión (cargando).
  uninitialized,

  /// No hay sesión activa → mostrar login.
  unauthenticated,

  /// Hay sesión pero el usuario no eligió rol → mostrar selector de rol.
  needsRole,

  /// Sesión activa y perfil completo → mostrar home.
  authenticated,
}

/// Provider que gestiona el estado de autenticación de la aplicación.
///
/// Escucha [FirebaseAuth.authStateChanges] y busca el perfil del usuario
/// en Firestore para determinar qué pantalla mostrar.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.uninitialized;
  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = true;

  StreamSubscription<User?>? _authSubscription;

  // ── Getters ─────────────────────────────────────────────────────

  AuthStatus get status => _status;
  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ── Constructor ─────────────────────────────────────────────────

  AuthProvider() {
    _init();
  }

  void _init() {
    _authSubscription =
        _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  // ── Listener de auth ────────────────────────────────────────────

  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;

    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _userModel = null;
    } else {
      // Busca perfil en Firestore
      try {
        _userModel = await _authService.getUserFromFirestore(user.uid);
      } catch (_) {
        _userModel = null;
      }

      _status =
          _userModel == null ? AuthStatus.needsRole : AuthStatus.authenticated;
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Acciones ────────────────────────────────────────────────────

  /// Guarda un nuevo usuario con el [rol] seleccionado en Firestore.
  Future<void> saveUserWithRole(String rol) async {
    if (_firebaseUser == null) return;

    _isLoading = true;
    notifyListeners();

    final user = UserModel(
      id: _firebaseUser!.uid,
      telefono: _firebaseUser!.phoneNumber ?? '',
      rol: rol,
      nombre: '', // Se completa en el perfil más adelante
      fechaRegistro: DateTime.now(),
    );

    await _authService.saveUserToFirestore(user);
    _userModel = user;
    _status = AuthStatus.authenticated;
    _isLoading = false;
    notifyListeners();
  }

  /// Cierra la sesión y limpia el estado.
  Future<void> signOut() async {
    await _authService.signOut();
    // El listener _onAuthStateChanged se encargará del resto.
  }

  // ── Dispose ─────────────────────────────────────────────────────

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
