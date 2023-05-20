//
//  SessionManager.swift
//  Talker2
//
//  Created by Cole Hershkowitz on 5/17/23.
//

// todo shoudl be an actor

import Foundation
import Combine

// MARK: - Session Manager
class SessionManager: ObservableObject {
    @Published var audioCaptureManager = AudioCaptureManager()
    @Published var transcriptionActivity: [TranscriptionActivity] = []
    @Published var currentTranscriptionActivity: TranscriptionActivity?
    private var transcribers: [Transcriber.ModelName: Transcriber] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var transcribeDelay: TimeInterval = 1.0 // tunable delay
    let modelUpgradeDelay: TimeInterval = 0.5
    
    var bestTranscription: String {
        return transcriptionActivity.last?.transcriptionText ?? ""
    }
    
    func getTranscriber(_ modelName: Transcriber.ModelName) async -> Transcriber? {
        if transcribers[modelName] == nil {
            await loadTranscriber(modelName)
        }
        return transcribers[modelName]
    }
    
    func loadTranscriber(_ modelName: Transcriber.ModelName) async {
        guard transcribers[modelName] == nil else {
            print("transcriber \(modelName) already loaded")
            return
        }
        
        let startTime = Date()
        self.transcribers[modelName] = await Transcriber(modelName: modelName)
        let endTime = Date()
        print("Time to load the \(modelName.rawValue) model: \(endTime.timeIntervalSince(startTime)) seconds")
    }
    
    func unloadTranscriber(_ modelName: Transcriber.ModelName) {
        if transcribers[modelName] != nil {
            transcribers.removeValue(forKey: modelName)
            print("\(modelName.rawValue) model unloaded.")
        }
    }
    

    
    init(modelName: Transcriber.ModelName) {
        audioCaptureManager.runId = UUID().uuidString
        Task {
            await self.loadTranscriber(.tiny)
        }
        
        audioCaptureManager.$powerLevel
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    struct TranscriptionActivity {
        var uuid: UUID?
        var start: TimeInterval
        var end: TimeInterval
        var startDate: Date
        var endDate: Date?
        var modelName: Transcriber.ModelName
        var transcriptionText: String?
    }
    
    func start() {
        transcriptionActivity = []
        currentTranscriptionActivity = nil
        
        audioCaptureManager.startRecording()
        Task {
            await self.loadTranscriber(.small)
        }
        startTranscription()
    }
    
    func stop() {
        guard audioCaptureManager.isRecording else {
            print("Couldn't stop recording again")
            return
        }
        audioCaptureManager.stopRecording()
        currentTranscriptionActivity = nil
        unloadTranscriber(.small)
        unloadTranscriber(.medium)
    }
    
    private func startTranscription() {
        Task {
            try! await Task.sleep(nanoseconds: UInt64(transcribeDelay * 1_000_000_000))
            while audioCaptureManager.isRecording {
                var modelName: Transcriber.ModelName? = .tiny
                // Check if we need to upgrade the model
                if let lastNoiseEvent = audioCaptureManager.noiseEvents.last(where: { $0.state == .noisy }),
                   let lastTranscriptionEvent = transcriptionActivity.last,
                   (lastTranscriptionEvent.end - lastNoiseEvent.end) > modelUpgradeDelay {
                    // If the last noise event ended more than modelUpgradeDelay seconds
                    // before the last transcription event, upgrade the model for the next transcription
                    modelName = modelName?.upgradedModel
                    print("upgrading model")
                    print("Last noise event end time: \(lastNoiseEvent.end)")
                    print("Last transcription event end time: \(lastTranscriptionEvent.end)")
                }
                
                // In the future I should transcribe in blocks, once I am happy or have a nicely transcribed block with a quite gap.  I don't need to retranscribe it all of th time.
                let startTime: TimeInterval = 0
                guard let modelName = modelName,
                      let transcriber = await getTranscriber(.tiny),
                      await !transcriber.isTranscribing,
                      let negativeEndTime = audioCaptureManager.recordingStartedAt?.timeIntervalSinceNow,
                      let endTime = Optional(-negativeEndTime),
                      let audioData = audioCaptureManager.audioData(startTime: startTime, endTime: endTime)
                       else {
                    try! await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000)) // Don't burn the CPU too bad in this loop
                    continue
                }

                let startDate = Date()
                DispatchQueue.main.async { [weak self] in
                    guard self?.audioCaptureManager.isRecording ?? false else {
                        return
                    }
                    self?.currentTranscriptionActivity = TranscriptionActivity(
                        uuid: nil,
                        start: startTime,
                        end: endTime,
                        startDate: startDate,
                        endDate: nil,
                        modelName: modelName,
                        transcriptionText: nil
                    )
                }
                // Start transcribing with the current model
                let (uuid, transcription) = try await transcriber.requestTranscription(from: audioData)
                let endDate = Date()
                let activity = TranscriptionActivity(
                    uuid: uuid,
                    start: startTime,
                    end: endTime,
                    startDate: startDate,
                    endDate: endDate,
                    modelName: modelName,
                    transcriptionText: transcription
                )


                DispatchQueue.main.async { [weak self] in
                    guard self?.audioCaptureManager.isRecording ?? false else {
                        return
                    }
                    self?.transcriptionActivity.append(activity)
                    self?.currentTranscriptionActivity = nil
                }
            }
        }
    }
}
