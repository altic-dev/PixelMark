//
//  RecordingRow.swift
//  PixelMark
//
//  Created by PixelMark on 11/23/25.
//

import SwiftUI

struct RecordingRow: View {
    let recording: RecordingFile
    let onOpen: () -> Void
    let onReveal: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "video")
                .foregroundStyle(ThemeColors.textSecondary)
            
            Text(recording.name)
                .font(.system(size: 14))
                .foregroundStyle(ThemeColors.textPrimary)
            
            Spacer()
            
            Text(recording.formattedSize)
                .font(.system(size: 12))
                .foregroundStyle(ThemeColors.textSecondary)
            
            if isHovered {
                HStack(spacing: 12) {
                    Button(action: onOpen) {
                        Image(systemName: "play.fill")
                            .foregroundStyle(ThemeColors.textPrimary)
                    }
                    Button(action: onReveal) {
                        Image(systemName: "folder")
                            .foregroundStyle(ThemeColors.textPrimary)
                    }
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.red)
                    }
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
        }
        .padding(12)
        .background(isHovered ? ThemeColors.sidebarHighlight : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
