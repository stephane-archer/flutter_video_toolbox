import 'package:flutter_test/flutter_test.dart';
import 'package:video_toolbox/video_toolbox.dart';
import 'package:video_toolbox/video_toolbox_platform_interface.dart';
import 'package:video_toolbox/video_toolbox_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVideoToolboxPlatform
    with MockPlatformInterfaceMixin
    implements VideoToolboxPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final VideoToolboxPlatform initialPlatform = VideoToolboxPlatform.instance;

  test('$MethodChannelVideoToolbox is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelVideoToolbox>());
  });

  test('getPlatformVersion', () async {
    VideoToolbox videoToolboxPlugin = VideoToolbox();
    MockVideoToolboxPlatform fakePlatform = MockVideoToolboxPlatform();
    VideoToolboxPlatform.instance = fakePlatform;

    expect(await videoToolboxPlugin.getPlatformVersion(), '42');
  });
}
