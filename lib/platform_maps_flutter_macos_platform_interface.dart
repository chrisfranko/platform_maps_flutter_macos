import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'platform_maps_flutter_macos_method_channel.dart';

abstract class PlatformMapsFlutterMacosPlatform extends PlatformInterface {
  /// Constructs a PlatformMapsFlutterMacosPlatform.
  PlatformMapsFlutterMacosPlatform() : super(token: _token);

  static final Object _token = Object();

  static PlatformMapsFlutterMacosPlatform _instance = MethodChannelPlatformMapsFlutterMacos();

  /// The default instance of [PlatformMapsFlutterMacosPlatform] to use.
  ///
  /// Defaults to [MethodChannelPlatformMapsFlutterMacos].
  static PlatformMapsFlutterMacosPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PlatformMapsFlutterMacosPlatform] when
  /// they register themselves.
  static set instance(PlatformMapsFlutterMacosPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
