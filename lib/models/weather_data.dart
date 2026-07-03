// lib/models/weather_data.dart
// WeatherData is a convenience typedef for WeatherState.
// WeatherState is the canonical class in weather_provider.dart.
library;

export '../providers/weather_provider.dart'
    show
        WeatherState,
        WeatherNotifier,
        weatherProvider,
        WeatherCurrent,
        WeatherDay,
        CityResult,
        WeatherStatus;

// Typedef so any file importing weather_data.dart can use WeatherData
// instead of WeatherState (e.g. monitors_screen.dart: final WeatherData wx)
import '../providers/weather_provider.dart';

typedef WeatherData = WeatherState;
