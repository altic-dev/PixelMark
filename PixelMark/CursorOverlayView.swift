//
//  CursorOverlayView.swift
//  PixelMark
//
//  Created by PixelMark on 11/24/25.
//

import SwiftUI
import AVKit
import Combine

/// Overlays cursor and click effects on top of video based on recorded events
struct CursorOverlayView: View {
    let player: AVPlayer
    let events: [RecordingEvent]
    let cursorStyle: CursorStyle
    let showClickEffects: Bool
    let recordingWidth: Int
    let recordingHeight: Int
    
    @State private var currentTime: TimeInterval = 0
    @State private var cursorPosition: CGPoint = .zero
    @State private var isClicking = false
    @State private var clickRingAnimation = false // For the expanding ring effect
    @State private var lastClickEventTimestamp: TimeInterval = -1 // Track which click event we've animated
    
    private let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect() // 60fps
    
    var body: some View {
        GeometryReader { geometry in
            // Calculate the actual video content frame (accounting for aspect ratio/letterboxing)
            let videoFrame = calculateVideoFrame(in: geometry.size)
            
            ZStack {
                // Cursor - positioned relative to video frame
                cursorView
                    .position(
                        x: videoFrame.origin.x + cursorPosition.x,
                        y: videoFrame.origin.y + cursorPosition.y
                    )
                
                // Click effect
                if showClickEffects && isClicking {
                    ZStack {
                        // Persistent indicator while mouse is held
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 24, height: 24)
                        
                        // Expanding ring animation on initial click
                        Circle()
                            .stroke(Color.blue.opacity(0.6), lineWidth: 2)
                            .frame(width: clickRingAnimation ? 50 : 24, height: clickRingAnimation ? 50 : 24)
                            .opacity(clickRingAnimation ? 0 : 0.8)
                    }
                    .position(
                        x: videoFrame.origin.x + cursorPosition.x,
                        y: videoFrame.origin.y + cursorPosition.y
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onReceive(timer) { _ in
                updateCursorPosition(in: videoFrame.size)
            }
        }
        .allowsHitTesting(false) // Don't intercept clicks
    }
    
    /// Calculate where the video content is actually rendered within the view
    /// AVPlayerView maintains aspect ratio, so video may be letterboxed
    private func calculateVideoFrame(in containerSize: CGSize) -> CGRect {
        let videoAspect = CGFloat(recordingWidth) / CGFloat(recordingHeight)
        let containerAspect = containerSize.width / containerSize.height
        
        var videoSize: CGSize
        var videoOrigin: CGPoint
        
        if videoAspect > containerAspect {
            // Video is wider than container - letterbox top/bottom
            videoSize = CGSize(
                width: containerSize.width,
                height: containerSize.width / videoAspect
            )
            videoOrigin = CGPoint(
                x: 0,
                y: (containerSize.height - videoSize.height) / 2
            )
        } else {
            // Video is taller than container - letterbox left/right
            videoSize = CGSize(
                width: containerSize.height * videoAspect,
                height: containerSize.height
            )
            videoOrigin = CGPoint(
                x: (containerSize.width - videoSize.width) / 2,
                y: 0
            )
        }
        
        return CGRect(origin: videoOrigin, size: videoSize)
    }
    
    private var cursorView: some View {
        Group {
            switch cursorStyle {
            case .default:
                defaultCursor
            case .large:
                largeCursor
            case .highlighted:
                highlightedCursor
            case .minimal:
                minimalCursor
            }
        }
    }
    
    private var defaultCursor: some View {
        Image(systemName: "arrowtriangle.up.fill")
            .font(.system(size: 16))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            .rotationEffect(.degrees(-45))
    }
    
    private var largeCursor: some View {
        Image(systemName: "arrowtriangle.up.fill")
            .font(.system(size: 24))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
            .rotationEffect(.degrees(-45))
    }
    
    private var highlightedCursor: some View {
        ZStack {
            Circle()
                .fill(Color.yellow.opacity(0.3))
                .frame(width: 40, height: 40)
            
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .rotationEffect(.degrees(-45))
        }
    }
    
    private var minimalCursor: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 0)
    }
    
    private func updateCursorPosition(in size: CGSize) {
        // Get current playback time
        guard let currentItem = player.currentItem else { return }
        currentTime = CMTimeGetSeconds(currentItem.currentTime())
        
        // Find relevant cursor events
        let cursorEvents = events.filter { event in
            event.type == .cursorMove || event.type == .mouseDown || event.type == .mouseUp
        }
        
        // Find the event at or just before current time
        guard let currentEvent = cursorEvents.last(where: { $0.timestamp <= currentTime }) else {
            return
        }
        
        // Scale factors for coordinate conversion
        let scaleX = size.width / CGFloat(recordingWidth)
        let scaleY = size.height / CGFloat(recordingHeight)
        
        // Determine if we're currently in a click-hold state (between mouseDown and mouseUp)
        // Find the most recent mouseDown before current time
        let lastMouseDown = events.filter { $0.type == .mouseDown && $0.timestamp <= currentTime }.last
        // Find the most recent mouseUp before current time
        let lastMouseUp = events.filter { $0.type == .mouseUp && $0.timestamp <= currentTime }.last
        
        // We're clicking if there's a mouseDown that's more recent than the last mouseUp
        let currentlyHoldingClick: Bool
        if let mouseDown = lastMouseDown {
            if let mouseUp = lastMouseUp {
                currentlyHoldingClick = mouseDown.timestamp > mouseUp.timestamp
            } else {
                currentlyHoldingClick = true // mouseDown with no mouseUp yet
            }
        } else {
            currentlyHoldingClick = false
        }
        
        // Update click state
        if currentlyHoldingClick {
            if !isClicking {
                isClicking = true
                // Trigger ring animation for new click
                if let mouseDown = lastMouseDown, lastClickEventTimestamp != mouseDown.timestamp {
                    lastClickEventTimestamp = mouseDown.timestamp
                    clickRingAnimation = false
                    withAnimation(.easeOut(duration: 0.3)) {
                        clickRingAnimation = true
                    }
                }
            }
        } else {
            isClicking = false
            clickRingAnimation = false
        }
        
        // Extract position from event data
        // Note: Recorded coordinates use macOS coordinate system (origin at bottom-left, Y increases upward)
        // SwiftUI uses origin at top-left (Y increases downward), so we need to flip Y
        switch currentEvent.data {
        case .cursor(let x, let y):
            // Convert recorded coordinates to view coordinates
            // Map from recording resolution to current view size, flipping Y axis
            let flippedY = CGFloat(recordingHeight) - y // Flip Y in recording space
            cursorPosition = CGPoint(x: x * scaleX, y: flippedY * scaleY)
            
        case .click(let x, let y, _):
            let flippedY = CGFloat(recordingHeight) - y // Flip Y in recording space
            cursorPosition = CGPoint(x: x * scaleX, y: flippedY * scaleY)
            
        default:
            break
        }
        
        // Interpolate between events for smoother motion
        if let nextEvent = cursorEvents.first(where: { $0.timestamp > currentTime }) {
            let progress = (currentTime - currentEvent.timestamp) / (nextEvent.timestamp - currentEvent.timestamp)
            
            if case .cursor(let x1, let y1) = currentEvent.data,
               case .cursor(let x2, let y2) = nextEvent.data {
                let interpolatedX = x1 + (x2 - x1) * progress
                let interpolatedY = y1 + (y2 - y1) * progress
                // Flip Y axis for both interpolated points
                let flippedY = CGFloat(recordingHeight) - interpolatedY
                cursorPosition = CGPoint(
                    x: interpolatedX * scaleX,
                    y: flippedY * scaleY
                )
            }
        }
    }
}

#Preview {
    CursorOverlayView(
        player: AVPlayer(),
        events: [],
        cursorStyle: .default,
        showClickEffects: true,
        recordingWidth: 1920,
        recordingHeight: 1080
    )
    .frame(width: 800, height: 600)
    .background(Color.black)
}

