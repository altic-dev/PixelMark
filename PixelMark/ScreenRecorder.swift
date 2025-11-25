//
//  ScreenRecorder.swift
//  PixelMark
//
//  Created by PixelMark on 11/22/25.
//

import Foundation
import AppKit
import ScreenCaptureKit
import AVFoundation
import VideoToolbox
import Combine

@MainActor
class ScreenRecorder: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var availableDisplays: [SCDisplay] = []
    @Published var availableWindows: [SCWindow] = []
    @Published var selectedDisplay: SCDisplay?
    @Published var selectedWindow: SCWindow?
    @Published var recordingType: RecordingType = .screen
    @Published var errorMessage: String?
    @Published var streamError: Error?  // Track stream errors for UI notification
    
    // MARK: - Public Properties
    public private(set) var lastRecordingURL: URL?
    public private(set) var recordingWidth: Int = 0
    public private(set) var recordingHeight: Int = 0
    public private(set) var recordingFrame: CGRect = .zero
    
    enum RecordingType {
        case screen
        case window
    }
    
    // MARK: - Private Properties
    private var streamOutput: CaptureOutput?
    private var stream: SCStream?
    private var videoWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?
    
    // MARK: - Configuration
    private func videoSettings(width: Int, height: Int) -> [String: Any] {
        let codec: AVVideoCodecType
        switch AppSettings.shared.videoCodec {
        case .hevc: codec = .hevc
        case .h264: codec = .h264
        case .proRes422: codec = .proRes422
        case .proRes4444: codec = .proRes4444
        }
        
        var compressionProps: [String: Any] = [
            AVVideoExpectedSourceFrameRateKey: 60,
            AVVideoMaxKeyFrameIntervalKey: 60,
            AVVideoAllowFrameReorderingKey: false
        ]
        
        // Only apply bitrate/profile for H.264/HEVC (ProRes is constant quality)
        if codec == .hevc || codec == .h264 {
            compressionProps[AVVideoAverageBitRateKey] = 50_000_000
            if codec == .hevc {
                 compressionProps[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main_AutoLevel
            } else {
                 compressionProps[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
            }
        }
        
        return [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: compressionProps
        ]
    }
    
    /// Get the backing scale factor for a display
    private func getScaleFactor(for displayID: CGDirectDisplayID?) -> Double {
        guard let displayID = displayID else { return 2.0 }
        let factor = NSScreen.screens.first {
            guard let screenNumber = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return screenNumber.uint32Value == displayID
        }?.backingScaleFactor ?? 2.0
        return Double(factor)
    }
    
    /// Convert a rectangle reported in Quartz coordinate space (origin at top-left of the main display)
    /// to Cocoa's coordinate space (origin at bottom-left of the main display).
    private func convertQuartzFrameToCocoa(_ rect: CGRect) -> CGRect {
        guard let referenceScreen = NSScreen.main ?? NSScreen.screens.first else {
            return rect
        }
        
        let referenceHeight = referenceScreen.frame.height
        let convertedY = referenceHeight - (rect.origin.y + rect.height)
        return CGRect(x: rect.origin.x, y: convertedY, width: rect.width, height: rect.height)
    }
    
    /// Determine which screen contains the provided rectangle (in Cocoa coordinates).
    private func screenContaining(rect: CGRect) -> NSScreen? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Check if screen recording permission is granted
    func checkPermission() async -> Bool {
        do {
            // Try to get shareable content - this will prompt for permission if needed
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
    }
    
    /// Refresh available displays and windows
    func refreshAvailableContent() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            
            // Update available displays
            availableDisplays = content.displays
            
            // Filter windows to only show relevant ones
            availableWindows = content.windows.filter { window in
                // Must be on screen
                guard window.isOnScreen else { return false }
                
                // Must be on normal window layer (0)
                guard window.windowLayer == 0 else { return false }
                
                // Exclude our own app and development tools
                if let appName = window.owningApplication?.applicationName {
                    if appName == "PixelMark" || appName == "Windsurf" || appName == "Comet" {
                        return false
                    }
                }
                
                // Exclude small windows (likely tooltips, menu bar items, etc)
                if window.frame.width < 50 || window.frame.height < 50 {
                    return false
                }
                
                // Must have a title or belong to a known app
                if (window.title ?? "").isEmpty && (window.owningApplication?.applicationName ?? "").isEmpty {
                    return false
                }
                
                return true
            }
            
            // Select the main display by default
            if selectedDisplay == nil, let mainDisplay = availableDisplays.first {
                selectedDisplay = mainDisplay
            }
        } catch {
            errorMessage = "Failed to get available content: \(error.localizedDescription)"
            print("Error refreshing content: \(error)")
        }
    }
    
    /// Start recording the selected display
    func startRecording(outputDirectory: URL, includeAudio: Bool = true) async throws {
        let width: Int
        let height: Int
        let filter: SCContentFilter
        let scaleFactor: Double
        let frame: CGRect
        
        if recordingType == .screen {
            guard let display = selectedDisplay else {
                throw RecordingError.noDisplaySelected
            }
            scaleFactor = getScaleFactor(for: display.displayID)
            // Calculate physical pixels
            width = Int(Double(display.width) * scaleFactor)
            height = Int(Double(display.height) * scaleFactor)
            
            // Get the display frame
            if let screen = NSScreen.screens.first(where: {
                guard let screenNumber = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
                return screenNumber.uint32Value == display.displayID
            }) {
                frame = screen.frame
            } else {
                frame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: display.width, height: display.height)
            }
            
            filter = SCContentFilter(display: display, excludingWindows: [])
        } else {
            guard let window = selectedWindow else {
                throw RecordingError.noWindowSelected
            }
            
            // Convert Quartz (top-left) coordinates to Cocoa (bottom-left) for cursor mapping
            let cocoaFrame = convertQuartzFrameToCocoa(window.frame)
            let windowScreen = screenContaining(rect: cocoaFrame) ?? NSScreen.main ?? NSScreen.screens.first
            let backingScale = windowScreen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
            
            scaleFactor = Double(backingScale)
            width = Int(Double(cocoaFrame.width) * scaleFactor)
            height = Int(Double(cocoaFrame.height) * scaleFactor)
            frame = cocoaFrame
            filter = SCContentFilter(desktopIndependentWindow: window)
        }
        
        // Ensure even dimensions and minimum size
        let alignedWidth = width & ~1
        let alignedHeight = height & ~1
        
        if alignedWidth <= 0 || alignedHeight <= 0 {
            throw RecordingError.streamSetupFailed
        }
        
        guard !isRecording else {
            throw RecordingError.alreadyRecording
        }
        
        // Create output file URL
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "PixelMark-\(timestamp).mp4"
        let newOutputURL = outputDirectory.appendingPathComponent(filename)
        lastRecordingURL = newOutputURL
        
        // Setup AVAssetWriter
        videoWriter = try AVAssetWriter(outputURL: newOutputURL, fileType: .mp4)
        
        // Configure video input with display dimensions
        videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoSettings(width: alignedWidth, height: alignedHeight)
        )
        videoInput?.expectsMediaDataInRealTime = true
        
        // Store recording dimensions and frame for cursor coordinate mapping
        recordingWidth = alignedWidth
        recordingHeight = alignedHeight
        recordingFrame = frame
        
        print("🎥 Recording Configuration:")
        print("   - Logical Size: \(width)x\(height)")
        print("   - Scale Factor: \(scaleFactor)")
        print("   - Output Size:  \(alignedWidth)x\(alignedHeight)")
        print("   - Bitrate:      50 Mbps")
        print("   - FPS:          60")
        
        // Add pixel buffer adaptor for better format handling
        // Reverted to BGRA (4:4:4) for best text clarity/sharpness
        if let videoInput = videoInput {
            let bufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: alignedWidth,
                kCVPixelBufferHeightKey as String: alignedHeight,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput,
                sourcePixelBufferAttributes: bufferAttributes
            )
            videoWriter?.add(videoInput)
        }
        
        // Configure audio input if needed
        if includeAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000, // Increased to 48kHz
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 192_000 // Increased to 192kbps
            ]
            
            audioInput = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: audioSettings
            )
            audioInput?.expectsMediaDataInRealTime = true
            
            if let audioInput = audioInput {
                videoWriter?.add(audioInput)
            }
        }
        
        // Create stream configuration
        let streamConfig = SCStreamConfiguration()
        streamConfig.width = alignedWidth
        streamConfig.height = alignedHeight
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS
        streamConfig.pixelFormat = kCVPixelFormatType_32BGRA // BGRA for sharp text
        streamConfig.queueDepth = 6
        streamConfig.showsCursor = false
        streamConfig.capturesAudio = includeAudio
        streamConfig.colorSpaceName = CGColorSpace.sRGB
        
        // Create stream with delegate for error handling
        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        
        // Create and add stream output
        streamOutput = CaptureOutput(
            videoInput: videoInput,
            audioInput: audioInput,
            pixelBufferAdaptor: pixelBufferAdaptor,
            assetWriter: videoWriter
        )
        
        if let stream = stream, let streamOutput = streamOutput {
            // Prepare writer before capture begins so the first sample can start the session
            videoWriter?.startWriting()
            
            try stream.addStreamOutput(
                streamOutput,
                type: .screen,
                sampleHandlerQueue: DispatchQueue(label: "com.pixelmark.capture")
            )
            
            if includeAudio {
                try stream.addStreamOutput(
                    streamOutput,
                    type: .audio,
                    sampleHandlerQueue: DispatchQueue(label: "com.pixelmark.audio")
                )
            }
            
            // Start the stream
            try await stream.startCapture()
            
            startTime = nil
            
            isRecording = true
            errorMessage = nil
        }
    }
    
    /// Stop recording
    func stopRecording() async throws {
        guard isRecording else {
            throw RecordingError.notRecording
        }
        
        isRecording = false
        isPaused = false
        
        // Stop the stream
        if let stream = stream {
            try await stream.stopCapture()
        }
        
        // Finish writing
        await finishWriting()
        
        // Cleanup
        stream = nil
        streamOutput = nil
        videoWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        startTime = nil
    }
    
    /// Pause recording
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        isPaused = true
    }
    
    /// Resume recording
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        isPaused = false
    }
    
    // MARK: - Private Methods
    
    private func finishWriting() async {
        guard let videoWriter = videoWriter else { return }
        
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        await videoWriter.finishWriting()
        
        if videoWriter.status == .completed {
            print("Recording saved to: \(lastRecordingURL?.path ?? "unknown")")
        } else if let error = videoWriter.error {
            errorMessage = "Failed to save recording: \(error.localizedDescription)"
            print("Error writing video: \(error)")
        }
    }
    
    // MARK: - Error Types
    enum RecordingError: LocalizedError {
        case noDisplaySelected
        case noWindowSelected
        case alreadyRecording
        case notRecording
        case invalidOutputPath
        case streamSetupFailed
        case streamInterrupted(String)
        
        var errorDescription: String? {
            switch self {
            case .noDisplaySelected:
                return "No display selected for recording"
            case .noWindowSelected:
                return "No window selected for recording"
            case .alreadyRecording:
                return "Recording is already in progress"
            case .notRecording:
                return "No active recording to stop"
            case .invalidOutputPath:
                return "Invalid output file path"
            case .streamSetupFailed:
                return "Failed to setup screen capture stream"
            case .streamInterrupted(let reason):
                return "Recording interrupted: \(reason)"
            }
        }
    }
}

// MARK: - SCStreamDelegate
extension ScreenRecorder: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            print("⚠️ SCStream stopped with error: \(error.localizedDescription)")
            
            self.streamError = error
            self.errorMessage = "Recording was interrupted: \(error.localizedDescription)"
            
            // Post notification so UI can respond
            NotificationCenter.default.post(
                name: NSNotification.Name("RecordingStreamError"),
                object: nil,
                userInfo: ["error": error]
            )
            
            // If still recording, try to save what we have
            if self.isRecording {
                self.isRecording = false
                self.isPaused = false
                await self.finishWriting()
                
                // Cleanup
                self.stream = nil
                self.streamOutput = nil
                self.videoWriter = nil
                self.videoInput = nil
                self.audioInput = nil
                self.pixelBufferAdaptor = nil
                self.startTime = nil
                
                // Notify UI to update
                NotificationCenter.default.post(name: NSNotification.Name("RecordingStateChanged"), object: nil)
            }
        }
    }
}

