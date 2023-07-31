import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // Import the file where WeatherData is defined

class WeatherStorage {
  static const String _keyLocation = 'location';
  static const String _keyTemperature = 'temperature';
  static const String _keyTimestamp = 'timestamp';

  Future<void> saveWeatherData(WeatherData weatherData) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_keyLocation, weatherData.location);
    prefs.setDouble(_keyTemperature, weatherData.temperature);
    prefs.setString(_keyTimestamp, weatherData.timestamp.toIso8601String());
  }

  Future<WeatherData?> getWeatherData() async {
    final prefs = await SharedPreferences.getInstance();
    final location = prefs.getString(_keyLocation);
    final temperature = prefs.getDouble(_keyTemperature);
    final timestampString = prefs.getString(_keyTimestamp);

    if (location != null && temperature != null && timestampString != null) {
      final timestamp = DateTime.parse(timestampString);
      return WeatherData(
        location: location,
        temperature: temperature,
        timestamp: timestamp,
      );
    }

    return null;
  }
}