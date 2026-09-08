import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/shared/models/ride_request_model.dart';

/// Servicio para la creación, cancelación y monitoreo en tiempo real de solicitudes de viaje.
class RideRequestService {
  final FirebaseFirestore _firestore;

  RideRequestService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Crea una nueva solicitud de viaje en Firestore bajo la colección "viajes".
  /// Retorna el ID del documento generado.
  Future<String> createRideRequest(RideRequestModel ride) async {
    final docRef = _firestore.collection(AppConstants.ridesCollection).doc();

    final newRide = ride.copyWith(id: docRef.id);

    await docRef.set(newRide.toMap());
    return docRef.id;
  }

  /// Escucha en tiempo real los cambios del documento de un viaje (por ejemplo, cambio de estado de "buscando" a "aceptado").
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

  /// Cancela la solicitud de viaje marcando su estado como "cancelado".
  Future<void> cancelRideRequest(String rideId) async {
    await _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .update({
      'estado': AppConstants.rideCancelado,
    });
  }
}
