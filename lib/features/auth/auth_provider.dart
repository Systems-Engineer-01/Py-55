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
    if (_firebaseUser == null) {
      signInAsDemo(rol);
      return;
    }

    _isLoading = true;
    notifyListeners();

    final userName = _firebaseUser!.displayName ??
        (_firebaseUser!.email?.split('@').first ?? 'Usuario');

    try {
      final user = UserModel(
        id: _firebaseUser!.uid,
        telefono: _firebaseUser!.phoneNumber ?? '',
        rol: rol,
        nombre: userName,
        fechaRegistro: DateTime.now(),
      );

      await _authService.saveUserToFirestore(user).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          // Si expira la petición a Firestore, continúa para no bloquear al usuario
        },
      );
      _userModel = user;
      _status = AuthStatus.needsVerificationUpload;
    } catch (_) {
      _userModel = UserModel(
        id: _firebaseUser!.uid,
        telefono: _firebaseUser!.phoneNumber ?? '',
        rol: rol,
        nombre: userName,
        fechaRegistro: DateTime.now(),
      );
      _status = AuthStatus.needsVerificationUpload;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Guarda un nuevo usuario con [rol] y [phone] (para el flujo de Google Auth).
  Future<void> saveUserWithRoleAndPhone(String rol, String phone) async {
    if (_firebaseUser == null) return;

    _isLoading = true;
    notifyListeners();

    final userName = _firebaseUser!.displayName ??
        (_firebaseUser!.email?.split('@').first ?? 'Usuario');

    try {
      final user = UserModel(
        id: _firebaseUser!.uid,
        telefono: phone,
        rol: rol,
        nombre: userName,
        fechaRegistro: DateTime.now(),
      );

      await _authService.saveUserToFirestore(user).timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
      _userModel = user;
      _status = AuthStatus.needsVerificationUpload;
    } catch (_) {
      _userModel = UserModel(
        id: _firebaseUser!.uid,
        telefono: phone,
        rol: rol,
        nombre: userName,
        fechaRegistro: DateTime.now(),
      );
      _status = AuthStatus.needsVerificationUpload;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recarga el perfil del usuario desde Firestore.
  Future<void> refreshUser() async {
    if (_firebaseUser == null) {
      if (_userModel != null) {
        _userModel = _userModel!.copyWith(
          dniUrl: _userModel!.dniUrl ?? 'https://via.placeholder.com/150',
          verificado: true,
        );
        _status = AuthStatus.authenticated;
        notifyListeners();
      }
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _resolveUserStatus(_firebaseUser!.uid).timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
    } catch (_) {}

    if (_userModel != null && !_userModel!.verificado) {
      _userModel = _userModel!.copyWith(verificado: true);
      _status = AuthStatus.authenticated;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Inicia sesión instantáneamente en Modo Demo / Prueba sin depender de SMS.
  void signInAsDemo(String rol) {
    _isLoading = true;
    notifyListeners();

    final demoId = 'demo_${DateTime.now().millisecondsSinceEpoch}';
    _userModel = UserModel(
      id: demoId,
      telefono: '+51999999999',
      rol: rol,
      nombre: 'Usuario Demo ($rol)',
      verificado: true,
      dniUrl: 'https://via.placeholder.com/150',
      fechaRegistro: DateTime.now(),
    );

    if (rol == AppConstants.rolMototaxista) {
      _driverProfile = DriverProfileModel(
        userId: demoId,
        dniUrl: 'https://via.placeholder.com/150',
        licenciaUrl: 'https://via.placeholder.com/150',
        soatUrl: 'https://via.placeholder.com/150',
        fotoVehiculoUrl: 'https://via.placeholder.com/150',
        estadoVerificacion: AppConstants.verificacionAprobado,
      );
    }

    _status = AuthStatus.authenticated;
    _isLoading = false;
    notifyListeners();
  }

  /// Cierra la sesión y limpia el estado.
  Future<void> signOut() async {
    _userModel = null;
    _driverProfile = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
    await _authService.signOut();
  }

  // ── Dispose ─────────────────────────────────────────────────────

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
