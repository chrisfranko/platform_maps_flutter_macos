import 'package:flutter_test/flutter_test.dart';
import 'package:platform_maps_flutter_macos/platform_maps_flutter_macos.dart';
import 'package:platform_maps_flutter_platform_interface/platform_maps_flutter_platform_interface.dart';

void main() {
  group('PlatformMapsFlutterMacOS', () {
    test('registerWith sets the platform instance', () {
      // Register the macOS implementation
      PlatformMapsFlutterMacOS.registerWith();
      
      // Verify the instance is set
      expect(PlatformMapsPlatform.instance, isA<PlatformMapsFlutterMacOS>());
    });

    test('creates bitmap descriptor factory', () {
      final platform = PlatformMapsFlutterMacOS();
      final bitmapDescriptor = platform.createBitmapDescriptor();
      expect(bitmapDescriptor, isNotNull);
    });

    test('creates camera update factory', () {
      final platform = PlatformMapsFlutterMacOS();
      final cameraUpdate = platform.createPlatformCameraUpdate();
      expect(cameraUpdate, isNotNull);
    });

    test('creates platform widget', () {
      final platform = PlatformMapsFlutterMacOS();
      const params = PlatformMapsPlatformWidgetCreationParams(
        initialCameraPosition: CameraPosition(
          target: LatLng(37.7749, -122.4194),
          zoom: 12.0,
        ),
      );
      final widget = platform.createPlatformMapsPlatformWidget(params);
      expect(widget, isNotNull);
    });
  });
}
