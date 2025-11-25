//
//  OverlayPanel.swift
//  PixelMark
//
//  Created by PixelMark on 11/22/25.
//

import SwiftUI
import AppKit

class OverlayPanel: NSPanel {
    init(recordingManager: RecordingManager, onClose: @escaping () -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 60),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Critical settings for multi-Space support
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.hidesOnDeactivate = false  // CRITICAL: Don't hide when switching Spaces
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isOpaque = false
        self.animationBehavior = .utilityWindow
        
        // Center horizontally on the main screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let panelWidth: CGFloat = 480
            let panelHeight: CGFloat = 60
            
            let x = screenRect.midX - (panelWidth / 2)
            let y = screenRect.minY + 100 // Position near bottom
            
            self.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        }
        
        let contentView = RecordingOverlayView(
            recordingManager: recordingManager,
            onClose: onClose
        )
        
        self.contentView = NSHostingView(rootView: contentView)
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
