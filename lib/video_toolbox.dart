import 'video_toolbox_platform_interface.dart';

class VideoToolbox implements VideoToolboxPlatform {
  @override
  Future<void> compressVideo({
    required String inputPath,
    required String outputPath,
    required int destBitRate,
    required int destWidth,
    required int destHeight,
    required VideoCodec codec,
  }) {
    return VideoToolboxPlatform.instance.compressVideo(
      inputPath: inputPath,
      outputPath: outputPath,
      destBitRate: destBitRate,
      destWidth: destWidth,
      destHeight: destHeight,
      codec: codec,
    );
  }

  @override
  Future<String?> getPlatformVersion() {
    return VideoToolboxPlatform.instance.getPlatformVersion();
  }
}
