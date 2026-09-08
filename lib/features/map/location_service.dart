import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Servicio encargado del manejo de GPS y permisos de ubicación con Geolocator.
class LocationService {
  /// Verifica si el servicio de ubicación está activo y solicita permisos al usuario.
  /// Retorna `true` si el permiso fue concedido.
  static Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Obtiene la posición GPS actual del usuario.
  static Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  /// Stream de ubicación en tiempo real para el seguimiento continuo.
  /// Transmite la posición cada vez que el dispositivo se desplaza el filtro especificado (por defecto 5m).
  static Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 5,
  }) {
    final locationSettings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilterMeters,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
