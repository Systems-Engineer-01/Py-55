/// Constantes globales de la aplicación Py55.
class AppConstants {
  AppConstants._(); // No instanciable

  // ── Nombre de app ──────────────────────────────────────────────
  static const String appName = 'Py55';

  // ── Google Maps ────────────────────────────────────────────────
  static const String googleMapsApiKey =
      'AIzaSyDejdVwB9d9J6JwyVLjDJE0RZUf0nvT83o';

  // ── Roles ──────────────────────────────────────────────────────
  static const String rolPasajero = 'pasajero';
  static const String rolMototaxista = 'mototaxista';

  // ── Estados de verificación ────────────────────────────────────
  static const String verificacionPendiente = 'pendiente';
  static const String verificacionAprobado = 'aprobado';
  static const String verificacionRechazado = 'rechazado';

  // ── Estados de viaje ───────────────────────────────────────────
  static const String rideBuscando = 'buscando';
  static const String rideAceptado = 'aceptado';
  static const String rideEnCurso = 'en_curso';
  static const String rideFinalizado = 'finalizado';
  static const String rideCancelado = 'cancelado';

  // ── Firestore collections ──────────────────────────────────────
  static const String usersCollection = 'usuarios';
  static const String driversCollection = 'conductores';
  static const String ridesCollection = 'viajes';
}
