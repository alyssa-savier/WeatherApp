import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'weather_storage.dart';
import 'package:connectivity/connectivity.dart';
import 'package:workmanager/workmanager.dart';
import 'config.dart';
import 'package:permission_handler/permission_handler.dart';


class WeatherData {
  final String location;
  final double temperature;
  final DateTime timestamp;

  WeatherData({
    required this.location,
    required this.temperature,
    required this.timestamp,
  });
}

Future<bool> hasInternetConnection() async {
  final connectivityResult = await Connectivity().checkConnectivity();
  return connectivityResult != ConnectivityResult.none;
}

void main() { 
  runApp(WeatherApp());

  // Initialize the WorkManager package
  Workmanager().initialize(callbackDispatcher);
}

class WeatherApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    requestLocationPermission();

    return MaterialApp(
      home: WeatherHome(),
    );
  }
}

class WeatherHome extends StatefulWidget {
  @override
  _WeatherHomeState createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome> {
  final String apiKey = openWeatherMapApiKey;
  WeatherData? currentWeatherData;
  bool isLoading = true;

  // Additional cities
  List<String> cities = [
    'New York',
    'Singapore',
    'Mumbai',
    'Delhi',
    'Sydney',
    'Melbourne',
  ];
  List<WeatherData?> cityWeatherData = List.filled(6, null);

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final storage = WeatherStorage();
    currentWeatherData = await storage.getWeatherData();

    if (currentWeatherData == null) {
      await _getLocationAndWeather();
    }

    // Fetch weather data for additional cities
    await _fetchCityWeatherData();

    setState(() {
      isLoading = false;
    });

    Workmanager().registerOneOffTask(
      'weatherUpdateTask',
      'backgroundWeatherTask',
      inputData: <String, dynamic>{},
    );
  }

  Future<void> _fetchCityWeatherData() async {
    for (int i = 0; i < cities.length; i++) {
      final cityWeather = await _getCityWeather(cities[i]);
      setState(() {
        cityWeatherData[i] = cityWeather;
      });
    }
  }

  Future<WeatherData> _getCityWeather(String city) async {
    final url =
        'https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return WeatherData(
        location: data['name'],
        temperature: data['main']['temp'],
        timestamp: DateTime.now(),
      );
    } else {
      throw Exception('Failed to fetch weather data for $city');
    }
  }


  Future<void> _getLocationAndWeather() async {
    final hasInternet = await hasInternetConnection();

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
    } catch (e) {
      print('Error while getting location: $e');
      setState(() {
        isLoading = false;
      });
      return;
    }

    if (hasInternet) {
      print('$hasInternet');
      final double lat = position.latitude;
      final double lon = position.longitude;
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric';

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final weatherData = WeatherData(
            location: data['name'],
            temperature: data['main']['temp'],
            timestamp: DateTime.now(),
          );

          final storage = WeatherStorage();
          await storage.saveWeatherData(weatherData);

          setState(() {
            currentWeatherData = weatherData;
            isLoading = false;
          });
        } else {
          print('Error: ${response.statusCode}');
          setState(() {
            isLoading = false;
          });
        }
      } catch (e) {
        print('Error while fetching weather data: $e');
        setState(() {
          isLoading = false;
        });
      }
    } else {
      // No internet connection, display saved data if available
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weather App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Wrap the current weather in a Card widget
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: isLoading
                    ? CircularProgressIndicator()
                    : currentWeatherData != null
                        ? Text(
                            'Current Temperature: ${currentWeatherData!.temperature}°C')
                        : Text('Failed to fetch weather data.'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                requestLocationPermission();
              },
              child: Text('Request Location Permission'),
            ),
            // Display weather for additional cities in Card widgets
            ...cityWeatherData.map((cityData) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: cityData != null
                      ? Text('Temperature in ${cityData.location}: ${cityData.temperature}°C')
                      : Text('Failed to fetch weather data for this city.'),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

final GlobalKey<_WeatherHomeState> _weatherHomeKey = GlobalKey();

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'weatherUpdateTask') {
      final _WeatherHomeState? homeState = _weatherHomeKey.currentState;
      if (homeState != null) {
        await homeState._getLocationAndWeather();
      }
    }
    return Future.value(true);
  });

  // Unregister the task to prevent scheduling duplicates
  Workmanager().cancelByTag('weatherUpdateTask');
}

// Function to request location permission
Future<void> requestLocationPermission() async {
  // Check if the permission is already granted
  if (await Permission.location.isGranted) {
    // Permission is already granted, no need to request it again
    return;
  }

  // Request the permission
  PermissionStatus status = await Permission.location.request();
  if (status.isGranted) {
    // Permission granted
    print('Location permission granted.');
  } else if (status.isDenied) {
    // Permission denied
    print('Location permission denied.');
  } else if (status.isPermanentlyDenied) {
    // Permission permanently denied, show a dialog to guide the user to the app settings
    print('Location permission permanently denied.');
    openAppSettings();
  }
}