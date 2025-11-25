//
//  MenuBarController.swift
//  PixelMark
//
//  Created by PixelMark on 11/22/25.
//

import SwiftUI
import AppKit

@MainActor
class MenuBarController {
    private var statusItem: NSStatusItem?
    private var recordingManager: RecordingManager?
    private var overlayPanel: OverlayPanel?
    private var recordingIndicatorPanel: RecordingIndicatorPanel?
    
    func setupMenuBar(recordingManager: RecordingManager) {
        self.recordingManager = recordingManager
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "video.circle", accessibilityDescription: "PixelMark")
            button.image?.isTemplate = true
        }
        
        updateMenu()
        
        // Listen for recording state changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RecordingStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMenu()
                self?.updateRecordingIndicator()
            }
        }
    }
    
    private func updateRecordingIndicator() {
        guard let recordingManager = recordingManager else { return }
        
        if recordingManager.isRecording {
            // Show recording indicator
            if recordingIndicatorPanel == nil {
                recordingIndicatorPanel = RecordingIndicatorPanel(
                    recordingManager: recordingManager,
                    onStop: { [weak self] in
                        Task { @MainActor in
                            await self?.recordingManager?.stopRecording()
                        }
                    },
                    onPause: { [weak self] in
                        self?.recordingManager?.pauseRecording()
                    },
                    onResume: { [weak self] in
                        self?.recordingManager?.resumeRecording()
                    }
                )
            }
            recordingIndicatorPanel?.orderFront(nil)
        } else {
            // Hide recording indicator
            recordingIndicatorPanel?.close()
            recordingIndicatorPanel = nil
        }
    }
    
    func updateMenu() {
        guard let recordingManager = recordingManager else { return }
        
        let menu = NSMenu()
        
        if recordingManager.isRecording {
            // Recording controls
            if recordingManager.isPaused {
                let resumeItem = NSMenuItem(title: "Resume Recording", action: #selector(resumeRecording), keyEquivalent: "")
                resumeItem.target = self
                menu.addItem(resumeItem)
            } else {
                let pauseItem = NSMenuItem(title: "Pause Recording", action: #selector(pauseRecording), keyEquivalent: "")
                pauseItem.target = self
                menu.addItem(pauseItem)
            }
            
            let stopItem = NSMenuItem(title: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "")
            stopItem.target = self
            menu.addItem(stopItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // Show duration
            let durationItem = NSMenuItem(title: formatDuration(recordingManager.recordingDuration), action: nil, keyEquivalent: "")
            durationItem.isEnabled = false
            menu.addItem(durationItem)
        } else {
            // Start recording overlay
            let startItem = NSMenuItem(title: "New Recording...", action: #selector(showRecordingOverlay), keyEquivalent: "n")
            startItem.target = self
            menu.addItem(startItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Show/Hide Window
        let windowItem = NSMenuItem(title: "Show Editor", action: #selector(showWindow), keyEquivalent: "e")
        windowItem.target = self
        menu.addItem(windowItem)
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit PixelMark", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc func showRecordingOverlay() {
        guard let recordingManager = recordingManager else { return }
        
        if overlayPanel == nil {
            overlayPanel = OverlayPanel(recordingManager: recordingManager) { [weak self] in
                self?.overlayPanel?.close()
                self?.overlayPanel = nil
            }
        }
        
        overlayPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func startRecording() {
        Task { @MainActor in
            await recordingManager?.startRecording()
            updateMenu()
        }
    }
    
    @objc private func stopRecording() {
        Task { @MainActor in
            await recordingManager?.stopRecording()
            updateMenu()
        }
    }
    
    @objc private func pauseRecording() {
        recordingManager?.pauseRecording()
        updateMenu()
    }
    
    @objc private func resumeRecording() {
        recordingManager?.resumeRecording()
        updateMenu()
    }
    
    @objc private func showWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func openSettings() {
        showWindow()
        NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "⏱ %02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "⏱ %02d:%02d", minutes, seconds)
        }
    }
}

