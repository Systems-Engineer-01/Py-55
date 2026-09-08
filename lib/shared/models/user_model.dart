/// Modelo de usuario (pasajero o mototaxista).
class UserModel {
  final String id;
  final String telefono;
  final String rol; // "pasajero" | "mototaxista"
  final String nombre;
  final String? fotoPerfilUrl;
  final bool verificado;
  final DateTime fechaRegistro;

  UserModel({
    required this.id,
    required this.telefono,
    required this.rol,
    required this.nombre,
    this.fotoPerfilUrl,
    this.verificado = false,
    required this.fechaRegistro,
  });

  /// Convierte la instancia a un [Map] compatible con Firestore / RTDB.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'telefono': telefono,
      'rol': rol,
      'nombre': nombre,
      'fotoPerfilUrl': fotoPerfilUrl,
      'verificado': verificado,
      'fechaRegistro': fechaRegistro.millisecondsSinceEpoch,
    };
  }

  /// Crea una instancia a partir de un [Map] leído de Firestore / RTDB.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      telefono: map['telefono'] as String,
      rol: map['rol'] as String,
      nombre: map['nombre'] as String,
      fotoPerfilUrl: map['fotoPerfilUrl'] as String?,
      verificado: map['verificado'] as bool? ?? false,
      fechaRegistro: DateTime.fromMillisecondsSinceEpoch(
        map['fechaRegistro'] as int,
      ),
    );
  }

  @override
  String toString() => 'UserModel(id: $id, nombre: $nombre, rol: $rol)';
}
