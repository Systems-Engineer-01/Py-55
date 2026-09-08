import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/features/auth/auth_service.dart';
import 'package:py55/features/verification/verification_service.dart';
import 'package:py55/shared/models/driver_profile_model.dart';
import 'package:py55/shared/models/user_model.dart';

/// Estado de alto nivel de la sesión del usuario.
enum AuthStatus {
  /// Aún no se sabe si hay sesión (cargando).
  uninitialized,

  /// No hay sesión activa → mostrar login.
  unauthenticated,

  /// Hay sesión pero el usuario no eligió rol → mostrar selector de rol.
  needsRole,

  /// Sesión activa, rol elegido, pero falta subir documentos.
  needsVerificationUpload,

  /// Documentos subidos, pendiente de aprobación.
  verificationPending,

  /// Sesión activa y verificación aprobada → mostrar home.
  authenticated,
}

/// Provider que gestiona el estado de autenticación y verificación.
///
/// Escucha [FirebaseAuth.authStateChanges] y busca el perfil del usuario
/// en Firestore para determinar qué pantalla mostrar.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final VerificationService _verificationService = VerificationService();

  AuthStatus _status = AuthStatus.uninitialized;
  User? _firebaseUser;
  UserModel? _userModel;
  DriverProfileModel? _driverProfile;
  bool _isLoading = true;

  StreamSubscription<User?>? _authSubscription;

  // ── Getters ─────────────────────────────────────────────────────

  AuthStatus get status => _status;
  User? get firebaseUser => _firebaseUser;
  UserModel? get userModel => _userModel;
  DriverProfileModel? get driverProfile => _driverProfile;
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
      _driverProfile = null;
    } else {
      await _resolveUserStatus(user.uid);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Determina el estado correcto del usuario basándose en Firestore.
  Future<void> _resolveUserStatus(String uid) async {
    // 1. Buscar perfil de usuario
    try {
      _userModel = await _authService.getUserFromFirestore(uid);
    } catch (_) {
      _userModel = null;
    }

    if (_userModel == null) {
      _status = AuthStatus.needsRole;
      return;
    }

    // 2. Si es conductor, revisar perfil de conductor
    if (_userModel!.rol == AppConstants.rolMototaxista) {
      try {
        _driverProfile =
            await _verificationService.getDriverProfile(uid);
      } catch (_) {
        _driverProfile = null;
      }

      if (_driverProfile == null || !_driverHasAllDocs(_driverProfile!)) {
        _status = AuthStatus.needsVerificationUpload;
      } else if (_driverProfile!.estadoVerificacion ==
          AppConstants.verificacionPendiente) {
        _status = AuthStatus.verificationPending;
      } else if (_driverProfile!.estadoVerificacion ==
          AppConstants.verificacionAprobado) {
        _status = AuthStatus.authenticated;
      } else {
        // rechazado → volver a subir
        _status = AuthStatus.needsVerificationUpload;
      }
      return;
    }

    // 3. Si es pasajero, revisar si subió DNI
    if (_userModel!.dniUrl == null || _userModel!.dniUrl!.isEmpty) {
      _status = AuthStatus.needsVerificationUpload;
    } else if (!_userModel!.verificado) {
      _status = AuthStatus.verificationPending;
    } else {
      _status = AuthStatus.authenticated;
    }
  }

  /// Comprueba si el conductor ha subido los 4 documentos requeridos.
  bool _driverHasAllDocs(DriverProfileModel profile) {
    return profile.dniUrl != null &&
        profile.dniUrl!.isNotEmpty &&
        profile.licenciaUrl != null &&
        profile.licenciaUrl!.isNotEmpty &&
        profile.soatUrl != null &&
        profile.soatUrl!.isNotEmpty &&
        profile.fotoVehiculoUrl != null &&
        profile.fotoVehiculoUrl!.isNotEmpty;
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

    // Tras elegir rol, el usuario necesita subir documentos
    _status = AuthStatus.needsVerificationUpload;
    _isLoading = false;
    notifyListeners();
  }

  /// Recarga el perfil del usuario desde Firestore.
  ///
  /// Útil después de subir documentos o para verificar si el admin
  /// ya aprobó la cuenta.
  Future<void> refreshUser() async {
    if (_firebaseUser == null) return;

    _isLoading = true;
    notifyListeners();

    await _resolveUserStatus(_firebaseUser!.uid);

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
