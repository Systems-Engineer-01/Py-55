/// Modelo de solicitud de viaje.
class RideRequestModel {
  final String id;
  final String pasajeroId;
  final String? conductorId;
  final double origenLat;
  final double origenLng;
  final String origenDireccion;
  final double destinoLat;
  final double destinoLng;
  final String destinoDireccion;
  final double distanciaKm;
  final double tarifaMin;
  final double tarifaMax;
  final double? tarifaAcordada;
  final String estado; // "buscando"|"aceptado"|"en_curso"|"finalizado"|"cancelado"
  final DateTime fechaCreacion;

  RideRequestModel({
    required this.id,
    required this.pasajeroId,
    this.conductorId,
    required this.origenLat,
    required this.origenLng,
    required this.origenDireccion,
    required this.destinoLat,
    required this.destinoLng,
    required this.destinoDireccion,
    required this.distanciaKm,
    required this.tarifaMin,
    required this.tarifaMax,
    this.tarifaAcordada,
    this.estado = 'buscando',
    required this.fechaCreacion,
  });

  RideRequestModel copyWith({
    String? id,
    String? pasajeroId,
    String? conductorId,
    double? origenLat,
    double? origenLng,
    String? origenDireccion,
    double? destinoLat,
    double? destinoLng,
    String? destinoDireccion,
    double? distanciaKm,
    double? tarifaMin,
    double? tarifaMax,
    double? tarifaAcordada,
    String? estado,
    DateTime? fechaCreacion,
  }) {
    return RideRequestModel(
      id: id ?? this.id,
      pasajeroId: pasajeroId ?? this.pasajeroId,
      conductorId: conductorId ?? this.conductorId,
      origenLat: origenLat ?? this.origenLat,
      origenLng: origenLng ?? this.origenLng,
      origenDireccion: origenDireccion ?? this.origenDireccion,
      destinoLat: destinoLat ?? this.destinoLat,
      destinoLng: destinoLng ?? this.destinoLng,
      destinoDireccion: destinoDireccion ?? this.destinoDireccion,
      distanciaKm: distanciaKm ?? this.distanciaKm,
      tarifaMin: tarifaMin ?? this.tarifaMin,
      tarifaMax: tarifaMax ?? this.tarifaMax,
      tarifaAcordada: tarifaAcordada ?? this.tarifaAcordada,
      estado: estado ?? this.estado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  /// Convierte la instancia a un [Map] compatible con Firestore / RTDB.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pasajeroId': pasajeroId,
      'conductorId': conductorId,
      'origenLat': origenLat,
      'origenLng': origenLng,
      'origenDireccion': origenDireccion,
      'destinoLat': destinoLat,
      'destinoLng': destinoLng,
      'destinoDireccion': destinoDireccion,
      'distanciaKm': distanciaKm,
      'tarifaMin': tarifaMin,
      'tarifaMax': tarifaMax,
      'tarifaAcordada': tarifaAcordada,
      'estado': estado,
      'fechaCreacion': fechaCreacion.millisecondsSinceEpoch,
    };
  }

  /// Crea una instancia a partir de un [Map] leído de Firestore / RTDB.
  factory RideRequestModel.fromMap(Map<String, dynamic> map) {
    return RideRequestModel(
      id: map['id'] as String,
      pasajeroId: map['pasajeroId'] as String,
      conductorId: map['conductorId'] as String?,
      origenLat: (map['origenLat'] as num).toDouble(),
      origenLng: (map['origenLng'] as num).toDouble(),
      origenDireccion: map['origenDireccion'] as String,
      destinoLat: (map['destinoLat'] as num).toDouble(),
      destinoLng: (map['destinoLng'] as num).toDouble(),
      destinoDireccion: map['destinoDireccion'] as String,
      distanciaKm: (map['distanciaKm'] as num).toDouble(),
      tarifaMin: (map['tarifaMin'] as num).toDouble(),
      tarifaMax: (map['tarifaMax'] as num).toDouble(),
      tarifaAcordada: (map['tarifaAcordada'] as num?)?.toDouble(),
      estado: map['estado'] as String? ?? 'buscando',
      fechaCreacion: DateTime.fromMillisecondsSinceEpoch(
        map['fechaCreacion'] as int,
      ),
    );
  }

  @override
  String toString() =>
      'RideRequestModel(id: $id, estado: $estado, pasajero: $pasajeroId)';
}
