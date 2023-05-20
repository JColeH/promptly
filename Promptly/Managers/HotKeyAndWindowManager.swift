//
//  HotKeyAndWindowManager.swift
//  Talker2
//
//  Created by Cole Hershkowitz on 5/17/23.
//

import SwiftUI
import HotKey
import Combine

class HotKeyWindowManager: ObservableObject {
    @Published private(set) var previousApp: NSRunningApplication?
    let activateRecordingUICalled = PassthroughSubject<Void, Never>()

    
    var window: NSWindow? {
        didSet {
            self.window?.orderOut(nil)
        }
    }
    
    var activateHotKey: HotKey? {
        didSet {setupActivateHotkey()}
    }
    
    var cancelHotKey: HotKey? {
        didSet {setupCancelHotkey()}
    }
    
    private func setupActivateHotkey() {
        guard let activateHotKey = activateHotKey else {
            return
        }
        
        activateHotKey.keyDownHandler = { [weak self] in
            guard let self = self else {
                return
            }
            
            self.activateRecordingUI()
        }
        
        let encoder = JSONEncoder()
        if let encodedData = try? encoder.encode(activateHotKey.keyCombo) {
            UserDefaults.shared.set(encodedData, forKey: "ActivateHotKey")
        }
    }
    
    private func setupCancelHotkey() {
        guard let cancelHotKey = cancelHotKey else {
            return
        }

        cancelHotKey.keyDownHandler = { [weak self] in
            guard let self = self else {
                return
            }

            NSApp.activate(ignoringOtherApps: true)

            if self.window?.isVisible == true {
                self.hideWindow()
            }
        }
    }

    init(window: NSWindow? = nil) {
        self.window = window
        self.window?.orderOut(nil)
        
        if let savedKeyComboData = UserDefaults.shared.data(forKey: "ActivateHotKey"),
           let activateKeyCombo = try? JSONDecoder().decode(KeyCombo.self, from: savedKeyComboData) {
                    self.activateHotKey = HotKey(keyCombo: activateKeyCombo)
        } else {
            self.activateHotKey = HotKey(key: .k, modifiers: [.command])
        }
        
        setupActivateHotkey()
    }

    func hideWindow() {
        self.window?.orderOut(nil)
        cancelHotKey = nil
        previousApp?.activate(options: [])
        previousApp = nil
    }

    func deinitHotKeys() {
        activateHotKey = nil
        cancelHotKey = nil
    }
    
    func activateRecordingUI() {
        previousApp = NSWorkspace.shared.frontmostApplication
        self.activateRecordingUICalled.send()
        
        NSApp.activate(ignoringOtherApps: true)
        
        if self.window?.isVisible != true {
            self.showWindow()
        }
        
    }
    
    func showWindow() {
        self.window?.makeKeyAndOrderFront(nil)
        self.cancelHotKey = HotKey(key: .escape, modifiers: [])
    }

    func copy(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    
    func paste(text: String) {
        let pasteboard = NSPasteboard.general
        
        // Save the current contents of the pasteboard
        let savedItems = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let value = item.string(forType: type) {
                    newItem.setString(value, forType: type)
                }
            }
            return newItem
        }
        
        // Set the new text on the pasteboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Ensure your app loses focus before simulating the paste
        //        NSApp.hide(nil)
        
        // You may want to add a slight delay here to allow the other app to gain focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Simulate the paste
            let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
            
            let cmdVKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 is the virtual key code for the V key
            let cmdVKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            
            cmdVKeyDown?.flags = .maskCommand
            cmdVKeyUp?.flags = .maskCommand
            
            let location = CGEventTapLocation.cghidEventTap
            
            cmdVKeyDown?.post(tap: location)
            cmdVKeyUp?.post(tap: location)
            
            // Restore the original contents of the pasteboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pasteboard.clearContents()
                pasteboard.writeObjects(savedItems!)
            }
        }
    }
    
    // Implement NSWindowDelegate method
    func windowDidResignKey(_ notification: Notification) {
        // The window has lost focus, so hide it
        hideWindow()
    }
}

extension KeyCombo: Codable {
    
    enum CodingKeys: CodingKey {
        case key
        case modifiers
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let key = try container.decode(UInt32.self, forKey: .key)
        let modifiers = try container.decode(UInt32.self, forKey: .modifiers)
        
        self.init(key: Key(carbonKeyCode: key)!, modifiers: NSEvent.ModifierFlags(carbonFlags: modifiers))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(key?.carbonKeyCode, forKey: .key)
        try container.encode(modifiers.carbonFlags, forKey: .modifiers)
    }
}
