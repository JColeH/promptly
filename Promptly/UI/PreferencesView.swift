//
//  ContentView.swift
//  Talker
//
//  Created by Cole Hershkowitz on 5/7/23.
//

import SwiftUI
import HotKey

struct PreferencesView: View {
    @State private var launchOnStartup: Bool = false
    @State private var debugMode: Bool = false
    @State private var betaFeatures: Bool = false
    @EnvironmentObject var hotKeyWindowManager: HotKeyWindowManager
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var preferences: PreferencesManager


    var body: some View {
        List {
            GroupBox("Transcription") {
                PreferencesRowView("Hotkey", details: "The key combination that activates recording for transcription") {
                    HotKeyRecorderView(keyCombo: Binding(get: {
                        hotKeyWindowManager.activateHotKey?.keyCombo
                    }, set: { newValue in
                        guard let newValue = newValue else {
                            hotKeyWindowManager.activateHotKey = nil
                            return
                        }
                        hotKeyWindowManager.activateHotKey  = nil
                        hotKeyWindowManager.activateHotKey = HotKey(keyCombo: newValue)
                    }))
                }
                PreferencesRowView("Debug Mode", details: "See debug view when recording.") {
                    Toggle("", isOn: $preferences.debugMode)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
            }
            .padding()
            GroupBox("General") {
                PreferencesRowView("Launch on Startup") {
                    Toggle("", isOn: $launchOnStartup)
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                }
                Spacer()
            }
            .padding()
            
            VStack(alignment: .center) {
                Text("About")
                Text("v \(versionNumber) (\(bundleNumber))") // Version
                Text("Made with ♥️ and 🍵 by Cole")
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .listStyle(.plain)
    }
    
    var versionNumber: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "null"

    }
    var bundleNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "null"

    }
}

struct MicOrderView: View {
    @State private var mics = [
        "John",
        "Alice",
        "Bob",
        "Foo",
        "Bar"
    ]
    
    @State private var ignoredMics: [String] = []
    
    var body: some View {
        List {
            ForEach(Array(mics.enumerated()), id: \.element) { index, mic in
                HStack {
                    Text(mic)
                        .strikethrough(ignoredMics.contains(where: {$0 == mic}))
                    Spacer()
                    Button(action: {
                        mics.move(fromOffsets: IndexSet(integer: index), toOffset: 0)
                    }) {
                        Image(systemName: "arrow.up")
                    }
                    .buttonStyle(PlainButtonStyle())
                    Button(action: {
                        if ignoredMics.contains(where: {$0 == mic}) {
                            ignoredMics.removeAll(where: {$0 == mic})
                        } else {
                            ignoredMics.append(mic)
                        }
                    }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }.onMove { from, to in
                mics.move(fromOffsets: from, toOffset: to)

            }
        }
        .frame(height: CGFloat(mics.count)*24)
        .background(Color(hex: 0x302A24))
    }
}


struct PreferencesRowView<Content: View>: View {
    var title: String
    var details: String?
    var content: () -> Content

    init(_ title: String, details: String? = nil, content: @escaping () -> Content) {
        self.title = title
        self.details = details
        self.content = content
    }
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text(title)
                    .foregroundColor(.primary)
                if let details = self.details {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(Color(hex: 0xA7A49F))
                }
            }
            .foregroundColor(.primary)
            Spacer()
            
            content()
        }
        .padding()
    }
}

struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
            .frame(height: 700)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
    }
}

fileprivate extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

fileprivate extension KeyCombo {
    var fullDescription: String? {
        guard let keyDescription = self.key else {
            return nil
        }
        return ("\(self.modifiers.description)\(self.modifiers.isEmpty ? "" : " + ")\(keyDescription)")
    }
}



import Combine
import SwiftUI
import HotKey

struct HotKeyRecorderView: View {
    @State private var isFocused = false
    @Binding var keyCombo: KeyCombo?
    @StateObject var hotKeyRecorder = HotKeyRecorder()
    
    var body: some View {
        ZStack {
            HotKeyRecorderRepresentableView(isFocused: $isFocused)
            Text(hotKeyRecorder.hotKey == nil ? "record" : "\(hotKeyRecorder.hotKey!.fullDescription ?? "na")")
                .font(.title3)
                .foregroundColor(hotKeyRecorder.hotKey == nil ? Color.primary.opacity(0.5) : Color.primary)
                .padding()
        }
        .frame(width: 130, height: 34)
        .background(Color.clear)
        .overlay(RoundedRectangle(cornerRadius: 10)
        .stroke(isFocused ? Color.red : Color.primary.opacity(0.5), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused.toggle()
        }
        .environmentObject(hotKeyRecorder)
        .onChange(of: hotKeyRecorder.hotKey) { newValue in
            keyCombo = newValue
        }
        .onChange(of: keyCombo) { newValue in
            hotKeyRecorder.hotKey = newValue
        }
        .onAppear() {
            hotKeyRecorder.hotKey = keyCombo
        }

    }
}

class HotKeyRecorder: ObservableObject {
    @Published var hotKey: KeyCombo?
}

fileprivate class HotKeyRecorderNSView: NSView {
    let isFocusedSubject = PassthroughSubject<Bool, Never>()
    
    var isFocused: Bool = false {
        didSet {
            isFocusedSubject.send(isFocused)
            if isFocused {
                window?.makeFirstResponder(self)
            } else if (window?.firstResponder == self) {
                self.resignFirstResponder()
            }
        }
    }
    var hotKeyRecorder: HotKeyRecorder?

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isFocused else {
            self.resignFirstResponder()
            return
        }
        if event.modifierFlags.rawValue == 256 || event.keyCode == 53 {
            super.keyDown(with: event)
            return
        }
        
        hotKeyRecorder?.hotKey = KeyCombo(carbonKeyCode: UInt32(event.keyCode), carbonModifiers: event.modifierFlags.carbonFlags)

        self.isFocused = false
//        self.resignFirstResponder()
    }
}

fileprivate struct HotKeyRecorderRepresentableView: NSViewRepresentable {
    @Binding var isFocused: Bool
    @EnvironmentObject var hotKeyRecorder: HotKeyRecorder

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: HotKeyRecorderRepresentableView
        var cancellable: AnyCancellable?
        
        init(_ parent: HotKeyRecorderRepresentableView) {
            self.parent = parent
        }
        
        deinit {
            cancellable?.cancel()
        }
    }
    
    func makeNSView(context: Context) -> HotKeyRecorderNSView {
        let nsView = HotKeyRecorderNSView()
        nsView.hotKeyRecorder = hotKeyRecorder
        context.coordinator.cancellable = nsView.isFocusedSubject
            .receive(on: DispatchQueue.main)
            .sink { isFocused in
                context.coordinator.parent.isFocused = isFocused
            }
        return nsView
    }
    
    func updateNSView(_ nsView: HotKeyRecorderNSView, context: Context) {
        nsView.isFocused = isFocused
    }
}

extension UserDefaults {
    static let shared: UserDefaults = {
        if isDebug {
            return UserDefaults(suiteName: "Debug")!
        } else {
            return UserDefaults(suiteName: "Standard")!
        }
    }()
    
    private static var isDebug: Bool {
        get {
#if DEBUG
            return true
#else
            return false
#endif
        }
        
    }
}
