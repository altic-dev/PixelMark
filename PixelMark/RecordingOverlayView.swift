//
//  RecordingOverlayView.swift
//  PixelMark
//
//  Created by PixelMark on 11/22/25.
//

import SwiftUI
import ScreenCaptureKit

struct RecordingOverlayView: View {
    @ObservedObject var recordingManager: RecordingManager
    var onClose: () -> Void
    
    @State private var isHovered = false
    @State private var isCountingDown = false
    @State private var countdownValue = 3
    @StateObject private var themeManager = ThemeManager.shared
    
    private var isRecordDisabled: Bool {
        if recordingManager.screenRecorder.recordingType == .window {
            return recordingManager.screenRecorder.selectedWindow == nil
        }
        return false
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Grab handle area
            Image(systemName: "grip.vertical")
                .foregroundStyle(ThemeColors.textSecondary.opacity(0.5))
                .font(.system(size: 12))
                .padding(.leading, 4)
            
            Divider()
                .frame(height: 20)
                .overlay(ThemeColors.textSecondary.opacity(0.2))
            
            // Recording Mode
            HStack(spacing: 2) {
                ModeButton(
                    title: "Screen",
                    icon: "display",
                    isSelected: recordingManager.screenRecorder.recordingType == .screen,
                    action: { recordingManager.screenRecorder.recordingType = .screen }
                )
                
                ModeButton(
                    title: "Window",
                    icon: "macwindow",
                    isSelected: recordingManager.screenRecorder.recordingType == .window,
                    action: { 
                        recordingManager.screenRecorder.recordingType = .window
                        recordingManager.startWindowPicker()
                    }
                )
            }
            
            Divider()
                .frame(height: 20)
                .overlay(ThemeColors.textSecondary.opacity(0.2))
            
            // Options
            Menu {
                // Source Selection
                if recordingManager.screenRecorder.recordingType == .screen {
                    Section("Display") {
                        ForEach(recordingManager.screenRecorder.availableDisplays, id: \.displayID) { display in
                            Button {
                                recordingManager.screenRecorder.selectedDisplay = display
                            } label: {
                                if display.displayID == recordingManager.screenRecorder.selectedDisplay?.displayID {
                                    Label("Display \(display.displayID)", systemImage: "checkmark")
                                } else {
                                    Text("Display \(display.displayID)")
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                Button("Refresh Sources") {
                    Task { await recordingManager.refreshDisplays() }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Options")
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ThemeColors.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .focusable(false)
            
            Spacer()
            
            // Record Button
            Button {
                if isCountingDown { return }
                
                isCountingDown = true
                countdownValue = 3
                
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    if countdownValue > 1 {
                        countdownValue -= 1
                    } else {
                        timer.invalidate()
                        Task {
                            await recordingManager.startRecording()
                            await MainActor.run {
                                onClose()
                            }
                        }
                    }
                }
            } label: {
                Text(isCountingDown ? "\(countdownValue)" : "Record")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(minWidth: 50) // Ensure width consistency
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isCountingDown ? ThemeColors.sidebarHover : ThemeColors.accent)
                    .foregroundStyle(isCountingDown ? ThemeColors.textPrimary : .black)
                    .cornerRadius(6)
                    .animation(.default, value: isCountingDown)
                    .animation(.default, value: countdownValue)
            }
            .buttonStyle(.plain)
            .disabled(isCountingDown)
            .focusable(false)
            
            // Close Button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(ThemeColors.textSecondary)
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ThemeColors.textSecondary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
        .frame(width: 480)
        .task {
            // refresh displays when overlay appears to ensure we have a default display selected
            await recordingManager.refreshDisplays()
        }
    }
}

struct ModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(width: 50, height: 40)
            .foregroundStyle(isSelected ? ThemeColors.textPrimary : ThemeColors.textSecondary)
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}
