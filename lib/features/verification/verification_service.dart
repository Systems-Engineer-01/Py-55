import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:py55/core/constants.dart';
import 'package:py55/shared/models/driver_profile_model.dart';

/// Servicio de verificación de documentos.
///
/// Sube imágenes a Cloudinary vía HTTP Multipart POST y actualiza los modelos en Firestore.
class VerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _cloudName = 'josvvli9';
  static const String _uploadPreset = 'py55_unsigned';
  static final Uri _cloudinaryUrl = Uri.parse(
    'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
  );

  // ── Subir archivo a Cloudinary ─────────────────────────────────

  /// Sube una imagen a Cloudinary y devuelve el [secure_url].
  Future<String> uploadDocument({
    required String userId,
    required String tipoDocumento,
    required File file,
  }) async {
    if (!file.existsSync()) {
      throw Exception('El archivo seleccionado no existe en el dispositivo.');
    }

    try {
      final request = http.MultipartRequest('POST', _cloudinaryUrl)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
              'Tiempo de espera agotado al conectar con Cloudinary. Verifica tu conexión a internet.');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final secureUrl = responseData['secure_url'] as String?;
        if (secureUrl != null && secureUrl.isNotEmpty) {
          return secureUrl;
        } else {
          throw Exception('La respuesta de Cloudinary no contiene una URL válida.');
        }
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        String errorMessage =
            errorData['error']?['message'] ?? 'Error desconocido (${response.statusCode})';
        if (errorMessage.contains('whitelisted for unsigned uploads')) {
          errorMessage =
              'El preset "$_uploadPreset" en Cloudinary debe configurarse como "Unsigned" en la consola de Cloudinary (Settings -> Upload -> Upload presets -> Signing Mode: Unsigned).';
        }
        throw Exception(errorMessage);
      }
    } on SocketException {
      throw Exception('Sin conexión a internet. Comprueba tu red e intenta de nuevo.');
    } on HttpException {
      throw Exception('Error al comunicarse con el servidor de imágenes.');
    } on FormatException {
      throw Exception('Respuesta no válida del servidor de imágenes.');
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Error al subir la imagen: $e');
    }
  }

  // ── Conductor: perfil completo ──────────────────────────────────

  /// Obtiene el [DriverProfileModel] desde Firestore. Null si no existe.
  Future<DriverProfileModel?> getDriverProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.driversCollection)
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 5));
      if (doc.exists && doc.data() != null) {
        return DriverProfileModel.fromMap(doc.data()!);
      }
    } catch (_) {}
    return null;
  }

  /// Guarda o actualiza el [DriverProfileModel] en Firestore.
  Future<void> saveDriverProfile(DriverProfileModel profile) async {
    try {
      await _firestore
          .collection(AppConstants.driversCollection)
          .doc(profile.userId)
          .set(profile.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Sube un documento del conductor a Cloudinary y actualiza su perfil en Firestore.
  ///
  /// [tipoDocumento] debe ser uno de: "dni", "licencia", "soat", "foto_vehiculo".
  Future<String> uploadDriverDocument({
    required String userId,
    required String tipoDocumento,
    required File file,
  }) async {
    // 1. Subir a Cloudinary
    final url = await uploadDocument(
      userId: userId,
      tipoDocumento: tipoDocumento,
      file: file,
    );

    // 2. Leer perfil actual (o crear uno nuevo)
    DriverProfileModel profile =
        await getDriverProfile(userId) ??
        DriverProfileModel(userId: userId);

    // 3. Actualizar el campo correspondiente con la URL de Cloudinary
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
    try {
      await _firestore
          .collection(AppConstants.driversCollection)
          .doc(userId)
          .update({
        'estadoVerificacion': AppConstants.verificacionPendiente,
      }).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  // ── Pasajero: solo DNI ──────────────────────────────────────────

  /// Sube el DNI del pasajero a Cloudinary y actualiza su perfil en Firestore.
  Future<String> uploadPassengerDni({
    required String userId,
    required File file,
  }) async {
    final url = await uploadDocument(
      userId: userId,
      tipoDocumento: 'dni',
      file: file,
    );

    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({
        'dniUrl': url,
        'verificado': false,
      }).timeout(const Duration(seconds: 5));
    } catch (_) {}

    return url;
  }
}
