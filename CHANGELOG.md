# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-08-16

### Added
- **Initial Release**: Complete macOS implementation for platform_maps_flutter
- **Native MapKit Integration**: Uses Apple's MapKit framework via flutter_macos_maps
- **Map Types**: Support for standard, satellite, and hybrid map views
- **Interactive Elements**:
  - Markers with customizable info windows and tap callbacks
  - Polylines with customizable color, width, and points
  - Polygons with stroke and fill color customization
  - Circles with radius, stroke, and fill customization
- **Camera Controls**: 
  - Animate and move camera operations
  - Support for newCameraPosition, newLatLng, newLatLngZoom, newLatLngBounds
  - Zoom operations: zoomIn, zoomOut, zoomBy, zoomTo
  - Bounds fitting with padding support
- **Touch Interactions**: 
  - Map tap and long press gesture handling
  - Marker tap callbacks
- **Event Callbacks**:
  - Camera movement tracking with onCameraMove
  - Camera idle detection with onCameraIdle
  - Real-time position and zoom updates
- **Platform Interface Compliance**: Full implementation of platform_maps_flutter_platform_interface
- **Auto-registration**: Automatic plugin registration for macOS platform
- **Example App**: Complete demonstration app showing all features
- **Federated Architecture**: Seamless integration with platform_maps_flutter ecosystem

### Technical Features
- Efficient differential updates for map overlays (markers, polylines, polygons, circles)
- Memory-efficient overlay management with proper cleanup
- Zoom-to-span conversion algorithms for MapKit compatibility
- Comprehensive camera position tracking and synchronization
- Robust error handling and fallback behaviors

### Platform Compatibility
- macOS 10.11 or later
- Flutter 3.22.0 or later  
- Dart SDK 3.3.0 or later

### Dependencies
- `platform_maps_flutter_platform_interface: ^1.0.0-beta.1`
- `flutter_macos_maps: ^0.1.0`

### Known Limitations
- Snapshot functionality not yet implemented (takeSnapshot returns null)
- Info window show/hide programmatic control not fully implemented
- getVisibleRegion throws UnimplementedError (pending flutter_macos_maps support)

---

## [0.0.1] - Initial Development

### Added
- Project scaffolding and initial structure setup
- Basic plugin configuration and platform registration
