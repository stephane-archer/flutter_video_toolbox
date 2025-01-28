import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'video_toolbox_method_channel.dart';

abstract class VideoToolboxPlatform extends PlatformInterface {
  static final Object _token = Object();

  static VideoToolboxPlatform _instance = MethodChannelVideoToolbox();

  /// The default instance of [VideoToolboxPlatform] to use.
  ///
  /// Defaults to [MethodChannelVideoToolbox].
  static VideoToolboxPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VideoToolboxPlatform] when
  /// they register themselves.
  static set instance(VideoToolboxPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Constructs a VideoToolboxPlatform.
  VideoToolboxPlatform() : super(token: _token);

  Future<void> compressVideo({
    required String inputPath,
    required String outputPath,
    required int destBitRate,
    required int destWidth,
    required int destHeight,
  }) {
    throw UnimplementedError('compressVideo() has not been implemented.');
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
