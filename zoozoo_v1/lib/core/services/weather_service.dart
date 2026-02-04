import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

enum WeatherType {
  clear,
  rain, // * 1.15
  heavyRain, // * 1.3
}

class WeatherService {
  // Open-Meteo API (Free, No Key required)
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherType> fetchCurrentWeather(double lat, double lng) async {
    try {
      final url = Uri.parse(
          '$_baseUrl?latitude=$lat&longitude=$lng&current_weather=true');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final currentWeather = data['current_weather'];
        final int weatherCode = currentWeather['weathercode'];

        debugPrint('Weather Code: $weatherCode');
        return _mapCodeToType(weatherCode);
      } else {
        debugPrint('Failed to load weather: ${response.statusCode}');
        return WeatherType.clear;
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
      return WeatherType.clear; // Default to clear on error
    }
  }

  WeatherType _mapCodeToType(int code) {
    // WMO Weather interpretation codes (WW)
    // 0: Clear sky
    // 1, 2, 3: Mainly clear, partly cloudy, and overcast
    // 45, 48: Fog
    // 51, 53, 55: Drizzle: Light, moderate, and dense intensity
    // 56, 57: Freezing Drizzle
    // 61, 63: Rain: Slight, moderate (Light Rain) -> 1.15x
    // 65: Rain: Heavy intensity (Heavy Rain) -> 1.3x
    // 66, 67: Freezing Rain
    // 80, 81: Rain showers: Slight, moderate
    // 82: Rain showers: Violent -> 1.3x
    // 95, 96, 99: Thunderstorm -> 1.3x

    if ([65, 82, 95, 96, 99].contains(code)) {
      return WeatherType.heavyRain;
    } else if ([51, 53, 55, 61, 63, 66, 67, 80, 81].contains(code)) {
      return WeatherType.rain;
    } else {
      return WeatherType.clear;
    }
  }
}
