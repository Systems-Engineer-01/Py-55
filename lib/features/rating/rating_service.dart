import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:py55/core/constants.dart';

/// Servicio para el registro de calificaciones de viajes en Firestore.
class RatingService {
  final FirebaseFirestore _firestore;

  RatingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Registra una calificación en la subcolección "viajes/{rideId}/calificaciones".
  Future<void> submitRating({
    required String rideId,
    required String quienCalifica,
    required String aCalificado,
    required int estrellas,
    String? comentario,
  }) async {
    final docRef = _firestore
        .collection(AppConstants.ridesCollection)
        .doc(rideId)
        .collection('calificaciones')
        .doc();

    await docRef.set({
      'id': docRef.id,
      'rideId': rideId,
      'quienCalifica': quienCalifica,
      'aCalificado': aCalificado,
      'estrellas': estrellas,
      'comentario': comentario ?? '',
      'fecha': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
