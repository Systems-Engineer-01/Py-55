import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/shared/models/ride_request_model.dart';

/// Servicio para la creación, aceptación con transacciones atómicas, cancelación y seguimiento en tiempo real de viajes.
class RideRequestService {
  final FirebaseFirestore _firestore;

  RideRequestService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Crea una nueva solicitud de viaje en Firestore bajo la colección "viajes".
  Future<String> createRideRequest(RideRequestModel ride) async {
    final docRef = _firestore.collection(AppConstants.ridesCollection).doc();
    final newRide = ride.copyWith(id: docRef.id);
    await docRef.set(newRide.toMap());
    return docRef.id;
  }

  /// Escucha en tiempo real los cambios del documento de un viaje por su ID.
  Stream<RideRequestModel?> streamRideRequest(String rideId) {
    return _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return RideRequestModel.fromMap(snapshot.data()!);
    });
  }

  /// Escucha todas las solicitudes en estado "buscando" para que los mototaxistas las vean en tiempo real.
  Stream<List<RideRequestModel>> streamPendingRides() {
    return _firestore
        .collection(AppConstants.ridesCollection)
        .where('estado', isEqualTo: AppConstants.rideBuscando)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RideRequestModel.fromMap(doc.data()))
          .toList();
    });
  }

  /// Transacción atómica en Firestore para aceptar un viaje.
  /// Previene condiciones de carrera si dos mototaxistas intentan aceptar el mismo viaje a la vez.
  /// Retorna `true` si fue aceptado con éxito o `false` si ya fue ganado por otro conductor.
  Future<bool> acceptRideTransaction({
    required String rideId,
    required String driverId,
    required double tarifaAcordada,
  }) async {
    final docRef = _firestore.collection(AppConstants.ridesCollection).doc(rideId);

    return await _firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) return false;

      final data = snapshot.data();
      if (data == null) return false;

      final currentEstado = data['estado'] as String?;
      final currentConductorId = data['conductorId'] as String?;

      // Verificar que la solicitud siga buscando y no tenga conductor asignado
      if (currentEstado != AppConstants.rideBuscando || currentConductorId != null) {
        return false;
      }

      // Actualizar el documento de manera atómica
      transaction.update(docRef, {
        'conductorId': driverId,
        'estado': AppConstants.rideAceptado,
        'tarifaAcordada': tarifaAcordada,
      });

      return true;
    });
  }

  /// Actualiza el estado del viaje (ej: "en_curso", "finalizado", "cancelado").
  Future<void> updateRideStatus(String rideId, String newStatus) async {
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .update({
      'estado': newStatus,
    });
  }

  /// Cancela la solicitud de viaje marcando su estado como "cancelado".
  Future<void> cancelRideRequest(String rideId) async {
    await updateRideStatus(rideId, AppConstants.rideCancelado);
  }

  /// Escucha en tiempo real si el mototaxista tiene un viaje activo ("aceptado" o "en_curso").
  Stream<RideRequestModel?> streamDriverActiveRide(String driverId) {
    return _firestore
        .collection(AppConstants.ridesCollection)
        .where('conductorId', isEqualTo: driverId)
        .where('estado', whereIn: [
          AppConstants.rideAceptado,
          AppConstants.rideEnCurso,
        ])
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return RideRequestModel.fromMap(snapshot.docs.first.data());
        });
  }
}
