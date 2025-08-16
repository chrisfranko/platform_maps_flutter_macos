# platform_maps_flutter_macos

[![pub package](https://img.shields.io/pub/v/platform_maps_flutter_macos.svg)](https://pub.dev/packages/platform_maps_flutter_macos)

The macOS implementation of [`platform_maps_flutter`](https://pub.dev/packages/platform_maps_flutter).

## About

This package provides a macOS implementation for the `platform_maps_flutter` plugin using Apple's MapKit framework via the [`flutter_macos_maps`](https://pub.dev/packages/flutter_macos_maps) package. It enables Flutter applications to display interactive maps with native macOS performance and appearance.

## Features

- **Native MapKit Integration**: Uses Apple's MapKit for authentic macOS map experience
- **Multiple Map Types**: Support for standard, satellite, and hybrid map views
- **Interactive Elements**:
  - Markers with customizable info windows
  - Polylines for route visualization
  - Polygons for area highlighting
  - Circles for radius visualization
- **Camera Controls**: Animate and move camera with zoom, pan, and bounds fitting
- **Touch Interactions**: Handle tap and long press gestures on the map
- **Event Callbacks**: Respond to camera changes, marker taps, and map interactions

## Requirements

- macOS 10.11 or later
- Flutter 3.22.0 or later
- Dart SDK 3.3.0 or later

## Installation

This plugin is typically used as part of the federated `platform_maps_flutter` plugin and is automatically included when you add `platform_maps_flutter` to your dependencies.

However, if you need to use it directly:

```yaml
dependencies:
  platform_maps_flutter_macos: ^0.1.0
  platform_maps_flutter_platform_interface: ^1.0.0-beta.1
```

## Usage

### Basic Implementation

```dart
import 'package:flutter/material.dart';
import 'package:platform_maps_flutter_platform_interface/platform_maps_flutter_platform_interface.dart';
import 'package:platform_maps_flutter_macos/platform_maps_flutter_macos.dart';

void main() {
  // Register the macOS implementation
  PlatformMapsFlutterMacOS.registerWith();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('macOS Maps')),
        body: MapView(),
      ),
    );
  }
}

class MapView extends StatefulWidget {
  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  PlatformMapController? _controller;
  
  @override
  Widget build(BuildContext context) {
    final params = PlatformMapsPlatformWidgetCreationParams(
      initialCameraPosition: CameraPosition(
        target: LatLng(37.7749, -122.4194), // San Francisco
        zoom: 12.0,
      ),
      onMapCreated: (controller) {
        _controller = controller;
      },
      onTap: (position) {
        print('Map tapped at: ${position.latitude}, ${position.longitude}');
      },
    );

    return PlatformMapsPlatform.instance!
        .createPlatformMapsPlatformWidget(params)
        .build(context);
  }
}
```

### Adding Markers

```dart
Set<Marker> markers = {
  Marker(
    markerId: MarkerId('marker1'),
    position: LatLng(37.7749, -122.4194),
    infoWindow: InfoWindow(
      title: 'San Francisco',
      snippet: 'A beautiful city',
    ),
    onTap: () {
      print('Marker tapped!');
    },
  ),
};

// Pass markers to PlatformMapsPlatformWidgetCreationParams
final params = PlatformMapsPlatformWidgetCreationParams(
  // ... other parameters
  markers: markers,
);
```

### Adding Shapes

```dart
// Polyline example
Set<Polyline> polylines = {
  Polyline(
    polylineId: PolylineId('route'),
    points: [
      LatLng(37.7749, -122.4194),
      LatLng(37.7849, -122.4094),
      LatLng(37.7949, -122.3994),
    ],
    color: Colors.blue,
    width: 3,
  ),
};

// Polygon example
Set<Polygon> polygons = {
  Polygon(
    polygonId: PolygonId('area'),
    points: [
      LatLng(37.7749, -122.4194),
      LatLng(37.7849, -122.4094),
      LatLng(37.7949, -122.3994),
      LatLng(37.7849, -122.4294),
    ],
    fillColor: Colors.red.withOpacity(0.3),
    strokeColor: Colors.red,
    strokeWidth: 2,
  ),
};

// Circle example
Set<Circle> circles = {
  Circle(
    circleId: CircleId('radius'),
    center: LatLng(37.7749, -122.4194),
    radius: 1000, // meters
    fillColor: Colors.green.withOpacity(0.3),
    strokeColor: Colors.green,
    strokeWidth: 2,
  ),
};
```

### Camera Controls

```dart
// Animate to a specific location
_controller?.animateCamera(
  CameraUpdate.newLatLngZoom(
    LatLng(37.7749, -122.4194),
    15.0,
  ),
);

// Zoom in/out
_controller?.animateCamera(CameraUpdate.zoomIn());
_controller?.animateCamera(CameraUpdate.zoomOut());

// Fit bounds
_controller?.animateCamera(
  CameraUpdate.newLatLngBounds(
    LatLngBounds(
      southwest: LatLng(37.7049, -122.4894),
      northeast: LatLng(37.8449, -122.3494),
    ),
    100.0, // padding
  ),
);
```

## Platform-Specific Notes

This implementation uses Apple's MapKit framework and provides:

- Native scrolling and zooming performance
- Consistent appearance with macOS system preferences
- Automatic dark mode support (when available in MapKit)
- High-resolution rendering on Retina displays

## Limitations

- Some advanced MapKit features may not be exposed through the platform interface
- Snapshot functionality is not yet implemented
- Info window display/hide control is not fully implemented

## Contributing

This plugin is part of the `platform_maps_flutter` ecosystem. Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

See the [LICENSE](LICENSE) file for details.
