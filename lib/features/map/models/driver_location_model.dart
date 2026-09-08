/// Modelo de datos para las ubicaciones en tiempo real de los conductores
/// guardadas en Firebase Realtime Database en "ubicaciones_activas/{userId}".
class DriverLocationModel {
  final String driverId;
  final double latitude;
  final double longitude;
  final double heading;
  final int timestamp;
  final bool isAvailable;

  const DriverLocationModel({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    this.heading = 0.0,
    required this.timestamp,
    this.isAvailable = true,
  });

  /// Crea la instancia a partir de un Map obtenido de Firebase Realtime Database.
  factory DriverLocationModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return DriverLocationModel(
      driverId: id,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      isAvailable: (map['isAvailable'] as bool?) ?? true,
    );
  }

  /// Convierte la instancia a un Map para guardar en Firebase Realtime Database.
  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'timestamp': timestamp,
      'isAvailable': isAvailable,
    };
  }
}
