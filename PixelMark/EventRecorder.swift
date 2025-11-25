//
//  EventRecorder.swift
//  PixelMark
//
//  Created by PixelMark on 11/24/25.
//

import Foundation
import AppKit
import Cocoa

/// Records user events (cursor, clicks, keyboard, scroll) during screen recording
class EventRecorder {
    private var events: [RecordingEvent] = []
    private var startTime: Date?
    private var isRecording = false
    private var isPaused = false
    private var hasAccessibilityPermission = false
    
    // Recording area bounds (to convert absolute to relative coordinates)
    private var recordingFrame: CGRect = .zero
    private var scaleFactor: CGFloat = 1.0
    
    // Event monitors
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var scrollMonitor: Any?
    
    // Throttling for cursor movement
    private var lastCursorUpdateTime: Date?
    private var cursorThrottleInterval: TimeInterval = 0.016 // ~60fps
    
    // MARK: - Public Methods
    
    /// Check if accessibility permissions are granted
    /// This is a definitive check - no false positives
    func checkAccessibilityPermission() -> Bool {
        // Check without prompting (we handle the prompt ourselves)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        print("🔒 Accessibility permission check: \(isTrusted ? "GRANTED ✅" : "NOT GRANTED ❌")")
        return isTrusted
    }
    
    /// Start recording events
    /// - Parameters:
    ///   - startTime: Recording start time
    ///   - recordingFrame: The bounds of the recording area (window or screen frame) in points
    ///   - videoWidth: Actual video width in pixels
    ///   - videoHeight: Actual video height in pixels
    func startRecording(startTime: Date, recordingFrame: CGRect, videoWidth: Int, videoHeight: Int) {
        guard !isRecording else { return }
        
        self.startTime = startTime
        self.recordingFrame = recordingFrame
        self.isRecording = true
        self.isPaused = false
        self.events = []
        
        // Calculate scale factor to convert points to pixels
        let scaleX = CGFloat(videoWidth) / recordingFrame.width
        let scaleY = CGFloat(videoHeight) / recordingFrame.height
        // Use average scale (should be same for both if aspect ratio is preserved)
        self.scaleFactor = (scaleX + scaleY) / 2.0
        
        print("📍 Recording frame: origin=(\(recordingFrame.origin.x), \(recordingFrame.origin.y)) size=(\(recordingFrame.width)x\(recordingFrame.height)) points")
        print("📍 Video size: \(videoWidth)x\(videoHeight) pixels, scale=\(scaleFactor)x")
        
        // Check accessibility permission
        hasAccessibilityPermission = checkAccessibilityPermission()
        
        if hasAccessibilityPermission {
            setupEventMonitors()
            print("✅ Event recording started with accessibility permissions")
        } else {
            print("⚠️ Event recording started WITHOUT accessibility permissions - events will not be captured")
            print("   Grant Accessibility permission in System Settings > Privacy & Security > Accessibility")
        }
    }
    
    /// Stop recording and return captured events
    func stopRecording() -> [RecordingEvent] {
        guard isRecording else { return [] }
        
        isRecording = false
        isPaused = false
        removeEventMonitors()
        
        let capturedEvents = events
        events = []
        startTime = nil
        
        return capturedEvents
    }
    
    /// Pause event recording
    func pauseRecording() {
        isPaused = true
    }
    
    /// Resume event recording
    func resumeRecording() {
        isPaused = false
    }
    
    // MARK: - Private Methods
    
    private func setupEventMonitors() {
        // Wrap in try-catch to handle any permission errors gracefully
        do {
            // Local mouse monitor (works without accessibility permission for our app's events)
            // Include drag events to track cursor during click-and-drag operations
            localMouseMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                          .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]
            ) { [weak self] event in
                self?.handleMouseEvent(event)
                return event
            }
            
            // Global monitors require accessibility permission
            if hasAccessibilityPermission {
                // Global mouse monitor for cursor movement and clicks
                // Include drag events to track cursor during click-and-drag operations
                globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
                    matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                              .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp]
                ) { [weak self] event in
                    self?.handleMouseEvent(event)
                }
                
                // Scroll events
                scrollMonitor = NSEvent.addGlobalMonitorForEvents(
                    matching: [.scrollWheel]
                ) { [weak self] event in
                    self?.handleScrollEvent(event)
                }
                
                // Global keyboard monitor
                globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(
                    matching: [.keyDown]
                ) { [weak self] event in
                    self?.handleKeyEvent(event)
                }
                
                // Local keyboard monitor
                localKeyMonitor = NSEvent.addLocalMonitorForEvents(
                    matching: [.keyDown]
                ) { [weak self] event in
                    self?.handleKeyEvent(event)
                    return event
                }
            }
        } catch {
            print("⚠️ Error setting up event monitors: \(error)")
        }
    }
    
    private func removeEventMonitors() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }
    
    private func handleMouseEvent(_ event: NSEvent) {
        guard isRecording, !isPaused, let startTime = startTime else { return }
        
        let timestamp = Date().timeIntervalSince(startTime)
        let location = NSEvent.mouseLocation
        
        // Convert absolute screen coordinates to relative coordinates within recording area
        // then scale to video pixel coordinates
        // macOS uses bottom-left origin, but recording frame also uses bottom-left
        let relativeX = location.x - recordingFrame.origin.x
        let relativeY = location.y - recordingFrame.origin.y
        
        // Scale to video pixel space
        let x = relativeX * scaleFactor
        let y = relativeY * scaleFactor
        
        switch event.type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            // Throttle cursor movement updates (applies to both regular moves and drags)
            let now = Date()
            if let lastUpdate = lastCursorUpdateTime,
               now.timeIntervalSince(lastUpdate) < cursorThrottleInterval {
                return
            }
            lastCursorUpdateTime = now
            
            let recordingEvent = RecordingEvent(
                timestamp: timestamp,
                type: .cursorMove,
                data: .cursor(x: x, y: y)
            )
            events.append(recordingEvent)
            
        case .leftMouseDown:
            let recordingEvent = RecordingEvent(
                timestamp: timestamp,
                type: .mouseDown,
                data: .click(x: x, y: y, button: .left)
            )
            events.append(recordingEvent)
            
        case .leftMouseUp:
            let recordingEvent = RecordingEvent(
                timestamp: timestamp,
                type: .mouseUp,
                data: .click(x: x, y: y, button: .left)
            )
            events.append(recordingEvent)
            
        case .rightMouseDown:
            let recordingEvent = RecordingEvent(
                timestamp: timestamp,
                type: .mouseDown,
                data: .click(x: x, y: y, button: .right)
            )
            events.append(recordingEvent)
            
        case .rightMouseUp:
            let recordingEvent = RecordingEvent(
                timestamp: timestamp,
                type: .mouseUp,
                data: .click(x: x, y: y, button: .right)
            )
            events.append(recordingEvent)
            
        case .otherMouseDown:
            let recordingEvent = RecordingEvent(
                timestamp: timestamp,
                type: .mouseDown,
                data: .click(x: x, y: y, button: .middle)
            )
            events.append(recordingEvent)
            
        case .otherMouseUp:
            let recordingEvent = RecordingEvent(
                timestamp: timestamp,
                type: .mouseUp,
                data: .click(x: x, y: y, button: .middle)
            )
            events.append(recordingEvent)
            
        default:
            break
        }
    }
    
    private func handleScrollEvent(_ event: NSEvent) {
        guard isRecording, !isPaused, let startTime = startTime else { return }
        
        let timestamp = Date().timeIntervalSince(startTime)
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY
        
        // Only record non-zero scrolls
        if deltaX != 0 || deltaY != 0 {
            let recordingEvent = RecordingEvent(
                timestamp: timestamp,
                type: .scroll,
                data: .scroll(deltaX: deltaX, deltaY: deltaY)
            )
            events.append(recordingEvent)
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecording, !isPaused, let startTime = startTime else { return }
        
        let timestamp = Date().timeIntervalSince(startTime)
        let keyCode = event.keyCode
        let characters = event.charactersIgnoringModifiers
        
        // Get modifier flags
        var modifiers: [String] = []
        let flags = event.modifierFlags
        if flags.contains(.command) { modifiers.append("command") }
        if flags.contains(.option) { modifiers.append("option") }
        if flags.contains(.control) { modifiers.append("control") }
        if flags.contains(.shift) { modifiers.append("shift") }
        if flags.contains(.function) { modifiers.append("function") }
        
        let recordingEvent = RecordingEvent(
            timestamp: timestamp,
            type: .keyPress,
            data: .key(keyCode: keyCode, characters: characters, modifiers: modifiers)
        )
        events.append(recordingEvent)
    }
    
    deinit {
        removeEventMonitors()
    }
}

