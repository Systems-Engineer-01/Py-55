import 'package:flutter_test/flutter_test.dart';
import 'package:py55/shared/models/panic_alert_model.dart';

void main() {
  group('PanicAlertModel Tests', () {
    test('toMap y fromMap serializan y deserializan correctamente', () {
      final now = DateTime.now();
      final alert = PanicAlertModel(
        id: 'alert_123',
        rideId: 'ride_456',
        userId: 'user_789',
        rol: 'pasajero',
        nombreUsuario: 'Juan Pérez',
        telefono: '+51987654321',
        lat: -12.046374,
        lng: -77.042793,
        timestamp: now,
        estado: 'activa',
      );

      final map = alert.toMap();
      expect(map['id'], equals('alert_123'));
      expect(map['rol'], equals('pasajero'));
      expect(map['estado'], equals('activa'));

      final parsed = PanicAlertModel.fromMap(map, 'alert_123');
      expect(parsed.id, equals('alert_123'));
      expect(parsed.nombreUsuario, equals('Juan Pérez'));
      expect(parsed.lat, equals(-12.046374));
      expect(parsed.lng, equals(-77.042793));
    });
  });
}
