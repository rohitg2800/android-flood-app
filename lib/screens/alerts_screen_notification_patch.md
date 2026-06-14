# AlertsScreen — Notification Deep-link Patch

## What changed

`main.dart` now passes an optional `stationFilter` String argument when
navigating to `/alerts` from a notification tap.

## Required change in `alerts_screen.dart`

Add the optional constructor param and use it to pre-filter the list:

```dart
class AlertsScreen extends StatefulWidget {
  static const route = '/alerts';

  /// When non-null, the screen pre-filters to show only alerts for this station.
  final String? stationFilter;

  const AlertsScreen({super.key, this.stationFilter});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}
```

In `_AlertsScreenState.initState()`:

```dart
@override
void initState() {
  super.initState();
  if (widget.stationFilter != null && widget.stationFilter!.isNotEmpty) {
    // Pre-populate the search field with the station name
    _searchController.text = widget.stationFilter!;
    _filterQuery = widget.stationFilter!;
  }
}
```

This makes the Alerts screen automatically highlight the relevant station
when opened from a notification tap.
