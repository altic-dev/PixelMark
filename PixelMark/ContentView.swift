//
//  ContentView.swift
//  PixelMark
//

import SwiftUI
import ScreenCaptureKit
import AVKit

struct ContentView: View {
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var settings = AppSettings.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var isRefreshing = false
    @State private var hasPermission = false
    @State private var isCheckingPermission = true
    @State private var showDebugPanel = false
    @State private var selectedTab = "editor"
    @State private var isSidebarVisible = true
    @State private var hoveredSidebarItem: String?
    @State private var selectedRecording: RecordingFile?
    @Environment(\.colorScheme) var colorScheme
    
    private let sidebarItems: [SidebarItem] = [
        SidebarItem(id: "editor", title: "Editor", icon: "clock"),
        SidebarItem(id: "settings", title: "Settings", icon: "gearshape")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebar
                    .transition(.move(edge: .leading))
            }
            
            ZStack(alignment: .topLeading) {
                Group {
                    switch selectedTab {
                    case "editor":
                        editorView
                    case "settings":
                        settingsDetailView
                    default:
                        editorView
                    }
                }
                .frame(minWidth: 400, minHeight: 350) // Reduced width
                .background(ThemeColors.primaryBackground.ignoresSafeArea())
                .padding(.leading, !isSidebarVisible ? 60 : 0)
                
                if !isSidebarVisible {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isSidebarVisible = true
                        }
                    } label: {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 16))
                            .foregroundStyle(ThemeColors.textSecondary)
                            .padding(10)
                            .background(ThemeColors.secondaryBackground.opacity(0.8))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(ThemeColors.textSecondary.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .padding(.leading, 20)
                    .padding(.top, 32)
                }
            }
        }
        .background(ThemeColors.primaryBackground.ignoresSafeArea())
        .sheet(isPresented: $showDebugPanel) {
            DebugView(recordingManager: recordingManager, settings: settings)
        }
        .task {
            // Setup menu bar (through AppDelegate)
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.menuBarController?.setupMenuBar(recordingManager: recordingManager)
            }
            
            // Check permission on launch
            hasPermission = await recordingManager.screenRecorder.checkPermission()
            isCheckingPermission = false
            
            // Auto-load sources if we have permission
            if hasPermission {
                await recordingManager.refreshDisplays()
            }
            
            // Load recent recordings
            recordingManager.loadRecentRecordings()
        }
        .onAppear {
            // Refresh recordings list when view appears
            recordingManager.loadRecentRecordings()
        }
        .alert("Error", isPresented: Binding(
            get: { recordingManager.errorMessage != nil },
            set: { if !$0 { recordingManager.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                recordingManager.errorMessage = nil
            }
        } message: {
            Text(recordingManager.errorMessage ?? "")
        }
        .alert("Enable Cursor Recording", isPresented: $recordingManager.showAccessibilityWarning) {
            Button("Open Settings") {
                recordingManager.openAccessibilitySettings()
                recordingManager.showAccessibilityWarning = false
            }
            Button("Record Without Cursor", role: .cancel) {
                recordingManager.showAccessibilityWarning = false
            }
        } message: {
            Text("PixelMark needs Accessibility permission to record cursor movements, clicks, and keyboard events.\n\nRecording will continue, but cursor data won't be captured.")
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 24) {
            // User Profile / App Header
            HStack(spacing: 12) {
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isSidebarVisible = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundStyle(ThemeColors.textSecondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            
            // Menu Items
            VStack(spacing: 4) {
                Button {
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.menuBarController?.showRecordingOverlay()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "record.circle")
                            .font(.system(size: 15))
                            .frame(width: 20)
                        
                        Text("New Recording")
                            .font(.system(size: 14))
                        
                        Spacer()
                    }
                    .foregroundStyle(ThemeColors.textPrimary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ThemeColors.sidebarHover)
                    )
                }
                .buttonStyle(.plain)
                .focusable(false)
                .padding(.bottom, 8)
                
                ForEach(sidebarItems) { item in
                    Button {
                        selectedTab = item.id
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.icon)
                                .font(.system(size: 15))
                                .frame(width: 20)
                            
                            Text(item.title)
                                .font(.system(size: 14))
                            
                            Spacer()
                        }
                        .foregroundStyle(selectedTab == item.id ? ThemeColors.accent : ThemeColors.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    selectedTab == item.id ? ThemeColors.sidebarHighlight :
                                    (hoveredSidebarItem == item.id ? ThemeColors.sidebarHover : Color.clear)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .onHover { hovering in
                        hoveredSidebarItem = hovering ? item.id : (hoveredSidebarItem == item.id ? nil : hoveredSidebarItem)
                    }
                }
            }
            .padding(.horizontal, 8)
            
            Spacer()
        }
        .frame(width: 200)
        .background(ThemeColors.sidebarBackground.ignoresSafeArea())
    }
    
    // MARK: - Editor View
    
    private var editorView: some View {
        ZStack {
            if let recording = selectedRecording {
                VideoPlayerView(recording: recording, onClose: {
                    withAnimation {
                        selectedRecording = nil
                    }
                })
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
            
            VStack(alignment: .leading, spacing: 32) {
                HStack {
                    Text("Editor")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(ThemeColors.textPrimary)
                    
                    Spacer()
                    
                    Button {
                        recordingManager.loadRecentRecordings()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(ThemeColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                }
                
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(recordingManager.recentRecordings) { recording in
                            RecordingRow(
                                recording: recording,
                                onOpen: {
                                    withAnimation {
                                        selectedRecording = recording
                                    }
                                },
                                onReveal: { recordingManager.revealInFinder(recording) },
                                onDelete: {
                                    recordingManager.deleteRecording(recording)
                                    Task {
                                        try? await Task.sleep(nanoseconds: 100_000_000)
                                        recordingManager.loadRecentRecordings()
                                    }
                                }
                            )
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ThemeColors.textSecondary.opacity(0.1), lineWidth: 1)
                    )
                }
            }
            .padding(40)
            .opacity(selectedRecording != nil ? 0 : 1)
        }
    }
    
    // MARK: - Settings Detail View
    
    private var settingsDetailView: some View {
        SettingsView()
    }
    
    // MARK: - Status Section
    
    private var recordingStatusSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            
            Text(formatDuration(recordingManager.recordingDuration))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(ThemeColors.textPrimary)
            
            Spacer()
            
            if recordingManager.isPaused {
                Text("PAUSED")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(ThemeColors.secondaryBackground)
        .cornerRadius(8)
        .padding(.top, 16)
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

// MARK: - Debug View

struct DebugView: View {
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Debug Info")
                .font(.headline)
            
            Text("Output: \(settings.outputDirectory.path)")
                .font(.caption)
                .textSelection(.enabled)
            
            Button("Open Console") {
                NSWorkspace.shared.launchApplication("Console")
            }
            
            Button("Reload Recordings") {
                recordingManager.loadRecentRecordings()
            }
            
            Button("Close") {
                dismiss()
            }
        }
        .padding(20)
        .frame(width: 400, height: 300)
    }
}

struct SidebarItem: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
}

#Preview {
    ContentView()
}
