import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'video_toolbox_platform_interface.dart';

/// An implementation of [VideoToolboxPlatform] that uses method channels.
class MethodChannelVideoToolbox extends VideoToolboxPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('video_toolbox');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
