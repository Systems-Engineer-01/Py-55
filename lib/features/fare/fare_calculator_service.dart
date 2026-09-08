import 'dart:math';

/// Resultado del cálculo de tarifa para una solicitud de viaje.
class FareEstimate {
  final double distanciaKm;
  final double tarifaBase;
  final double costoPorKm;
  final double tarifaSugerida;
  final double tarifaMin;
  final double tarifaMax;

  const FareEstimate({
    required this.distanciaKm,
    required this.tarifaBase,
    required this.costoPorKm,
    required this.tarifaSugerida,
    required this.tarifaMin,
    required this.tarifaMax,
  });
}

/// Servicio encargado del cálculo de distancias por fórmula Haversine y estimado de tarifas.
class FareCalculatorService {
  // Parámetros configurables de tarifa en Soles (S/)
  static const double defaultTarifaBase = 2.0;
  static const double defaultCostoPorKm = 1.2;
  static const double defaultMargenPorcentaje = 0.20; // ±20%

  /// Calcula la distancia en kilómetros entre dos coordenadas usando la fórmula Haversine.
  static double calculateDistanceKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double r = 6371.0; // Radio de la Tierra en kilómetros
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  /// Calcula el estimado de tarifa completa (rango sugerido min - max) para un viaje.
  static FareEstimate calculateFare({
    required double origenLat,
    required double origenLng,
    required double destinoLat,
    required double destinoLng,
    double tarifaBase = defaultTarifaBase,
    double costoPorKm = defaultCostoPorKm,
    double margenPorcentaje = defaultMargenPorcentaje,
  }) {
    final distancia = calculateDistanceKm(
      lat1: origenLat,
      lon1: origenLng,
      lat2: destinoLat,
      lon2: destinoLng,
    );

    final tarifaCalculada = tarifaBase + (distancia * costoPorKm);
    
    // Garantiza una tarifa sugerida mínima de S/ 2.50
    final tarifaSugerida = max(2.5, tarifaCalculada);

    final tarifaMinRaw = (tarifaBase + distancia * costoPorKm) * (1 - margenPorcentaje);
    final tarifaMaxRaw = (tarifaBase + distancia * costoPorKm) * (1 + margenPorcentaje);

    // Redondear a 1 decimal para montos limpios en Soles
    final tarifaMin = _roundToOneDecimal(max(2.0, tarifaMinRaw));
    final tarifaMax = _roundToOneDecimal(max(3.0, tarifaMaxRaw));
    final sugeridaFinal = _roundToOneDecimal(tarifaSugerida);

    return FareEstimate(
      distanciaKm: double.parse(distancia.toStringAsFixed(2)),
      tarifaBase: tarifaBase,
      costoPorKm: costoPorKm,
      tarifaSugerida: sugeridaFinal,
      tarifaMin: tarifaMin,
      tarifaMax: tarifaMax,
    );
  }

  static double _toRadians(double degree) {
    return degree * (pi / 180.0);
  }

  static double _roundToOneDecimal(double val) {
    return (val * 10).roundToDouble() / 10;
  }
}
