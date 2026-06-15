// lib/widgets/ml_card_test_export.dart
// Thin barrel that re-exports _MlCard as a public widget for golden tests.
// Only import from test/ files.

export '../screens/city_detail_screen.dart' show MlCardTestExport;

// NOTE: For this to work, rename the private _MlCard class in
// city_detail_screen.dart to MlCardTestExport (or add a public alias).
// The golden test file above imports this barrel.
//
// If you prefer to keep _MlCard private, copy the build() body into this
// file as a standalone widget instead.
