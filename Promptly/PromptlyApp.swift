//
//  ContentView.swift
//  PromptlyTest
//
//  Created by Cole Hershkowitz on 5/19/23.
//

import SwiftUI

@main
struct Promptly: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var preferences: PreferencesManager = PreferencesManager()

    var body: some Scene {
        WindowGroup {
            RecorderView()
                .background(VisualEffectView())
                .ignoresSafeArea()
                .frame(minWidth: 200, minHeight: 200)
                .environmentObject(appDelegate.hotKeyWindowManager)
                .environmentObject(appDelegate.sessionManager)
                .environmentObject(preferences)
                .onReceive(appDelegate.hotKeyWindowManager.activateRecordingUICalled) { [weak appDelegate] _ in
                    appDelegate?.sessionManager.start()
                }

        }
        MenuBarExtra("Whisper App", systemImage: "mic.fill") {
            Button("Record") {
//                appDelegate.hotKeyWindowManager.activateRecordingUI()
            }
            Divider()
            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
                //                window.makeKeyAndOrderFront(nil)
            }
            Button("Check for Updates...") {
                
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }.keyboardShortcut("q")
        }
    }
}

// I Don't like how two of my classes HotKeyWindowManager and SessionManager are declared here instead of in the appdelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var hotKeyWindowManager: HotKeyWindowManager = HotKeyWindowManager()
    private var windowDelegate = WindowDelegate()
    @ObservedObject var sessionManager = SessionManager(modelName: .tiny)  // make it non-private
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Get a reference to the window and setup the hotKeyWindowManager
        if let window = NSApp.windows.first {
            hotKeyWindowManager.window = window
            window.delegate = windowDelegate
            windowDelegate.stopSessionAction = { [weak self] in
                self?.sessionManager.stop()
                self?.hotKeyWindowManager.hideWindow()
            }
            
            // Cutomize window behavior
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.level = NSWindow.Level.floating

            window.styleMask.remove(.resizable)
            window.styleMask = [.resizable, .titled, .closable, .miniaturizable, .fullSizeContentView]

            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.level = NSWindow.Level.floating
   
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Deinitialize the hotkeys when the application is about to quit
        hotKeyWindowManager.deinitHotKeys()
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    var stopSessionAction: (() -> Void)?
    
    func windowDidResignKey(_ notification: Notification) {
        // Commenting out while testing something
        stopSessionAction?()
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}
