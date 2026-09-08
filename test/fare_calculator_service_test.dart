import 'package:flutter_test/flutter_test.dart';
import 'package:py55/features/fare/fare_calculator_service.dart';

void main() {
  group('FareCalculatorService Tests', () {
    test('Caso 1: Distancia corta (~1 km) - Verifica tarifa base y rangos min/max', () {
      // Coordenadas aproximadas a 1.0 km de diferencia en Lima
      const lat1 = -12.046374;
      const lon1 = -77.042793;
      const lat2 = -12.054374;
      const lon2 = -77.042793;

      final estimate = FareCalculatorService.calculateFare(
        origenLat: lat1,
        origenLng: lon1,
        destinoLat: lat2,
        destinoLng: lon2,
      );

      // Verificaciones
      expect(estimate.distanciaKm, greaterThan(0.8));
      expect(estimate.distanciaKm, lessThan(1.2));
      expect(estimate.tarifaMin, greaterThanOrEqualTo(2.0));
      expect(estimate.tarifaMax, greaterThan(estimate.tarifaMin));
      expect(estimate.tarifaSugerida, greaterThanOrEqualTo(estimate.tarifaMin));
      expect(estimate.tarifaSugerida, lessThanOrEqualTo(estimate.tarifaMax));
    });

    test('Caso 2: Distancia mediana (~5 km) - Verifica coherencia de cálculo', () {
      // Coordenadas a aprox 5.2 km de diferencia
      const lat1 = -12.046374;
      const lon1 = -77.042793;
      const lat2 = -12.093374;
      const lon2 = -77.042793;

      final estimate = FareCalculatorService.calculateFare(
        origenLat: lat1,
        origenLng: lon1,
        destinoLat: lat2,
        destinoLng: lon2,
      );

      // Fórmula esperada: tarifaBase(2.0) + 5.2 * costoPorKm(1.2) = ~8.24
      // tarifaMin = 8.24 * 0.8 = ~6.6
      // tarifaMax = 8.24 * 1.2 = ~9.9
      expect(estimate.distanciaKm, closeTo(5.2, 0.3));
      expect(estimate.tarifaSugerida, greaterThan(7.0));
      expect(estimate.tarifaMin, lessThan(estimate.tarifaSugerida));
      expect(estimate.tarifaMax, greaterThan(estimate.tarifaSugerida));
    });

    test('Caso 3: Distancia larga (~15 km) - Verifica escalamiento proporcional', () {
      // Coordenadas a aprox 15 km de distancia
      const lat1 = -12.046374;
      const lon1 = -77.042793;
      const lat2 = -12.181374;
      const lon2 = -77.042793;

      final estimate = FareCalculatorService.calculateFare(
        origenLat: lat1,
        origenLng: lon1,
        destinoLat: lat2,
        destinoLng: lon2,
      );

      expect(estimate.distanciaKm, closeTo(15.0, 0.5));
      expect(estimate.tarifaMin, greaterThan(15.0));
      expect(estimate.tarifaMax, greaterThan(estimate.tarifaMin));
      expect(estimate.tarifaSugerida, greaterThanOrEqualTo(estimate.tarifaMin));
    });
  });
}
