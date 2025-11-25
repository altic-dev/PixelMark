//
//  VideoPlayerView.swift
//  PixelMark
//
//  Created by PixelMark on 11/23/25.
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let recording: RecordingFile
    let onClose: () -> Void
    
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var showCursor = true
    @State private var cursorStyle: CursorStyle = .default
    @State private var showClickEffects = true
    @State private var playbackSpeed: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onClose) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(ThemeColors.textSecondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(recording.name)
                    .font(.headline)
                    .foregroundStyle(ThemeColors.textPrimary)
                
                Spacer()
                
                // Placeholder for symmetry
                Spacer().frame(width: 60)
            }
            .padding()
            .background(ThemeColors.secondaryBackground)
            
            // Main Content: Video Player + Editing Sidebar
            HStack(spacing: 0) {
                // Video Player Area
                ZStack {
                    if let player = player {
                        PlayerView(player: player)
                            .onAppear {
                                player.play()
                                isPlaying = true
                            }
                        
                        // Cursor overlay (if enabled and events exist)
                        if showCursor, let project = recording.project, !project.metadata.events.isEmpty,
                           let width = project.metadata.recordingWidth,
                           let height = project.metadata.recordingHeight {
                            CursorOverlayView(
                                player: player,
                                events: project.metadata.events,
                                cursorStyle: cursorStyle,
                                showClickEffects: showClickEffects,
                                recordingWidth: width,
                                recordingHeight: height
                            )
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundStyle(ThemeColors.textSecondary)
                            Text("Unable to load video")
                                .font(.headline)
                                .foregroundStyle(ThemeColors.textPrimary)
                            Text("The recording file may be missing or corrupted.")
                                .font(.subheadline)
                                .foregroundStyle(ThemeColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 600)
                
                Divider()
                
                // Editing Sidebar
                editingSidebar
                    .frame(width: 280)
                    .background(ThemeColors.secondaryBackground)
            }
        }
        .background(ThemeColors.primaryBackground)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private var editingSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Metadata Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recording Info")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeColors.textPrimary)
                    
                    if let project = recording.project {
                        metadataRow(label: "Type", value: project.metadata.sourceType.capitalized)
                        
                        if let windowTitle = project.metadata.windowTitle {
                            metadataRow(label: "Window", value: windowTitle)
                        }
                        
                        if let appName = project.metadata.appName {
                            metadataRow(label: "App", value: appName)
                        }
                        
                        metadataRow(label: "Duration", value: formatDuration(project.duration))
                        metadataRow(label: "Events", value: "\(project.metadata.events.count)")
                    } else {
                        metadataRow(label: "Format", value: "Legacy MP4")
                    }
                    
                    metadataRow(label: "Created", value: recording.formattedDate)
                    metadataRow(label: "Size", value: recording.formattedSize)
                }
                
                Divider()
                
                // Cursor Controls Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cursor")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeColors.textPrimary)
                    
                    if let project = recording.project, !project.metadata.events.isEmpty {
                        Toggle("Show Cursor", isOn: $showCursor)
                            .toggleStyle(.switch)
                        
                        if showCursor {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Style")
                                    .font(.system(size: 13))
                                    .foregroundStyle(ThemeColors.textSecondary)
                                
                                Picker("", selection: $cursorStyle) {
                                    ForEach(CursorStyle.allCases, id: \.self) { style in
                                        Text(style.rawValue).tag(style)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            Toggle("Click Effects", isOn: $showClickEffects)
                                .toggleStyle(.switch)
                        }
                    } else {
                        Text("No cursor data available")
                            .font(.system(size: 13))
                            .foregroundStyle(ThemeColors.textSecondary)
                    }
                }
                
                Divider()
                
                // Playback Controls Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Playback")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeColors.textPrimary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed")
                                .font(.system(size: 13))
                                .foregroundStyle(ThemeColors.textSecondary)
                            
                            Spacer()
                            
                            Text("\(playbackSpeed, specifier: "%.1f")×")
                                .font(.system(size: 13))
                                .foregroundStyle(ThemeColors.textPrimary)
                        }
                        
                        Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.25)
                            .onChange(of: playbackSpeed) { newValue in
                                player?.rate = Float(newValue)
                            }
                    }
                }
                
                Divider()
                
                // Export Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeColors.textPrimary)
                    
                    Button {
                        exportVideo()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Video")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(ThemeColors.accent)
                        .foregroundStyle(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }
    
    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(ThemeColors.textSecondary)
                .frame(width: 70, alignment: .leading)
            
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(ThemeColors.textPrimary)
                .lineLimit(2)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func exportVideo() {
        // TODO: Implement video export with cursor rendering
        NSWorkspace.shared.selectFile(recording.url.path, inFileViewerRootedAtPath: "")
    }
    
    private func setupPlayer() {
        // Verify the file exists before creating player
        let mediaURL = recording.mediaURL
        guard FileManager.default.fileExists(atPath: mediaURL.path) else {
            print("❌ Media file does not exist at: \(mediaURL.path)")
            return
        }
        
        print("✅ Setting up player for: \(mediaURL.path)")
        player = AVPlayer(url: mediaURL)
    }
}

// MARK: - Cursor Style

enum CursorStyle: String, CaseIterable {
    case `default` = "Default"
    case large = "Large"
    case highlighted = "Highlighted"
    case minimal = "Minimal"
}

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .inline
        view.showsFrameSteppingButtons = false
        view.showsSharingServiceButton = false
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        // Only update if player reference changed (using identity check)
        if nsView.player !== player {
            nsView.player = player
        }
    }
}
