//
//  PixelMarkApp.swift
//  PixelMark
//

import SwiftUI

@main
struct PixelMarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    if let window = NSApp.windows.first {
                        appDelegate.mainWindow = window
                        // Apply custom styling to window
                        window.titlebarAppearsTransparent = false
                        window.titleVisibility = .visible
                        
                        // Make the main window work better with Spaces
                        window.collectionBehavior = [.managed, .fullScreenPrimary]
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    var mainWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar
        menuBarController = MenuBarController()
        
        // Keep app running even when all windows are closed (for menu bar recording)
        NSApp.setActivationPolicy(.regular)
        
        // Listen for workspace notifications (Space changes)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Listen for stream errors
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStreamError),
            name: NSNotification.Name("RecordingStreamError"),
            object: nil
        )
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't terminate when window closes - we want to keep running for menu bar
        return false
    }
    
    @objc private func workspaceDidActivate(_ notification: Notification) {
        // When switching between apps/spaces, ensure our recording panels stay visible
        Task { @MainActor in
            // Post notification to refresh recording state
            NotificationCenter.default.post(name: NSNotification.Name("RecordingStateChanged"), object: nil)
        }
    }
    
    @objc private func handleStreamError(_ notification: Notification) {
        if let error = notification.userInfo?["error"] as? Error {
            Task { @MainActor in
                // Show an alert about the recording error
                let alert = NSAlert()
                alert.messageText = "Recording Interrupted"
                alert.informativeText = "The recording was interrupted: \(error.localizedDescription)\n\nAny captured footage has been saved."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}
