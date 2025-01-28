import Cocoa
import FlutterMacOS
import AVFoundation
import VideoToolbox

public class VideoToolboxPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "video_toolbox", binaryMessenger: registrar.messenger)
        let instance = VideoToolboxPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "compressVideo":
            guard let args = call.arguments as? [String: Any],
                  let inputPath = args["inputPath"] as? String,
                  let outputPath = args["outputPath"] as? String,
                  let destBitRate = args["destBitRate"] as? Int,
                  let destWidth = args["destWidth"] as? Int,
                  let destHeight = args["destHeight"] as? Int else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for compressVideo", details: nil))
                return
            }
            
            let options = Options(
                destWidth: destWidth,
                destHeight: destHeight,
                pixelFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                codec: kCMVideoCodecType_H264,
                destBitRate: destBitRate,
                maxKeyFrameInterval: 30,
                maxKeyFrameIntervalDuration: 2.0,
                savePower: false
            )
            
            do {
                try compressVideo(inputPath: inputPath, outputPath: outputPath, options: options)
                result(nil) // Success
            } catch {
                result(FlutterError(code: "COMPRESSION_FAILED", message: error.localizedDescription, details: nil))
            }
        case "getPlatformVersion":
            result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

struct Options {
    var destWidth: Int
    var destHeight: Int
    var pixelFormat: OSType
    var codec: CMVideoCodecType
    var destBitRate: Int
    var maxKeyFrameInterval: Int
    var maxKeyFrameIntervalDuration: Float
    var savePower: Bool
}

func compressVideo(inputPath: String, outputPath: String, options: Options) throws {
    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)
    
    // Create AVAsset for the input file
    let asset = AVAsset(url: inputURL)
    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
        throw NSError(domain: "VideoToolboxPlugin", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track found in file: \(inputPath)"])
    }
    
    // Create AVAssetReader
    let reader = try AVAssetReader(asset: asset)
    let readerOutputSettings: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: options.pixelFormat
    ]
    let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)
    reader.add(readerOutput)
    
    // Create AVAssetWriter
    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: options.destWidth,
        AVVideoHeightKey: options.destHeight,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: options.destBitRate,
            AVVideoMaxKeyFrameIntervalKey: options.maxKeyFrameInterval
        ]
    ])
    writer.add(writerInput)
    
    // Start reading and writing
    reader.startReading()
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    
    // Perform compression
    let mediaQueue = DispatchQueue(label: "mediaQueue")
    let group = DispatchGroup()
    group.enter()
    
    writerInput.requestMediaDataWhenReady(on: mediaQueue) {
        while writerInput.isReadyForMoreMediaData {
            if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                // Append the sample buffer to the writer
                writerInput.append(sampleBuffer)
            } else {
                writerInput.markAsFinished()
                group.leave()
                break
            }
        }
    }
    
    group.wait()
    
    reader.cancelReading()
    writer.finishWriting {
        if writer.status == .failed {
            NSLog("Failed to write compressed video: \(writer.error?.localizedDescription ?? "Unknown error")")
        } else {
            NSLog("Video compression completed successfully.")
        }
    }
}

/// Configures a compression session for offline transcoding.
/// - Parameters:
///   - session: A compression session.
///   - options: The configuration options.
///   - expectedFrameRate: The expected frame rate of the video source.
private func configureVTCompressionSession(session: VTCompressionSession, options: Options, expectedFrameRate: Float) {
    // Different encoder implementations may support different property sets, so
    // the app needs to determine the implications of a failed property setting
    // on a case-by-case basis for the encoder. If the property is essential for
    // the use case and its setting fails, the app terminates. Otherwise, the
    // encoder ignores the failed setting and uses a default value to proceed
    // with encoding.
    
    
    var err: OSStatus = noErr
    
    // Specify the profile and level for the encoded bitstream.
    if options.codec == kCMVideoCodecType_H264 {
        err = VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel)
    } else if options.codec == kCMVideoCodecType_HEVC {
        err = VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_HEVC_Main_AutoLevel)
    }
    if noErr != err {
        NSLog("Warning: VTSessionSetProperty(kVTCompressionPropertyKey_ProfileLevel) failed (\(err))")
    }
    
    
    // Indicate that the compression session isn't in real time.
    err = VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanFalse)
    if noErr != err {
        NSLog("Warning: VTSessionSetProperty(kVTCompressionPropertyKey_RealTime) failed (\(err))")
    }
    
    
    // Specify the long-term desired average bit rate in bits per second. It's a
    // soft limit, so the encoder may overshoot or undershoot, and the average
    // bit rate of the output video may be over or under the target.
    err = VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: options.destBitRate as CFNumber)
    if noErr != err {
        NSLog("Warning: VTSessionSetProperty(kVTCompressionPropertyKey_AverageBitRate) failed (\(err))")
    }
    
    
    // Enable temporal compression.
    err = VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowTemporalCompression, value: kCFBooleanTrue)
    if noErr != err {
        NSLog("Warning: VTSessionSetProperty(kVTCompressionPropertyKey_AllowTemporalCompression) failed (\(err))")
    }
    
    
    // Enable frame reordering.
    err = VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanTrue)
    if noErr != err {
        NSLog("Warning: VTSessionSetProperty(kVTCompressionPropertyKey_AllowFrameReordering) failed (\(err))")
    }
    
    
    // Specify the maximum interval between key frames, also known as the key
    // frame rate. Set this in conjunction with
    // `kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration` to enforce both
    // limits, which requires a keyframe every X frames or every Y seconds,
    // whichever comes first.
    err = VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: options.maxKeyFrameInterval as CFNumber)
    if noErr != err {
        NSLog("Warning: VTSessionSetProperty(kVTCompressionPropertyKey_MaxKeyFrameInterval) failed (\(err))")
    }
    
    
    // Specify the maximum duration from one key frame to the next in seconds.
    err = VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration,
                               value: options.maxKeyFrameIntervalDuration as CFNumber)
    if noErr != err {
        NSLog("Warning: VTSessionSetProperty(kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration) failed (\(err))")
    }
    
    
    // Hint to the video encoder to maximize power efficiency during encoding. Set
    // this to `kCFBooleanFalse` for offline transcoding that a user initiates
    // and waits for the results. Set this to `kCFBooleanTrue` for the offline
    // transcoding in the background when the user isn't aware.
    err = VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaximizePowerEfficiency, value: options.savePower as CFBoolean)
    if noErr != err {
        NSLog("Warning: VTSessionSetProperty(kVTCompressionPropertyKey_MaximizePowerEfficiency) failed (\(err))")
    }
}
