/// Perfil de conductor / mototaxista con documentos de verificación.
class DriverProfileModel {
  final String userId;
  final String? dniUrl;
  final String? licenciaUrl;
  final String? soatUrl;
  final String? fotoVehiculoUrl;
  final String? placaVehiculo;
  final String estadoVerificacion; // "pendiente" | "aprobado" | "rechazado"
  final bool disponible;
  final double? lat;
  final double? lng;
  final double calificacionPromedio;

  DriverProfileModel({
    required this.userId,
    this.dniUrl,
    this.licenciaUrl,
    this.soatUrl,
    this.fotoVehiculoUrl,
    this.placaVehiculo,
    this.estadoVerificacion = 'pendiente',
    this.disponible = false,
    this.lat,
    this.lng,
    this.calificacionPromedio = 0.0,
  });

  /// Convierte la instancia a un [Map] compatible con Firestore / RTDB.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'dniUrl': dniUrl,
      'licenciaUrl': licenciaUrl,
      'soatUrl': soatUrl,
      'fotoVehiculoUrl': fotoVehiculoUrl,
      'placaVehiculo': placaVehiculo,
      'estadoVerificacion': estadoVerificacion,
      'disponible': disponible,
      'lat': lat,
      'lng': lng,
      'calificacionPromedio': calificacionPromedio,
    };
  }

  /// Crea una instancia a partir de un [Map] leído de Firestore / RTDB.
  factory DriverProfileModel.fromMap(Map<String, dynamic> map) {
    return DriverProfileModel(
      userId: map['userId'] as String,
      dniUrl: map['dniUrl'] as String?,
      licenciaUrl: map['licenciaUrl'] as String?,
      soatUrl: map['soatUrl'] as String?,
      fotoVehiculoUrl: map['fotoVehiculoUrl'] as String?,
      placaVehiculo: map['placaVehiculo'] as String?,
      estadoVerificacion:
          map['estadoVerificacion'] as String? ?? 'pendiente',
      disponible: map['disponible'] as bool? ?? false,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      calificacionPromedio:
          (map['calificacionPromedio'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Crea una copia con campos opcionales actualizados.
  DriverProfileModel copyWith({
    String? userId,
    String? dniUrl,
    String? licenciaUrl,
    String? soatUrl,
    String? fotoVehiculoUrl,
    String? placaVehiculo,
    String? estadoVerificacion,
    bool? disponible,
    double? lat,
    double? lng,
    double? calificacionPromedio,
  }) {
    return DriverProfileModel(
      userId: userId ?? this.userId,
      dniUrl: dniUrl ?? this.dniUrl,
      licenciaUrl: licenciaUrl ?? this.licenciaUrl,
      soatUrl: soatUrl ?? this.soatUrl,
      fotoVehiculoUrl: fotoVehiculoUrl ?? this.fotoVehiculoUrl,
      placaVehiculo: placaVehiculo ?? this.placaVehiculo,
      estadoVerificacion: estadoVerificacion ?? this.estadoVerificacion,
      disponible: disponible ?? this.disponible,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      calificacionPromedio: calificacionPromedio ?? this.calificacionPromedio,
    );
  }

  @override
  String toString() =>
      'DriverProfileModel(userId: $userId, estado: $estadoVerificacion)';
}
