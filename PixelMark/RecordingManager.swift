//
//  RecordingManager.swift
//  PixelMark
//
//  Created by PixelMark on 11/22/25.
//

import Foundation
import SwiftUI
import Combine
import ScreenCaptureKit

@MainActor
class RecordingManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recentRecordings: [RecordingFile] = []
    @Published var errorMessage: String?
    @Published var screenRecorder = ScreenRecorder()
    @Published var showAccessibilityWarning = false
    
    // MARK: - Dependencies
    private var settings = AppSettings.shared
    
    // MARK: - Private Properties
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    private let windowPicker = WindowPicker()
    private let eventRecorder = EventRecorder()
    
    // MARK: - Initialization
    init() {
        loadRecentRecordings()
        
        // Forward changes from screenRecorder to RecordingManager
        screenRecorder.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Start window picker UI
    func startWindowPicker() {
        windowPicker.startPicking(windows: screenRecorder.availableWindows) { [weak self] window in
            self?.screenRecorder.selectedWindow = window
            self?.screenRecorder.recordingType = .window
        }
    }
    
    /// Start a new recording
    func startRecording() async {
        do {
            // Check accessibility permission (non-blocking)
            let hasAccessibility = eventRecorder.checkAccessibilityPermission()
            if !hasAccessibility {
                // Show warning but continue (recording works without it)
                showAccessibilityWarning = true
            }
            
            // Use temporary directory for initial recording
            let tempDirectory = FileManager.default.temporaryDirectory
            
            print("🎥 Starting recording to temp: \(tempDirectory.path)")
            
            // Start recording
            try await screenRecorder.startRecording(
                outputDirectory: tempDirectory,
                includeAudio: settings.captureAudio
            )
            
            // Update state
            isRecording = true
            isPaused = false
            recordingStartTime = Date()
            recordingDuration = 0
            
            // Start event recording (works with or without permission)
            eventRecorder.startRecording(
                startTime: recordingStartTime!,
                recordingFrame: screenRecorder.recordingFrame,
                videoWidth: screenRecorder.recordingWidth,
                videoHeight: screenRecorder.recordingHeight
            )
            
            // Start timer
            startTimer()
            
            // Notify menu bar to update
            NotificationCenter.default.post(name: NSNotification.Name("RecordingStateChanged"), object: nil)
            
            errorMessage = nil
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print("Recording error: \(error)")
        }
    }
    
    /// Open System Settings to Accessibility pane
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Stop the current recording
    func stopRecording() async {
        do {
            // Stop event recording and get captured events
            let capturedEvents = eventRecorder.stopRecording()
            
            // Capture metadata before stopping (in case state clears)
            let metadata = ProjectMetadata(
                sourceType: screenRecorder.recordingType == .screen ? "screen" : "window",
                windowTitle: screenRecorder.selectedWindow?.title,
                appName: screenRecorder.selectedWindow?.owningApplication?.applicationName,
                displayID: screenRecorder.selectedDisplay?.displayID,
                recordingWidth: screenRecorder.recordingWidth,
                recordingHeight: screenRecorder.recordingHeight,
                events: capturedEvents
            )
            
            try await screenRecorder.stopRecording()
            
            // Convert to Project Bundle
            if let tempURL = screenRecorder.lastRecordingURL {
                _ = try ProjectManager.shared.createProject(
                    from: tempURL,
                    metadata: metadata,
                    in: settings.outputDirectory
                )
            }
            
            // Update state
            isRecording = false
            isPaused = false
            stopTimer()
            
            recordingDuration = 0
            recordingStartTime = nil
            
            // Reload recent recordings after a brief delay to ensure file is written
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            loadRecentRecordings()
            
            // Notify menu bar to update
            NotificationCenter.default.post(name: NSNotification.Name("RecordingStateChanged"), object: nil)
            
            // Automatically open the editor
            await MainActor.run {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title == "PixelMark" || $0.title == "Editor" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            
        } catch {
            errorMessage = "Failed to stop recording: \(error.localizedDescription)"
            print("Stop recording error: \(error)")
        }
    }
    
    /// Pause the current recording
    func pauseRecording() {
        guard isRecording && !isPaused else { return }
        
        screenRecorder.pauseRecording()
        eventRecorder.pauseRecording()
        isPaused = true
        stopTimer()
    }
    
    /// Resume the current recording
    func resumeRecording() {
        guard isRecording && isPaused else { return }
        
        screenRecorder.resumeRecording()
        eventRecorder.resumeRecording()
        isPaused = false
        startTimer()
    }
    
    /// Refresh available displays
    func refreshDisplays() async {
        await screenRecorder.refreshAvailableContent()
    }
    
    /// Load recent recordings from the output directory
    func loadRecentRecordings() {
        let outputDirectory = settings.outputDirectory
        
        print("📁 Loading recordings from: \(outputDirectory.path)")
        
        do {
            let fileManager = FileManager.default
            
            // Check if directory exists
            guard fileManager.fileExists(atPath: outputDirectory.path) else {
                print("❌ Directory doesn't exist: \(outputDirectory.path)")
                recentRecordings = []
                return
            }
            
            let files = try fileManager.contentsOfDirectory(
                at: outputDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            var recordings: [RecordingFile] = []
            
            // 1. Load Legacy MP4s
            let mp4Files = files.filter { $0.pathExtension == "mp4" && $0.lastPathComponent.starts(with: "PixelMark-") }
            for url in mp4Files {
                if let resourceValues = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
                   let creationDate = resourceValues.creationDate,
                   let fileSize = resourceValues.fileSize {
                    recordings.append(RecordingFile(
                        url: url,
                        name: url.lastPathComponent,
                        creationDate: creationDate,
                        fileSize: Int64(fileSize)
                    ))
                }
            }
            
            // 2. Load PixelMark Projects
            let projectFiles = files.filter { $0.pathExtension == Project.fileExtension }
            for url in projectFiles {
                if let recording = RecordingFile(projectURL: url) {
                    recordings.append(recording)
                }
            }
            
            // Sort by date descending
            recentRecordings = recordings
                .sorted { $0.creationDate > $1.creationDate }
                .prefix(20) // Increased limit
                .map { $0 }
            
            print("📊 Final count: \(recentRecordings.count) recordings")
            
        } catch {
            print("❌ Error loading recent recordings: \(error)")
            recentRecordings = []
        }
    }
    
    /// Delete a recording file
    func deleteRecording(_ recording: RecordingFile) {
        do {
            try FileManager.default.removeItem(at: recording.url)
            loadRecentRecordings()
        } catch {
            errorMessage = "Failed to delete recording: \(error.localizedDescription)"
            print("Delete error: \(error)")
        }
    }
    
    /// Open recording in Finder
    func revealInFinder(_ recording: RecordingFile) {
        NSWorkspace.shared.selectFile(recording.url.path, inFileViewerRootedAtPath: "")
    }
    
    /// Open recording in default video player
    func openRecording(_ recording: RecordingFile) {
        NSWorkspace.shared.open(recording.url)
    }
    
    // MARK: - Private Methods
    
    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

