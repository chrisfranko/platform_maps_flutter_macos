import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_maps_flutter_macos/platform_maps_flutter_macos.dart';
import 'package:platform_maps_flutter_platform_interface/platform_maps_flutter_platform_interface.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformMapsFlutterMacOS Integration Tests', () {
    testWidgets('plugin registers correctly', (WidgetTester tester) async {
      // Only run on macOS
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        PlatformMapsFlutterMacOS.registerWith();
        
        // Verify the platform instance is correctly set
        expect(PlatformMapsPlatform.instance, isA<PlatformMapsFlutterMacOS>());
        
        // Verify we can create the required components
        final platform = PlatformMapsPlatform.instance!;
        expect(platform.createBitmapDescriptor(), isNotNull);
        expect(platform.createPlatformCameraUpdate(), isNotNull);
      }
    });
  });
}
