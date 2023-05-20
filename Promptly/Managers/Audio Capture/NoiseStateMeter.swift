//
//  NoiseMeter.swift
//  Talker2
//
//  Created by Cole Hershkowitz on 5/15/23.
//

import AVFoundation


enum NoiseState {
    case quiet
    case noisy
    var displayString: String {
        switch self {
        case .quiet:
            return "Quiet"
        case .noisy:
            return "Noisy"
        }
    }
}

struct NoiseEvent {
    var state: NoiseState
    var startTime: Date
}

struct LogEntry {
    var timestamp: TimeInterval
    var powerLevel: Float
    var minPower: Float
    var maxPower: Float
    var sta: Float
    var lta: Float
    var noisePercentile: Float
    var highThreshold: Float
    var lowThreshold: Float
}

class NoiseStateMonitor {
    
    struct PowerLevel {
        var power: Float
        var time: TimeInterval
    }
    
    // Noise Tracking Hyperparameters
    private(set) var staWindow: TimeInterval = 0.2
    private(set) var ltaWindow: TimeInterval = 10
    private(set) var minMaxWindow: TimeInterval = 10
    private(set) var thresholdMultiplier: Float = 1.5
    private(set) var updateInterval: TimeInterval = 0.05
    private(set) var maxPowerPercentile: Float = 0.90
    private(set) var minPowerPercentile: Float = 0.05

    private(set) var staLtaHighThreshold: Float = 0.3 //3.5
    private(set) var staLtaLowThreshold: Float = 0.7 //2.8 //1.6
    
    
    // Noise events and power levels
    private(set) var noiseEvents = [NoiseEvent]()
    private(set) var powerLevel: Float?
    private(set) var staPowerLevels = [PowerLevel]()
    private(set) var ltaPowerLevels = [PowerLevel]()
    private(set) var sortedPowerLevels = [PowerLevel]()
    
    private(set) var logEntries = [LogEntry]()
    
    func reset(recordingStartedAt: Date) {
        noiseEvents = [NoiseEvent(state: .noisy, startTime: recordingStartedAt)]
        staPowerLevels = []
        ltaPowerLevels = []
        sortedPowerLevels = []
        logEntries = []
    }
    
    private func powerAtPercentile(_ percentile: Float, in powerLevels: [PowerLevel]) -> Float {
        guard !powerLevels.isEmpty else { return 0 }
        let index = Int(Float(powerLevels.count - 1) * percentile)
        return powerLevels[index].power
    }

    
    func updatePowerLevel(power: Float) {
        let timestamp = -noiseEvents.first!.startTime.timeIntervalSinceNow
        let powerLevel = power
        let newPowerLevel = PowerLevel(power: power, time: timestamp)
        staPowerLevels.append(newPowerLevel)
        ltaPowerLevels.append(newPowerLevel)
        sortedPowerLevels.insert(newPowerLevel, at: sortedPowerLevels.firstIndex(where: { $0.power > power }) ?? sortedPowerLevels.endIndex)
        
        staPowerLevels = staPowerLevels.filter { $0.time >= timestamp - staWindow }
        ltaPowerLevels = ltaPowerLevels.filter { $0.time >= timestamp - ltaWindow }
        sortedPowerLevels = sortedPowerLevels.filter { $0.time >= timestamp - minMaxWindow }
        sortedPowerLevels = sortedPowerLevels.filter { $0.time >= timestamp - minMaxWindow }

        let sta = staPowerLevels.reduce(0.0) { $0 + $1.power } / Float(staPowerLevels.count)
        let lta = ltaPowerLevels.reduce(0.0) { $0 + $1.power } / Float(ltaPowerLevels.count)
        let minPower = powerAtPercentile(minPowerPercentile, in: sortedPowerLevels)
        let maxPower = powerAtPercentile(maxPowerPercentile, in: sortedPowerLevels)
        let noisePercentile = (sta - minPower) / (maxPower - minPower)

        let adjustedHighThreshold = staLtaHighThreshold// * max(1, thresholdMultiplier * (1 - (lta - minPower)))
        let adjustedLowThreshold = staLtaLowThreshold// * max(1, thresholdMultiplier * (1 - (lta - minPower)))

        // create a new log entry
        let logEntry = LogEntry(timestamp: timestamp, powerLevel: powerLevel, minPower: minPower, maxPower: maxPower, sta: sta, lta: lta, noisePercentile: noisePercentile, highThreshold: adjustedHighThreshold, lowThreshold: adjustedLowThreshold)
        logEntries.append(logEntry)
        
        let currentNoiseState: NoiseState
        if let lastEvent = noiseEvents.last {
            switch lastEvent.state {
            case .quiet:
                currentNoiseState = noisePercentile > adjustedLowThreshold ? .noisy : .quiet
            case .noisy:
                currentNoiseState = noisePercentile < adjustedHighThreshold ? .quiet : .noisy
            }
            
            if lastEvent.state != currentNoiseState {
                noiseEvents.append(NoiseEvent(state: currentNoiseState, startTime: Date().addingTimeInterval(-staWindow)))
            }
        }
        
        
    }
}



class NoiseStateMonitorOld {

    struct PowerLevel {
        var power: Float
        var time: TimeInterval
    }
    
    // Noise Tracking Hyperparameters
    private(set) var staWindow: TimeInterval = 0.3
    private(set) var ltaWindow: TimeInterval = 10
    private(set) var staLtaHighThreshold: Float =  1.20 // 1.05
    private(set) var staLtaLowThreshold: Float = 0.7 // 0.95
    private(set) var updateInterval: TimeInterval = 0.05
    
    // Noise events and power levels
    private(set) var noiseEvents = [NoiseEvent]()
    private(set) var powerLevel: Float? = nil
    private(set) var staLtaRatio: Float? = nil
    private(set) var powerLevels = [PowerLevel]()
    
    private(set) var logEntries = [LogEntry]()

    
    func reset(recordingStartedAt: Date) {
        // Note, we initialize as noisy because we assume the user will be talking right when launching.
        noiseEvents = [NoiseEvent(state: .noisy, startTime: recordingStartedAt)]
        powerLevels = []
    }
    
    func updatePowerLevel(power: Float) {
        let currentTime = Date().timeIntervalSince1970
        self.powerLevel = power
        powerLevels.append(PowerLevel(power: power, time: currentTime))
        
        powerLevels = powerLevels.filter { $0.time >= currentTime - ltaWindow }
        let staPowerLevels = powerLevels.filter { $0.time >= currentTime - staWindow }
        
        let sta = staPowerLevels.reduce(0.0) { $0 + $1.power } / Float(staPowerLevels.count)
        let lta = powerLevels.reduce(0.0) { $0 + $1.power } / Float(powerLevels.count)
        
        self.staLtaRatio = sta / lta
        let staLtaRatio = staLtaRatio!
        
        let currentNoiseState: NoiseState
        if let lastEvent = noiseEvents.last {
            switch lastEvent.state {
            case .quiet:
                currentNoiseState = staLtaRatio > staLtaHighThreshold ? .noisy : .quiet
            case .noisy:
                currentNoiseState = staLtaRatio < staLtaLowThreshold ? .quiet : .noisy
            }
            
            if lastEvent.state != currentNoiseState {
                noiseEvents.append(NoiseEvent(state: currentNoiseState, startTime: Date().addingTimeInterval(-staWindow)))
            }
        }
    }
}
