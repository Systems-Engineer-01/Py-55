import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:py55/core/constants.dart';
import 'package:py55/shared/models/driver_profile_model.dart';

/// Servicio de verificación de documentos.
///
/// Sube imágenes a Firebase Storage y actualiza los modelos en Firestore.
class VerificationService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Subir archivo a Storage ─────────────────────────────────────

  /// Sube un archivo a `verificaciones/{userId}/{tipoDocumento}.jpg`
  /// y devuelve la URL de descarga.
  Future<String> uploadDocument({
    required String userId,
    required String tipoDocumento,
    required File file,
  }) async {
    final ref =
        _storage.ref().child('verificaciones/$userId/$tipoDocumento.jpg');

    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await uploadTask.ref.getDownloadURL();
  }

  // ── Conductor: perfil completo ──────────────────────────────────

  /// Obtiene el [DriverProfileModel] desde Firestore. Null si no existe.
  Future<DriverProfileModel?> getDriverProfile(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.driversCollection)
        .doc(userId)
        .get();
    if (doc.exists && doc.data() != null) {
      return DriverProfileModel.fromMap(doc.data()!);
    }
    return null;
  }

  /// Guarda o actualiza el [DriverProfileModel] en Firestore.
  Future<void> saveDriverProfile(DriverProfileModel profile) async {
    await _firestore
        .collection(AppConstants.driversCollection)
        .doc(profile.userId)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  /// Sube un documento del conductor y actualiza su perfil en Firestore.
  ///
  /// [tipoDocumento] debe ser uno de: "dni", "licencia", "soat", "foto_vehiculo".
  Future<String> uploadDriverDocument({
    required String userId,
    required String tipoDocumento,
    required File file,
  }) async {
    // 1. Subir a Storage
    final url = await uploadDocument(
      userId: userId,
      tipoDocumento: tipoDocumento,
      file: file,
    );

    // 2. Leer perfil actual (o crear uno nuevo)
    DriverProfileModel profile =
        await getDriverProfile(userId) ??
        DriverProfileModel(userId: userId);

    // 3. Actualizar el campo correspondiente
    switch (tipoDocumento) {
      case 'dni':
        profile = profile.copyWith(dniUrl: url);
        break;
      case 'licencia':
        profile = profile.copyWith(licenciaUrl: url);
        break;
      case 'soat':
        profile = profile.copyWith(soatUrl: url);
        break;
      case 'foto_vehiculo':
        profile = profile.copyWith(fotoVehiculoUrl: url);
        break;
    }

    // 4. Guardar en Firestore
    await saveDriverProfile(profile);

    return url;
  }

  /// Marca el perfil del conductor como "pendiente" de verificación.
  Future<void> submitDriverForVerification(String userId) async {
    await _firestore
        .collection(AppConstants.driversCollection)
        .doc(userId)
        .update({
      'estadoVerificacion': AppConstants.verificacionPendiente,
    });
  }

  // ── Pasajero: solo DNI ──────────────────────────────────────────

  /// Sube el DNI del pasajero y actualiza su perfil en Firestore.
  Future<String> uploadPassengerDni({
    required String userId,
    required File file,
  }) async {
    final url = await uploadDocument(
      userId: userId,
      tipoDocumento: 'dni',
      file: file,
    );

    // Actualizar dniUrl y marcar verificado = false (pendiente de revisión)
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({
      'dniUrl': url,
      'verificado': false,
    });

    return url;
  }
}
