import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:py55/core/constants.dart';

/// Modelo para una sugerencia de búsqueda de Google Places Autocomplete o motor secundario.
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
      placeId: json['place_id']?.toString() ?? '',
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

/// Servicio híbrido de búsqueda (Google Places API con fallback a Nominatim OpenStreetMap Perú).
class PlacesService {
  final http.Client _client;
  final String _apiKey;

  // Cache temporal para resultados resueltos por motor secundario (OSM)
  final Map<String, PlaceDetail> _osmCache = {};

  PlacesService({
    http.Client? client,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? AppConstants.googleMapsApiKey;

  /// Obtiene sugerencias de autocompletado filtradas por el país Perú (components=country:pe).
  /// Soporta sesgo geográfico `userLocation` para priorizar lugares cercanos al usuario.
  Future<List<PlacePrediction>> getAutocompleteSuggestions(
    String query, {
    LatLng? userLocation,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // 1. Intentar consultar Google Places Autocomplete API
    final queryParams = <String, String>{
      'input': cleanQuery,
      'components': 'country:pe',
      'key': _apiKey,
      'language': 'es',
    };

    if (userLocation != null) {
      queryParams['location'] =
          '${userLocation.latitude},${userLocation.longitude}';
      queryParams['radius'] = '50000'; // 50 km de sesgo regional
    }

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'] as String?;

        if (status == 'OK') {
          final predictionsJson = data['predictions'] as List? ?? [];
          final predictions = predictionsJson
              .map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
              .toList();

          if (predictions.isNotEmpty) {
            return predictions;
          }
        }
      }
    } catch (_) {
      // Si falla Google Places (red o bloqueo API), continuar a motor secundario
    }

    // 2. Fallback secundario: Búsqueda en Perú mediante Nominatim / OpenStreetMap
    return await _getOsmSuggestions(cleanQuery);
  }

  /// Búsqueda secundaria en Perú usando OpenStreetMap Nominatim API
  Future<List<PlacePrediction>> _getOsmSuggestions(String query) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search',
    ).replace(queryParameters: {
      'q': query,
      'countrycodes': 'pe',
      'format': 'json',
      'addressdetails': '1',
      'limit': '5',
    });

    try {
      final response = await _client.get(
        uri,
        headers: {'User-Agent': 'Py55_App/1.0'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body) as List? ?? [];
        final List<PlacePrediction> predictions = [];

        for (var item in data) {
          if (item is Map<String, dynamic>) {
            final rawId = item['place_id']?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString();
            final placeId = 'osm_$rawId';

            final displayName = item['display_name'] as String? ?? query;
            final latStr = item['lat'] as String?;
            final lonStr = item['lon'] as String?;

            if (latStr != null && lonStr != null) {
              final lat = double.tryParse(latStr) ?? 0.0;
              final lon = double.tryParse(lonStr) ?? 0.0;

              final nameParts = displayName.split(',');
              final mainText = nameParts.isNotEmpty ? nameParts.first.trim() : displayName;
              final secondaryText = nameParts.length > 1
                  ? nameParts.sublist(1).join(',').trim()
                  : 'Perú';

              // Guardar en cache para resolución instantánea en PlaceDetails
              _osmCache[placeId] = PlaceDetail(
                placeId: placeId,
                name: mainText,
                formattedAddress: displayName,
                location: LatLng(lat, lon),
              );

              predictions.add(PlacePrediction(
                placeId: placeId,
                description: displayName,
                mainText: mainText,
                secondaryText: secondaryText,
              ));
            }
          }
        }

        return predictions;
      }
    } catch (_) {
      return [];
    }

    return [];
  }

  /// Obtiene las coordenadas (lat, lng) y dirección detallada de un place_id.
  Future<PlaceDetail?> getPlaceDetails(String placeId) async {
    // Si fue generado por el motor secundario OSM
    if (placeId.startsWith('osm_') && _osmCache.containsKey(placeId)) {
      return _osmCache[placeId];
    }

    // Google Place Details API
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
