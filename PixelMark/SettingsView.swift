//
//  SettingsView.swift
//  PixelMark
//
//  Created by PixelMark on 11/22/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @State private var selectedCategory: SettingsCategory = .general
    @State private var hoveredCategory: SettingsCategory?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // Animation state
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Settings Sidebar
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingsCategory.allCases.indices, id: \.self) { index in
                    let category = SettingsCategory.allCases[index]
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: category.icon)
                                .font(.system(size: 14))
                                .frame(width: 20)
                            Text(category.title)
                                .font(.system(size: 14))
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .foregroundStyle(selectedCategory == category ? ThemeColors.accent : ThemeColors.textSecondary)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredCategory = hovering ? category : (hoveredCategory == category ? nil : hoveredCategory)
                    }
                    // Staggered animation for items
                    .offset(x: isVisible ? 0 : -20)
                    .opacity(isVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.2).delay(Double(index) * 0.03), value: isVisible)
                }
                Spacer()
            }
            .padding(16)
            .frame(width: 200)
            .background(ThemeColors.sidebarBackground) // Unified black background
            .overlay(
                Rectangle()
                    .frame(width: 1)
                    .foregroundStyle(ThemeColors.textSecondary.opacity(0.1)), // Subtle separator
                alignment: .trailing
            )
            .transition(.move(edge: .leading))
            
            // Settings Content
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        Text(selectedCategory.title)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(ThemeColors.textPrimary)
                            .opacity(isVisible ? 1 : 0)
                            .offset(y: isVisible ? 0 : 10)
                            .animation(.easeOut(duration: 0.3).delay(0.1), value: isVisible)
                        
                        selectedCategoryView
                            .opacity(isVisible ? 1 : 0)
                            .animation(.easeOut(duration: 0.3).delay(0.15), value: isVisible)
                    }
                    .padding(40)
                }
            }
            .background(ThemeColors.primaryBackground)
            .frame(maxWidth: .infinity)
        }
        .background(ThemeColors.primaryBackground)
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
    
    @ViewBuilder
    private var selectedCategoryView: some View {
        switch selectedCategory {
        case .general: generalSection
        case .advanced: advancedSection
        }
    }
    
    // MARK: - Sections
    
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            appearanceSection
            Divider().overlay(ThemeColors.textSecondary.opacity(0.1))
            outputSection
            Divider().overlay(ThemeColors.textSecondary.opacity(0.1))
            recordingSection
            Divider().overlay(ThemeColors.textSecondary.opacity(0.1))
            shortcutsSection
        }
    }
    
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            actionsSection
        }
    }
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ThemeColors.textPrimary)
                
                HStack(spacing: 12) {
                    ForEach(AppTheme.allCases) { theme in
                        ThemeOptionButton(
                            theme: theme,
                            isSelected: settings.appTheme == theme,
                            action: { settings.appTheme = theme }
                        )
                    }
                }
            }
        }
    }
    
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save Location")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ThemeColors.textPrimary)
            
            HStack {
                Text(settings.outputDirectory.path)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(ThemeColors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Change...") {
                    chooseOutputDirectory()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ThemeColors.secondaryBackground)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(ThemeColors.textSecondary.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ThemeColors.textSecondary.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var recordingSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Unified Grid for Toggles
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 16) {
                GridRow {
                    Text("Hide Window on Start")
                        .font(.system(size: 14))
                        .foregroundStyle(ThemeColors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $settings.hideWindowOnRecording)
                        .toggleStyle(SwitchToggleStyle(tint: ThemeColors.accent))
                        .labelsHidden()
                }
                
                GridRow {
                    Text("Show Cursor")
                        .font(.system(size: 14))
                        .foregroundStyle(ThemeColors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $settings.showCursor)
                        .toggleStyle(SwitchToggleStyle(tint: ThemeColors.accent))
                        .labelsHidden()
                }
                
                GridRow {
                    Text("Capture Audio")
                        .font(.system(size: 14))
                        .foregroundStyle(ThemeColors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $settings.captureAudio)
                        .toggleStyle(SwitchToggleStyle(tint: ThemeColors.accent))
                        .labelsHidden()
                }
                
                if settings.captureAudio {
                    GridRow {
                        Text("System Audio")
                            .font(.system(size: 14))
                            .foregroundStyle(ThemeColors.textSecondary)
                            .padding(.leading, 16)
                        Spacer()
                        Toggle("", isOn: $settings.captureSystemAudio)
                            .toggleStyle(SwitchToggleStyle(tint: ThemeColors.accent))
                            .labelsHidden()
                    }
                    
                    GridRow {
                        Text("Microphone")
                            .font(.system(size: 14))
                            .foregroundStyle(ThemeColors.textSecondary)
                            .padding(.leading, 16)
                        Spacer()
                        Toggle("", isOn: $settings.captureMicrophone)
                            .toggleStyle(SwitchToggleStyle(tint: ThemeColors.accent))
                            .labelsHidden()
                    }
                }
            }
            .frame(maxWidth: 400, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Quality")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ThemeColors.textPrimary)
                
                Picker("", selection: $settings.videoQuality) {
                    ForEach(VideoQuality.allCases) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .labelsHidden()
                .frame(width: 200)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Codec")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ThemeColors.textPrimary)
                
                Picker("", selection: $settings.videoCodec) {
                    ForEach(VideoCodec.allCases) { codec in
                        Text(codec.displayName).tag(codec)
                    }
                }
                .labelsHidden()
                .frame(width: 200)
                
                Text(settings.videoCodec.description)
                    .font(.system(size: 11))
                    .foregroundStyle(ThemeColors.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Frame Rate")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ThemeColors.textPrimary)
                
                Picker("", selection: $settings.frameRate) {
                    ForEach(AppSettings.availableFrameRates, id: \.self) { rate in
                        Text("\(rate) FPS").tag(rate)
                    }
                }
                .labelsHidden()
                .frame(width: 200)
            }
        }
    }
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Shortcut")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ThemeColors.textPrimary)
                
                Text(settings.keyboardShortcut)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ThemeColors.secondaryBackground)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ThemeColors.textSecondary.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reset Settings")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ThemeColors.textPrimary)
                
            Button("Reset All Settings") {
                settings.resetToDefaults()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.1))
            .foregroundStyle(.red)
            .cornerRadius(6)
        }
    }
    
    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.outputDirectory
        panel.prompt = "Select"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                settings.updateOutputDirectory(url)
            }
        }
    }
}

struct ThemeOptionButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    if theme == .cursorDark {
                        Color(hex: "#09090B")
                    } else if theme == .light {
                        Color.white
                    } else {
                        Color(nsColor: .windowBackgroundColor)
                    }
                }
                .frame(height: 80)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? ThemeColors.accent : ThemeColors.textSecondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                )
                
                Text(theme.displayName)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? ThemeColors.textPrimary : ThemeColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 100)
    }
}

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general, advanced
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general: return "General"
        case .advanced: return "Advanced"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .advanced: return "slider.horizontal.3"
        }
    }
}
