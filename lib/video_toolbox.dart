import 'video_toolbox_platform_interface.dart';

class VideoToolbox {
  Future<void> compressVideo({
    required String inputPath,
    required String outputPath,
    required int destBitRate,
    required int destWidth,
    required int destHeight,
  }) {
    return VideoToolboxPlatform.instance.compressVideo(
      inputPath: inputPath,
      outputPath: outputPath,
      destBitRate: destBitRate,
      destWidth: destWidth,
      destHeight: destHeight,
    );
  }

  Future<String?> getPlatformVersion() {
    return VideoToolboxPlatform.instance.getPlatformVersion();
  }
}
