// lib/constants/locale_constants.dart
import 'package:flutter/material.dart';

/// Locales supported by the app.
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('hi'),
  Locale('mai'), // Maithili
  Locale('bho'), // Bhojpuri
];

/// Human-readable labels for each supported locale.
const Map<String, String> kLocaleLabels = {
  'en': 'English',
  'hi': 'हिंदी',
  'mai': 'मैथिली',
  'bho': 'भोजपुरी',
};
