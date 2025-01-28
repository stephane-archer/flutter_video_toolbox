import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'video_toolbox_platform_interface.dart';

/// An implementation of [VideoToolboxPlatform] that uses method channels.
class MethodChannelVideoToolbox extends VideoToolboxPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('video_toolbox');

  @override
  Future<void> compressVideo({
    required String inputPath,
    required String outputPath,
    required int destBitRate,
    required int destWidth,
    required int destHeight,
  }) async {
    try {
      final options = {
        'inputPath': inputPath,
        'outputPath': outputPath,
        'destBitRate': destBitRate,
        'destWidth': destWidth,
        'destHeight': destHeight,
      };
      await methodChannel.invokeMethod('compressVideo', options);
    } on PlatformException catch (e) {
      throw 'Failed to compress video: ${e.message}';
    }
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
