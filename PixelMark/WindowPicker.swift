//
//  WindowPicker.swift
//  PixelMark
//
//  Created by PixelMark on 11/22/25.
//

import SwiftUI
import AppKit
import ScreenCaptureKit
import Combine

class WindowPicker: NSObject, ObservableObject {
    @Published var hoveredWindow: SCWindow?
    
    private var pickerWindow: NSWindow?
    private var onSelect: ((SCWindow) -> Void)?
    private var windows: [SCWindow] = []
    var screenFrame: CGRect = .zero
    
    private var keyDownMonitor: Any?
    private var mouseMonitor: Any?
    private var mouseDownMonitor: Any?
    private var refreshTimer: Timer?
    
    func startPicking(windows: [SCWindow], onSelect: @escaping (SCWindow) -> Void) {
        // Clean up any existing session first
        stopPicking()
        
        // Initial windows (though we will refresh immediately)
        self.windows = windows
        self.onSelect = onSelect
        
        // Get the main screen
        guard let screen = NSScreen.main, let primaryScreen = NSScreen.screens.first else { return }
        
        // Calculate screen frame in Quartz coordinates
        self.screenFrame = CGRect(
            x: screen.frame.origin.x,
            y: primaryScreen.frame.height - (screen.frame.origin.y + screen.frame.height),
            width: screen.frame.width,
            height: screen.frame.height
        )
        
        // Create a borderless, transparent window that covers the screen
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = .clear
        window.isOpaque = false
        window.level = .screenSaver // Ensure it's on top of everything
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.isReleasedWhenClosed = false 
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let contentView = WindowPickerView(picker: self)
        
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        self.pickerWindow = window
        
        // Activate app to ensure we capture clicks
        NSApp.activate(ignoringOtherApps: true)
        
        // Start refreshing windows to handle space changes
        startRefreshingWindows()
        
        // Add local event monitor for ESC key
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.stopPicking()
                return nil // Consume the event
            }
            return event
        }
        
        // Add local event monitor for mouse movement
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove(event)
            return event
        }
        
        // Add local event monitor for mouse click (more reliable than SwiftUI tap gesture on transparent windows)
        mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleMouseDown(event)
            return nil // Consume the click
        }
    }
    
    func stopPicking() {
        stopRefreshingWindows()
        
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDownMonitor = nil
        }
        
        pickerWindow?.close()
        pickerWindow = nil
        onSelect = nil
        windows = []
        hoveredWindow = nil
    }
    
    func selectWindow(_ window: SCWindow) {
        let callback = onSelect
        stopPicking()
        callback?(window)
    }
    
    private func startRefreshingWindows() {
        // Refresh immediately
        Task { await refreshWindows() }
        
        // Schedule periodic refresh
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.refreshWindows()
            }
        }
    }
    
    private func stopRefreshingWindows() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    @MainActor
    private func refreshWindows() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            
            // Filter windows (same logic as ScreenRecorder)
            self.windows = content.windows.filter { window in
                // Must be on screen
                guard window.isOnScreen else { return false }
                
                // Must be on normal window layer (0)
                guard window.windowLayer == 0 else { return false }
                
                // Exclude our own app
                if let appName = window.owningApplication?.applicationName, appName == "PixelMark" {
                    return false
                }
                
                // Exclude small windows
                if window.frame.width < 50 || window.frame.height < 50 {
                    return false
                }
                
                // Must have a title or belong to a known app
                if (window.title ?? "").isEmpty && (window.owningApplication?.applicationName ?? "").isEmpty {
                    return false
                }
                
                return true
            }
            
            // Re-check hover with new windows if mouse position is known?
            // We rely on next mouse move, or we could store last mouse location.
            // For simplicity, let's wait for next mouse move event (which happens constantly if user moves).
            
        } catch {
            print("Failed to refresh windows in picker: \(error)")
        }
    }
    
    private func handleMouseMove(_ event: NSEvent) {
        guard let window = event.window, let primaryScreen = NSScreen.screens.first else { return }
        
        // Convert window coordinates (Bottom-Left) to Screen coordinates (Bottom-Left)
        let globalCocoa = window.convertPoint(toScreen: event.locationInWindow)
        
        // Convert to Quartz coordinates (Top-Left)
        let p = CGPoint(
            x: globalCocoa.x,
            y: primaryScreen.frame.height - globalCocoa.y
        )
        
        // Find the top-most window that contains the point
        let found = windows.first { window in
            window.frame.contains(p)
        }
        
        if found?.windowID != hoveredWindow?.windowID {
            print("DEBUG: Mouse(Window): \(event.locationInWindow)")
            print("DEBUG: Mouse(Cocoa): \(globalCocoa)")
            print("DEBUG: Mouse(Quartz): \(p)")
            print("DEBUG: Screen Height: \(primaryScreen.frame.height)")
            if let f = found {
                print("DEBUG: Found Window: \(f.title ?? "untitled") Frame: \(f.frame)")
            } else {
                print("DEBUG: No window found at \(p)")
            }
            
            hoveredWindow = found
        }
    }
    
    private func handleMouseDown(_ event: NSEvent) {
        if let window = hoveredWindow {
            selectWindow(window)
        }
    }
}

struct WindowPickerView: View {
    @ObservedObject var picker: WindowPicker
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.2)
                .edgesIgnoringSafeArea(.all)
            
            // Instructions
            VStack {
                Text("Select a Window to Record")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 60)
                    .shadow(radius: 4)
                
                Text("Press ESC to Cancel")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 8)
                    .shadow(radius: 4)
                
                Spacer()
            }
            
            if let window = picker.hoveredWindow {
                // Draw selection highlight
                // Convert global window coordinates to local view coordinates
                // We subtract the screen's origin (in Quartz coords) because the view 
                // is positioned at (0,0) in the screen's frame.
                let localX = window.frame.origin.x - picker.screenFrame.origin.x
                let localY = window.frame.origin.y - picker.screenFrame.origin.y
                
                Rectangle()
                    .stroke(Color.blue, lineWidth: 4)
                    .background(Color.blue.opacity(0.1))
                    .frame(width: window.frame.width, height: window.frame.height)
                    .position(
                        x: localX + window.frame.width / 2,
                        y: localY + window.frame.height / 2
                    )
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
