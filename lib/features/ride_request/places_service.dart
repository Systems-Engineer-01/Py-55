import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:py55/core/constants.dart';

/// Modelo para una sugerencia de búsqueda de Google Places Autocomplete.
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] ?? {};
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structuredFormatting['main_text'] ?? json['description'] ?? '',
      secondaryText: structuredFormatting['secondary_text'] ?? '',
    );
  }
}

/// Modelo para los detalles de un lugar seleccionado (Place Details).
class PlaceDetail {
  final String placeId;
  final String name;
  final String formattedAddress;
  final LatLng location;

  PlaceDetail({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.location,
  });
}

/// Servicio para consultar la API de Google Places (Autocomplete y Place Details).
class PlacesService {
  final http.Client _client;
  final String _apiKey;

  PlacesService({
    http.Client? client,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? AppConstants.googleMapsApiKey;

  /// Obtiene sugerencias de autocompletado filtradas por el país Perú (components=country:pe).
  Future<List<PlacePrediction>> getAutocompleteSuggestions(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json',
    ).replace(queryParameters: {
      'input': query,
      'components': 'country:pe',
      'key': _apiKey,
      'language': 'es',
    });

    try {
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String?;

        if (status == 'OK') {
          final predictionsJson = data['predictions'] as List? ?? [];
          return predictionsJson
              .map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
              .toList();
        } else if (status == 'ZERO_RESULTS') {
          return [];
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Obtiene las coordenadas (lat, lng) y dirección detallada de un place_id.
  Future<PlaceDetail?> getPlaceDetails(String placeId) async {
    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json',
    ).replace(queryParameters: {
      'place_id': placeId,
      'fields': 'geometry,formatted_address,name',
      'key': _apiKey,
      'language': 'es',
    });

    try {
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String?;

        if (status == 'OK' && data['result'] != null) {
          final result = data['result'] as Map<String, dynamic>;
          final geometry = result['geometry'] as Map<String, dynamic>? ?? {};
          final location = geometry['location'] as Map<String, dynamic>? ?? {};

          final lat = (location['lat'] as num?)?.toDouble() ?? 0.0;
          final lng = (location['lng'] as num?)?.toDouble() ?? 0.0;
          final name = result['name'] as String? ?? 'Destino';
          final address = result['formatted_address'] as String? ?? name;

          return PlaceDetail(
            placeId: placeId,
            name: name,
            formattedAddress: address,
            location: LatLng(lat, lng),
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
