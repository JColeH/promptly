//
//  PreferencesManager.swift
//  Talker2
//
//  Created by Cole Hershkowitz on 5/17/23.
//

import Foundation

class PreferencesManager: ObservableObject {
    private let launchOnStartupKey = "launchOnStartup"
    private let debugModeKey = "debugMode"
    private let betaFeaturesKey = "betaFeatures"

    init() {
        UserDefaults.shared.register(defaults: [debugModeKey: true])
    }
    
    var launchOnStartup: Bool {
        get {
            return UserDefaults.shared.bool(forKey: launchOnStartupKey)
        }
        set {
            UserDefaults.shared.set(newValue, forKey: launchOnStartupKey)
        }
    }

    var debugMode: Bool {
        get {
            return UserDefaults.shared.bool(forKey: debugModeKey)
        }
        set {
            UserDefaults.shared.set(newValue, forKey: debugModeKey)
        }
    }

    var betaFeatures: Bool {
        get {
            return UserDefaults.shared.bool(forKey: betaFeaturesKey)
        }
        set {
            UserDefaults.shared.set(newValue, forKey: betaFeaturesKey)
        }
    }
}
