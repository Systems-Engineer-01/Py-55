import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/features/map/models/driver_location_model.dart';

/// Servicio encubierto para la transmisión de ubicaciones activas en Firebase Realtime Database
/// y la consulta de perfiles de conductor desde Firestore.
class MapService {
  final FirebaseDatabase _db;
  final FirebaseFirestore _firestore;

  MapService({
    FirebaseDatabase? db,
    FirebaseFirestore? firestore,
  })  : _db = db ?? FirebaseDatabase.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Ruta en Realtime Database donde se guardan las ubicaciones activas.
  static const String _activeLocationsPath = 'ubicaciones_activas';

  /// Actualiza la ubicación GPS del mototaxista en Firebase Realtime Database.
  /// Configura `onDisconnect().remove()` para eliminar la ubicación si la conexión se cae.
  Future<void> updateDriverLocation({
    required String driverId,
    required double latitude,
    required double longitude,
    double heading = 0.0,
  }) async {
    final ref = _db.ref('$_activeLocationsPath/$driverId');

    // Garantizar que se elimine la ubicación si el dispositivo pierde conexión o se cierra bruscamente.
    await ref.onDisconnect().remove();

    await ref.set({
      'driverId': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'timestamp': ServerValue.timestamp,
      'isAvailable': true,
    });
  }

  /// Desactiva al mototaxista y borra su registro de `ubicaciones_activas`.
  Future<void> setDriverUnavailable(String driverId) async {
    final ref = _db.ref('$_activeLocationsPath/$driverId');
    await ref.onDisconnect().cancel();
    await ref.remove();
  }

  /// Escucha en tiempo real todas las ubicaciones activas de mototaxistas.
  Stream<List<DriverLocationModel>> getActiveDriversStream() {
    final ref = _db.ref(_activeLocationsPath);

    return ref.onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return [];

      final List<DriverLocationModel> activeDrivers = [];

      if (data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            try {
              final driverLoc =
                  DriverLocationModel.fromMap(key.toString(), value);
              if (driverLoc.isAvailable) {
                activeDrivers.add(driverLoc);
              }
            } catch (_) {
              // Ignorar nodos malformados
            }
          }
        });
      }

      return activeDrivers;
    });
  }

  /// Obtiene los detalles combinados del conductor (UserModel + DriverProfileModel) desde Firestore
  /// para mostrarlos en el Bottom Sheet al seleccionar una mototaxi.
  Future<Map<String, dynamic>?> getDriverDetails(String driverId) async {
    try {
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(driverId)
          .get();

      final driverDoc = await _firestore
          .collection(AppConstants.driversCollection)
          .doc(driverId)
          .get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data() ?? {};
      final driverData = driverDoc.exists ? (driverDoc.data() ?? {}) : {};

      return {
        'driverId': driverId,
        'nombre': userData['nombre'] ?? 'Conductor Py55',
        'telefono': userData['telefono'] ?? '',
        'fotoPerfilUrl': userData['fotoPerfilUrl'],
        'calificacion': (driverData['calificacion'] as num?)?.toDouble() ?? 5.0,
        'placa': driverData['placa'] ?? 'Sin placa',
        'marcaVehiculo': driverData['marcaVehiculo'] ?? 'Torito Bajaj',
        'modeloVehiculo': driverData['modeloVehiculo'] ?? '',
        'verificado': driverData['estadoVerificacion'] == AppConstants.verificacionAprobado ||
            driverData['estadoVerificacion'] == 'pendiente', // Muestra estado real
        'estadoVerificacion': driverData['estadoVerificacion'] ?? AppConstants.verificacionPendiente,
      };
    } catch (e) {
      return null;
    }
  }
}
