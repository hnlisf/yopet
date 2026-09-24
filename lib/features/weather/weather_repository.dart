import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'weather_models.dart';

class WeatherLookupException implements Exception {
  const WeatherLookupException(this.message);

  final String message;
}

List<WeatherCity> weatherCitiesFromResponse(String body) {
  final decoded = jsonDecode(body) as Map<String, dynamic>;
  final results = (decoded['results'] as List? ?? const <dynamic>[])
      .cast<Map<String, dynamic>>();
  return results.map(WeatherCity.fromOpenMeteo).toList(growable: false);
}

WeatherSnapshot weatherSnapshotFromResponse({
  required WeatherCity city,
  required String body,
}) {
  return WeatherSnapshot.fromOpenMeteo(
    city: city,
    payload: (jsonDecode(body) as Map).cast<String, dynamic>(),
  );
}

abstract class WeatherRepository {
  Future<List<WeatherCity>> searchCities(String query);

  Future<WeatherSnapshot> refreshWeather({
    required String tankId,
    required WeatherCity city,
  });
}

/// Reads public, keyless Open-Meteo endpoints directly. The request contains
/// only the city the player explicitly selected; no precise device location is
/// collected or stored by yopet.
class OpenMeteoWeatherRepository implements WeatherRepository {
  OpenMeteoWeatherRepository(this._supabase, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final SupabaseClient _supabase;
  final http.Client _httpClient;

  @override
  Future<List<WeatherCity>> searchCities(String query) async {
    final normalized = query.trim();
    if (normalized.length < 2) return const <WeatherCity>[];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': normalized,
      'count': '6',
      'language': 'zh',
      'format': 'json',
    });
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw const WeatherLookupException('城市暂时没有回应');
    }
    return weatherCitiesFromResponse(response.body);
  }

  @override
  Future<WeatherSnapshot> refreshWeather({
    required String tankId,
    required WeatherCity city,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': city.latitude.toString(),
      'longitude': city.longitude.toString(),
      'current': 'temperature_2m,weather_code,is_day',
      'timezone': 'auto',
    });
    final response = await _httpClient.get(uri);
    if (response.statusCode != 200) {
      throw const WeatherLookupException('天气暂时没有回应');
    }
    final snapshot = weatherSnapshotFromResponse(
      city: city,
      body: response.body,
    );
    await _supabase
        .from('tanks')
        .update(snapshot.toTankUpdate())
        .eq('id', tankId);
    return snapshot;
  }
}
