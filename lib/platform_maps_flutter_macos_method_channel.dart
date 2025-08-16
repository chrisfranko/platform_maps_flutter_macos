import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'platform_maps_flutter_macos_platform_interface.dart';

/// An implementation of [PlatformMapsFlutterMacosPlatform] that uses method channels.
class MethodChannelPlatformMapsFlutterMacos extends PlatformMapsFlutterMacosPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('platform_maps_flutter_macos');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
