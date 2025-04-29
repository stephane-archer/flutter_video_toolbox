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
                pixelFormat: kCVPixelFormatType_32BGRA,
                codec: kCMVideoCodecType_H264,
                destBitRate: destBitRate,
                maxKeyFrameInterval: 30,
                maxKeyFrameIntervalDuration: 2.0,
                savePower: false
            )
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try compressVideo(inputPath: inputPath, outputPath: outputPath, options: options)
                    DispatchQueue.main.async { result(nil) }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "COMPRESSION_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
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
    try? FileManager.default.removeItem(at: outputURL)

    let asset = AVAsset(url: inputURL)
    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
        throw NSError(domain: "VideoToolboxPlugin", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
    }

    let reader = try AVAssetReader(asset: asset)
    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

    // Video reader
    let videoReaderSettings: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: options.pixelFormat
    ]
    let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderSettings)
    reader.add(videoReaderOutput)

    // Video writer
    let videoWriterSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: options.destWidth,
        AVVideoHeightKey: options.destHeight,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: options.destBitRate,
            AVVideoMaxKeyFrameIntervalKey: options.maxKeyFrameInterval,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]
    ]
    let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoWriterSettings)
    videoWriterInput.expectsMediaDataInRealTime = false
    let videoAdaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: videoWriterInput,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: options.pixelFormat,
            kCVPixelBufferWidthKey as String: options.destWidth,
            kCVPixelBufferHeightKey as String: options.destHeight
        ]
    )
    writer.add(videoWriterInput)

    // Audio reader and writer
    var audioReaderOutput: AVAssetReaderTrackOutput?
    var audioWriterInput: AVAssetWriterInput?

    if let audioTrack = asset.tracks(withMediaType: .audio).first {
        let audioOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM
        ]
        audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioOutputSettings)
        if let audioOutput = audioReaderOutput {
            reader.add(audioOutput)
        }

        let audioWriterSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000
        ]
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioWriterSettings)
        audioWriterInput?.expectsMediaDataInRealTime = false
        if let audioInput = audioWriterInput {
            writer.add(audioInput)
        }
    }

    guard reader.startReading() else {
        throw NSError(domain: "VideoToolboxPlugin", code: -1, userInfo: [NSLocalizedDescriptionKey: "Reader failed: \(reader.error?.localizedDescription ?? "Unknown")"])
    }

    guard writer.startWriting() else {
        throw NSError(domain: "VideoToolboxPlugin", code: -1, userInfo: [NSLocalizedDescriptionKey: "Writer failed: \(writer.error?.localizedDescription ?? "Unknown")"])
    }

    writer.startSession(atSourceTime: .zero)

    let dispatchGroup = DispatchGroup()

    // VIDEO
    dispatchGroup.enter()
    let videoQueue = DispatchQueue(label: "videoQueue")
    videoWriterInput.requestMediaDataWhenReady(on: videoQueue) {
        while videoWriterInput.isReadyForMoreMediaData {
            guard let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() else {
                videoWriterInput.markAsFinished()
                dispatchGroup.leave()
                break
            }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
            let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            _ = videoAdaptor.append(pixelBuffer, withPresentationTime: time)
        }
    }

    // AUDIO
    if let audioOutput = audioReaderOutput, let audioInput = audioWriterInput {
        dispatchGroup.enter()
        let audioQueue = DispatchQueue(label: "audioQueue")
        audioInput.requestMediaDataWhenReady(on: audioQueue) {
            while audioInput.isReadyForMoreMediaData {
                guard let sampleBuffer = audioOutput.copyNextSampleBuffer() else {
                    audioInput.markAsFinished()
                    dispatchGroup.leave()
                    break
                }
                _ = audioInput.append(sampleBuffer)
            }
        }
    }

    dispatchGroup.wait()

    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting {
        if writer.status != .completed {
            print("Writer failed: \(writer.error?.localizedDescription ?? "Unknown")")
        }
        semaphore.signal()
    }
    semaphore.wait()

    if writer.status != .completed {
        throw NSError(domain: "VideoToolboxPlugin", code: -1, userInfo: [NSLocalizedDescriptionKey: writer.error?.localizedDescription ?? "Unknown export error"])
    }
}
