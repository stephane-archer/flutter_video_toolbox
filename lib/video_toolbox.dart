
import 'video_toolbox_platform_interface.dart';

class VideoToolbox {
  Future<String?> getPlatformVersion() {
    return VideoToolboxPlatform.instance.getPlatformVersion();
  }
}
