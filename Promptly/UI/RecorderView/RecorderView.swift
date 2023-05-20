//
//  RecorderView().swift
//  Talker
//
//  Created by Cole Hershkowitz on 5/12/23.
//

import SwiftUI

// Where does escape go?
// Where do I start transcription again or just stop transcfirption?


struct RecorderView: View {
    @EnvironmentObject var hotKeyWindowManager: HotKeyWindowManager
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var preferences: PreferencesManager

    // TODO shouldn't be calculated every time
    var actions: [Action] {[
        Action(title: "Insert into \(hotKeyWindowManager.previousApp?.localizedName ?? "application")", hotkey: .return, perform: {
            //  This is a bit of a hack for now.  I should more explicitly start and stop the session in reaciton to hotkeys
            if sessionManager.audioCaptureManager.isRecording {
                sessionManager.stop()
                print("Insert pressed")
                hotKeyWindowManager.hideWindow()
                hotKeyWindowManager.paste(text: self.text)
            } else {
                sessionManager.start()
            }
        }, variant: .primary),
        Action(title: "Copy to Clipboard", hotkey: "C", perform: {
            print("Copy pressed")
            hotKeyWindowManager.hideWindow()
            hotKeyWindowManager.copy(text: self.text)
        }, variant: .secondary),
//        Action(title: "Edit with Keyboard", hotkey: "I", perform: { print("Edit with Keyboard pressed") }, variant: .secondary),
//        Action(title: "Edit with Audio", hotkey: "T", perform: { print("Edit with Audio pressed") }, variant: .secondary),
        Action(title: "Exit", hotkey: .escape, perform: {
//            hotKeyWindowManager.hideWindow()
            print("Exit")
        }, variant: .secondary),
    ]}
    
    var text: String {sessionManager.bestTranscription}
    var visibleText: String {
        // Don't show text if this session ended over 5 seconds ago.
        // This avoids old sessions from showing up briefly in the recorderView when it first shows
        (sessionManager.audioCaptureManager.recordingEndedAt?.timeIntervalSinceNow ?? .infinity) > 5 ? sessionManager.bestTranscription : ""
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ScrollView(.vertical) {
                    Text(visibleText)
                        .font(.title)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
                        .padding()
                }
                HStack {
                    Spacer()
                    VStack {
                        TranscriptionStatusView()
                            .padding()
                        Spacer()
                    }
                }
            }
            Divider()
            ActionBar(allActions: actions)
            if preferences.debugMode {
                Divider()
                AudioDebugView()
            }
        }
        .cornerRadius(16)
    }
}

struct ActionBar: View {
    @State private var showingMoreActions = false
    let allActions: [Action]
    var mainActions: [Action] {
        if allActions.count > 3 {
            return Array(allActions.prefix(upTo: 2))
        } else {
            return allActions
        }
    }
    var extraActions: [Action]? {
        if allActions.count > 3 {
            return Array(allActions.suffix(from: 2))
        }
        return nil
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            if let extraActions = extraActions {
                ActionButton(title: "more...", hotkey: "M", action: {
                    showingMoreActions = true
                }, variant: .secondary)
                .popover(isPresented: $showingMoreActions) {
                    VStack {
                        ForEach(extraActions) { action in
                            ActionButton(title: action.title, hotkey: action.hotkey, action: action.perform, variant: action.variant)
                            if extraActions.last?.id != action.id {
                                Divider()
                            }
                        }
                    }
                    .padding()
                }
                FatDivider()
            }
            
            // Main Actions
            ForEach(mainActions.reversed()) { action in
                ActionButton(title: action.title, hotkey: action.hotkey, action: action.perform, variant: action.variant)
                if mainActions.first?.id != action.id {
                    FatDivider()
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
    }
}

struct Action: Identifiable {
    let title: String
    let hotkey: KeyEquivalent
    let perform: () -> Void
    let variant: ButtonVariant
    
    var id: String {title}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        RecorderView()
            .frame(width: 700, height: 300)
    }
}

enum ButtonVariant {
    case primary, secondary
}

struct ActionButton: View {
    var title: String
    var hotkey: KeyEquivalent
    var action: () -> Void
    var variant: ButtonVariant
    @GestureState private var isPressed = false
    @State private var isHotkeyPressed = false
    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(title)
                .fontWeight(variant == .primary ? .bold : .light)
                .opacity(variant == .primary ? 1.0 : 0.7)
            Spacer()
                .frame(width: 10)
            Text(hotkey.displayValue)
                .fontWeight(.bold)
                .foregroundColor(variant == .primary ? Color.accentColor : Color.accentColor.opacity(0.8))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background((isPressed || isHotkeyPressed) ? Color.gray.opacity(0.1) : (isHovered ? Color.gray.opacity(0.05) : Color.clear))
        .cornerRadius(10)
        .onHover { hovering in
            isHovered = hovering
        }
        .gesture(DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, state, _ in
                state = true
            }
            .onEnded { _ in
                self.action()
            }
        )
        .onKeyboardShortcut(key: hotkey, modifiers: []  , perform: {
            isHotkeyPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isHotkeyPressed = false
            }
        })

    }
}

struct FatDivider: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .frame(width: 2, height: 20)
            .opacity(0.2)
    }
}

struct TranscriptionStatusView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var isHovering = false

    private func status(for model: Transcriber.ModelName) -> (color: Color, isActive: Bool) {
        // Determine isPulsing
        let isActive: Bool = sessionManager.currentTranscriptionActivity?.modelName == model

        // Determine color
        let color: Color = {
            guard let latestNoiseEventDate = sessionManager.audioCaptureManager.latestNoiseEventDate else {
                return .gray
            }
            
            if let completedTranscription = sessionManager.transcriptionActivity.reversed().first(where: { $0.modelName == model && $0.endDate != nil }) {
                if completedTranscription.end >= latestNoiseEventDate {
                    return .green
                } else {
                    return .yellow
                }
            } else {
                return .gray
            }
        }()

        return (color: color, isActive: isActive)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 14) {
            HStack {
                Text("medium")
                    .opacity(isHovering ? 1.0 : 0.0)
                StatusView(color: status(for: .medium).color, isActive: status(for: .medium).isActive)
            }
            HStack {
                Text("small")
                    .opacity(isHovering ? 1.0 : 0.0)
                StatusView(color: status(for: .small).color, isActive: status(for: .small).isActive)
            }
            HStack {
                Text("tiny")
                    .opacity(isHovering ? 1.0 : 0.0)
                StatusView(color: status(for: .tiny).color, isActive: status(for: .tiny).isActive)
            }
        }
        .padding()
        .onHover { hovering in
            self.isHovering = hovering
        }
    }
}

struct StatusView: View {
    let size: CGFloat = 8
    var color: Color
    var isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(isActive ? Color.primary : Color.clear, lineWidth: 2))
        }
    }
}

extension View {
    /// Adds an underlying hidden button with a performing action that is triggered on pressed shortcut
    /// - Parameters:
    ///   - key: Key equivalents consist of a letter, punctuation, or function key that can be combined with an optional set of modifier keys to specify a keyboard shortcut.
    ///   - modifiers: A set of key modifiers that you can add to a gesture.
    ///   - perform: Action to perform when the shortcut is pressed
    public func onKeyboardShortcut(key: KeyEquivalent, modifiers: EventModifiers = .command, perform: @escaping () -> ()) -> some View {
        ZStack {

            Group {
                Button("") {
                    perform()
                }
                .keyboardShortcut(key, modifiers: modifiers)
            }
            .opacity(0)
            self
            
        }
    }
}

extension KeyEquivalent: Equatable {
    public static func ==(lhs: KeyEquivalent, rhs: KeyEquivalent) -> Bool {
        return lhs.character == rhs.character
    }
    
    var displayValue: String {
        switch self {
        case .return:
            return "↵"
        case .tab:
            return "→" // Unicode for "Rightwards Arrow to Bar" (Tab)
        case .escape:
            return "esc"
        default:
            return String(self.character)
        }
    }
}

extension Animation {
    func `repeat`(while expression: Bool, autoreverses: Bool = true) -> Animation {
        if expression {
            return self.repeatForever(autoreverses: autoreverses)
        } else {
            return self
        }
    }
}
