import 'video_toolbox_platform_interface.dart';

class VideoToolbox {
  Future<String?> getPlatformVersion() {
    return VideoToolboxPlatform.instance.getPlatformVersion();
  }

  Future<void> compressVideo({
    required String inputPath,
    required String outputPath,
    required int destBitRate,
  }) {
    return VideoToolboxPlatform.instance.compressVideo(
      inputPath: inputPath,
      outputPath: outputPath,
      destBitRate: destBitRate,
    );
  }
}
