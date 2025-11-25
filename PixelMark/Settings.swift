//
//  Settings.swift
//  PixelMark
//
//  Created by PixelMark on 11/22/25.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

class AppSettings: ObservableObject {
    // MARK: - Singleton
    static let shared = AppSettings()
    
    // MARK: - Published Properties
    @Published var outputDirectory: URL {
        didSet {
            saveOutputDirectory()
        }
    }
    
    @Published var videoQuality: VideoQuality {
        didSet {
            UserDefaults.standard.set(videoQuality.rawValue, forKey: "videoQuality")
        }
    }
    
    @Published var videoCodec: VideoCodec {
        didSet {
            UserDefaults.standard.set(videoCodec.rawValue, forKey: "videoCodec")
        }
    }
    
    @Published var captureAudio: Bool {
        didSet {
            UserDefaults.standard.set(captureAudio, forKey: "captureAudio")
        }
    }
    
    @Published var captureSystemAudio: Bool {
        didSet {
            UserDefaults.standard.set(captureSystemAudio, forKey: "captureSystemAudio")
        }
    }
    
    @Published var captureMicrophone: Bool {
        didSet {
            UserDefaults.standard.set(captureMicrophone, forKey: "captureMicrophone")
        }
    }
    
    @Published var frameRate: Int {
        didSet {
            UserDefaults.standard.set(frameRate, forKey: "frameRate")
        }
    }
    
    @Published var showCursor: Bool {
        didSet {
            UserDefaults.standard.set(showCursor, forKey: "showCursor")
        }
    }
    
    @Published var keyboardShortcut: String {
        didSet {
            UserDefaults.standard.set(keyboardShortcut, forKey: "keyboardShortcut")
        }
    }
    
    @Published var hideWindowOnRecording: Bool {
        didSet {
            UserDefaults.standard.set(hideWindowOnRecording, forKey: "hideWindowOnRecording")
        }
    }
    
    @Published var appTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(appTheme.rawValue, forKey: "appTheme")
            Task { @MainActor in
                ThemeManager.shared.setTheme(appTheme)
            }
        }
    }
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let outputDirectoryBookmark = "outputDirectoryBookmark"
        static let outputDirectoryPath = "outputDirectoryPath"
        static let videoQuality = "videoQuality"
        static let videoCodec = "videoCodec"
        static let captureAudio = "captureAudio"
        static let captureSystemAudio = "captureSystemAudio"
        static let captureMicrophone = "captureMicrophone"
        static let frameRate = "frameRate"
        static let showCursor = "showCursor"
        static let keyboardShortcut = "keyboardShortcut"
        static let hideWindowOnRecording = "hideWindowOnRecording"
        static let appTheme = "appTheme"
    }
    
    // MARK: - Initialization
    private init() {
        // Load output directory (default to Downloads)
        if let savedPath = UserDefaults.standard.string(forKey: Keys.outputDirectoryPath) {
            // Use file URL, not string URL
            self.outputDirectory = URL(fileURLWithPath: savedPath)
            print("📂 Loaded saved path: \(savedPath)")
        } else {
            // Use actual user Downloads, not container Downloads
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let actualDownloads = homeDir.appendingPathComponent("Downloads")
            self.outputDirectory = actualDownloads
            print("📂 Using actual Downloads: \(actualDownloads.path)")
            
            // Save it so it persists
            UserDefaults.standard.set(actualDownloads.path, forKey: Keys.outputDirectoryPath)
        }
        
        // Load video quality (default: high)
        let qualityRaw = UserDefaults.standard.string(forKey: Keys.videoQuality) ?? VideoQuality.high.rawValue
        self.videoQuality = VideoQuality(rawValue: qualityRaw) ?? .high
        
        // Load video codec (default: hevc)
        let codecRaw = UserDefaults.standard.string(forKey: Keys.videoCodec) ?? VideoCodec.hevc.rawValue
        self.videoCodec = VideoCodec(rawValue: codecRaw) ?? .hevc
        
        // Load audio settings (defaults: capture audio, system audio on, microphone off)
        self.captureAudio = UserDefaults.standard.object(forKey: Keys.captureAudio) as? Bool ?? true
        self.captureSystemAudio = UserDefaults.standard.object(forKey: Keys.captureSystemAudio) as? Bool ?? true
        self.captureMicrophone = UserDefaults.standard.object(forKey: Keys.captureMicrophone) as? Bool ?? false
        
        // Load frame rate (default: 30)
        self.frameRate = UserDefaults.standard.object(forKey: Keys.frameRate) as? Int ?? 30
        
        // Load cursor visibility (default: true)
        self.showCursor = UserDefaults.standard.object(forKey: Keys.showCursor) as? Bool ?? true
        
        // Load keyboard shortcut (default: "⌘⇧5")
        self.keyboardShortcut = UserDefaults.standard.string(forKey: Keys.keyboardShortcut) ?? "⌘⇧5"
        
        // Load hide window setting (default: true)
        self.hideWindowOnRecording = UserDefaults.standard.object(forKey: Keys.hideWindowOnRecording) as? Bool ?? true
        
        // Load theme (default: system)
        let themeRaw = UserDefaults.standard.string(forKey: Keys.appTheme) ?? AppTheme.system.rawValue
        self.appTheme = AppTheme(rawValue: themeRaw) ?? .system
        ThemeManager.shared.setTheme(self.appTheme)
    }
    
    // MARK: - Public Methods
    
    /// Update the output directory
    func updateOutputDirectory(_ url: URL) {
        outputDirectory = url
        saveOutputDirectory()
    }
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        outputDirectory = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        
        videoQuality = .high
        videoCodec = .hevc
        captureAudio = true
        captureSystemAudio = true
        captureMicrophone = false
        frameRate = 30
        showCursor = true
        keyboardShortcut = "⌘⇧5"
        appTheme = .system
        ThemeManager.shared.setTheme(.system)
    }
    
    /// Get video settings based on quality preference
    func getVideoSettings(width: Int, height: Int) -> [String: Any] {
        let bitrate: Int
        
        switch videoQuality {
        case .low:
            bitrate = 2_000_000
        case .medium:
            bitrate = 4_000_000
        case .high:
            bitrate = 8_000_000
        case .ultra:
            bitrate = 12_000_000
        }
        
        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
    }
    
    // MARK: - Private Methods
    
    private func saveOutputDirectory() {
        // Save the file path as string
        UserDefaults.standard.set(outputDirectory.path, forKey: Keys.outputDirectoryPath)
    }
}

// MARK: - Video Codec Enum
enum VideoCodec: String, CaseIterable, Identifiable {
    case hevc = "HEVC (H.265)"
    case h264 = "H.264"
    case proRes422 = "ProRes 422"
    case proRes4444 = "ProRes 4444"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .hevc:
            return "High efficiency, standard quality"
        case .h264:
            return "Most compatible"
        case .proRes422:
            return "Professional editing quality"
        case .proRes4444:
            return "Lossless quality, alpha support"
        }
    }
}

// MARK: - Video Quality Enum
enum VideoQuality: String, CaseIterable, Identifiable {
    case low = "Low (720p)"
    case medium = "Medium (1080p)"
    case high = "High (1080p)"
    case ultra = "Ultra (4K)"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var description: String {
        switch self {
        case .low:
            return "720p, 2 Mbps - Smaller file size"
        case .medium:
            return "1080p, 4 Mbps - Balanced quality"
        case .high:
            return "1080p, 8 Mbps - High quality"
        case .ultra:
            return "4K, 12 Mbps - Maximum quality"
        }
    }
}

// MARK: - Frame Rate Options
extension AppSettings {
    static let availableFrameRates = [15, 24, 30, 60]
    
    func frameRateDescription(_ rate: Int) -> String {
        switch rate {
        case 15:
            return "15 FPS - Power saving"
        case 24:
            return "24 FPS - Cinematic"
        case 30:
            return "30 FPS - Standard"
        case 60:
            return "60 FPS - Smooth motion"
        default:
            return "\(rate) FPS"
        }
    }
}

