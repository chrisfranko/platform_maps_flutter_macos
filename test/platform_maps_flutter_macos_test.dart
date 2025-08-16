import 'package:flutter_test/flutter_test.dart';
import 'package:platform_maps_flutter_macos/platform_maps_flutter_macos.dart';
import 'package:platform_maps_flutter_macos/platform_maps_flutter_macos_platform_interface.dart';
import 'package:platform_maps_flutter_macos/platform_maps_flutter_macos_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPlatformMapsFlutterMacosPlatform
    with MockPlatformInterfaceMixin
    implements PlatformMapsFlutterMacosPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final PlatformMapsFlutterMacosPlatform initialPlatform = PlatformMapsFlutterMacosPlatform.instance;

  test('$MethodChannelPlatformMapsFlutterMacos is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelPlatformMapsFlutterMacos>());
  });

  test('getPlatformVersion', () async {
    PlatformMapsFlutterMacos platformMapsFlutterMacosPlugin = PlatformMapsFlutterMacos();
    MockPlatformMapsFlutterMacosPlatform fakePlatform = MockPlatformMapsFlutterMacosPlatform();
    PlatformMapsFlutterMacosPlatform.instance = fakePlatform;

    expect(await platformMapsFlutterMacosPlugin.getPlatformVersion(), '42');
  });
}
