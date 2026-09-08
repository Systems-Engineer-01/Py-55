import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:py55/shared/models/user_model.dart';

/// Servicio de autenticación con Firebase Auth (teléfono) y Firestore.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _usuariosCollection = 'usuarios';

  /// Usuario Firebase actual (null si no hay sesión).
  User? get currentUser => _auth.currentUser;

  /// Stream que emite cambios en el estado de autenticación.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Verificación de teléfono ────────────────────────────────────

  /// Envía un código OTP al [phoneNumber] proporcionado.
  ///
  /// [resendToken] se usa para reenviar el SMS sin iniciar un flujo nuevo.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential credential)
        onVerificationCompleted,
    required void Function(FirebaseAuthException error) onVerificationFailed,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String verificationId) onCodeAutoRetrievalTimeout,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
    );
  }

  /// Inicia sesión usando el [verificationId] y el [otp] ingresado.
  Future<UserCredential> signInWithOtp({
    required String verificationId,
    required String otp,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    return await _auth.signInWithCredential(credential);
  }

  // ── Firestore ───────────────────────────────────────────────────

  /// Obtiene el [UserModel] desde Firestore. Devuelve null si no existe.
  Future<UserModel?> getUserFromFirestore(String uid) async {
    final doc =
        await _firestore.collection(_usuariosCollection).doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  /// Guarda un [UserModel] en la colección "usuarios" de Firestore.
  Future<void> saveUserToFirestore(UserModel user) async {
    await _firestore
        .collection(_usuariosCollection)
        .doc(user.id)
        .set(user.toMap());
  }

  // ── Sesión ──────────────────────────────────────────────────────

  /// Cierra la sesión actual.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Errores legibles ────────────────────────────────────────────

  /// Traduce códigos de error de Firebase Auth a mensajes en español.
  static String friendlyError(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'El código ingresado es inválido. Intenta de nuevo.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera unos minutos antes de reintentar.';
      case 'session-expired':
        return 'El código ha expirado. Solicita uno nuevo.';
      case 'invalid-phone-number':
        return 'El número de teléfono no es válido.';
      case 'quota-exceeded':
        return 'Cuota de SMS excedida. Intenta más tarde.';
      case 'network-request-failed':
        return 'Error de red. Verifica tu conexión a internet.';
      default:
        return 'Ocurrió un error ($code). Intenta de nuevo.';
    }
  }
}
