import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:py55/features/ride_request/places_service.dart';

void main() {
  group('PlacesService Tests', () {
    test('getAutocompleteSuggestions devuelve sugerencias correctamente para Peru', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('components=country%3Ape'));
        expect(request.url.toString(), contains('input=Plaza'));

        return http.Response('''
        {
          "status": "OK",
          "predictions": [
            {
              "place_id": "ChIJ111",
              "description": "Plaza de Armas, Lima, Perú",
              "structured_formatting": {
                "main_text": "Plaza de Armas",
                "secondary_text": "Lima, Perú"
              }
            }
          ]
        }
        ''', 200);
      });

      final service = PlacesService(client: mockClient, apiKey: 'TEST_KEY');
      final result = await service.getAutocompleteSuggestions('Plaza');

      expect(result.length, equals(1));
      expect(result.first.mainText, equals('Plaza de Armas'));
      expect(result.first.placeId, equals('ChIJ111'));
    });

    test('getPlaceDetails obtiene latitud y longitud correctamente', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('place_id=ChIJ111'));

        return http.Response('''
        {
          "status": "OK",
          "result": {
            "name": "Plaza de Armas",
            "formatted_address": "Jirón de la Unión, Lima 15001, Perú",
            "geometry": {
              "location": {
                "lat": -12.046374,
                "lng": -77.042793
              }
            }
          }
        }
        ''', 200);
      });

      final service = PlacesService(client: mockClient, apiKey: 'TEST_KEY');
      final detail = await service.getPlaceDetails('ChIJ111');

      expect(detail, isNotNull);
      expect(detail!.name, equals('Plaza de Armas'));
      expect(detail.location.latitude, equals(-12.046374));
      expect(detail.location.longitude, equals(-77.042793));
    });
  });
}
