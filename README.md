# video_toolbox

A Dart package that provides video compression using the Video Toolbox API.

# Usage

## Import the package

``` Dart
import 'package:video_toolbox/video_toolbox.dart';
```

## Compress a video

``` Dart
void main() async {
  final videoToolbox = VideoToolbox();

  await videoToolbox.compressVideo(
    inputPath: "/path/to/input/video.mp4",
    outputPath: "/path/to/output/video.mp4",
    destBitRate: 1000000, // in bits per second
    destWidth: 1280,
    destHeight: 720,
  );

  print("Video compression completed.");
}
```
