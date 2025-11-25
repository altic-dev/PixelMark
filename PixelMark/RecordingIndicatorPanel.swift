//
//  RecordingIndicatorPanel.swift
//  PixelMark
//
//  Created by PixelMark on 11/25/25.
//

import SwiftUI
import AppKit
import Combine

/// A floating panel that shows recording status and controls.
/// Works across all Spaces/desktops and stays visible during recording.
class RecordingIndicatorPanel: NSPanel {
    private var recordingManager: RecordingManager
    private var cancellables = Set<AnyCancellable>()
    
    init(recordingManager: RecordingManager, onStop: @escaping () -> Void, onPause: @escaping () -> Void, onResume: @escaping () -> Void) {
        self.recordingManager = recordingManager
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 44),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Critical settings for multi-Space support
        self.isFloatingPanel = true
        self.level = .statusBar  // Higher than .floating to stay above most windows
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.hidesOnDeactivate = false  // CRITICAL: Don't hide when app deactivates
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isOpaque = false
        self.animationBehavior = .utilityWindow
        
        // Position at top-right of main screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let panelWidth: CGFloat = 200
            let panelHeight: CGFloat = 44
            
            let x = screenRect.maxX - panelWidth - 20
            let y = screenRect.maxY - panelHeight - 10
            
            self.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }
        
        let contentView = RecordingIndicatorView(
            recordingManager: recordingManager,
            onStop: onStop,
            onPause: onPause,
            onResume: onResume
        )
        
        self.contentView = NSHostingView(rootView: contentView)
    }
    
    // Allow the panel to be key when needed but doesn't require it
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

/// The SwiftUI view for the recording indicator
struct RecordingIndicatorView: View {
    @ObservedObject var recordingManager: RecordingManager
    var onStop: () -> Void
    var onPause: () -> Void
    var onResume: () -> Void
    
    @State private var isHovering = false
    @State private var pulseAnimation = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Recording indicator dot with pulse animation
            Circle()
                .fill(recordingManager.isPaused ? Color.orange : Color.red)
                .frame(width: 10, height: 10)
                .scaleEffect(pulseAnimation && !recordingManager.isPaused ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                .onAppear {
                    pulseAnimation = true
                }
            
            // Duration
            Text(formatDuration(recordingManager.recordingDuration))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
            
            Spacer()
            
            // Pause/Resume button
            Button {
                if recordingManager.isPaused {
                    onResume()
                } else {
                    onPause()
                }
            } label: {
                Image(systemName: recordingManager.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Stop button
            Button {
                onStop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

