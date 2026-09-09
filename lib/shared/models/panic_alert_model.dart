import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para una alerta de pánico registrada por un usuario (pasajero o mototaxista).
class PanicAlertModel {
  final String id;
  final String rideId;
  final String userId;
  final String rol; // "pasajero" | "mototaxista"
  final String nombreUsuario;
  final String telefono;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final String estado; // "activa" | "atendida"

  PanicAlertModel({
    required this.id,
    required this.rideId,
    required this.userId,
    required this.rol,
    required this.nombreUsuario,
    required this.telefono,
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.estado = 'activa',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rideId': rideId,
      'userId': userId,
      'rol': rol,
      'nombreUsuario': nombreUsuario,
      'telefono': telefono,
      'lat': lat,
      'lng': lng,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'estado': estado,
    };
  }

  factory PanicAlertModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime ts;
    final rawTs = map['timestamp'];

    if (rawTs is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else {
      ts = DateTime.now();
    }

    return PanicAlertModel(
      id: docId ?? (map['id'] as String? ?? ''),
      rideId: map['rideId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      rol: map['rol'] as String? ?? 'pasajero',
      nombreUsuario: map['nombreUsuario'] as String? ?? 'Usuario Py55',
      telefono: map['telefono'] as String? ?? '',
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      timestamp: ts,
      estado: map['estado'] as String? ?? 'activa',
    );
  }

  PanicAlertModel copyWith({
    String? id,
    String? rideId,
    String? userId,
    String? rol,
    String? nombreUsuario,
    String? telefono,
    double? lat,
    double? lng,
    DateTime? timestamp,
    String? estado,
  }) {
    return PanicAlertModel(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      userId: userId ?? this.userId,
      rol: rol ?? this.rol,
      nombreUsuario: nombreUsuario ?? this.nombreUsuario,
      telefono: telefono ?? this.telefono,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      timestamp: timestamp ?? this.timestamp,
      estado: estado ?? this.estado,
    );
  }
}
