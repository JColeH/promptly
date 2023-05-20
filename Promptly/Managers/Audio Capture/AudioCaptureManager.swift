import AVFoundation

class AudioCaptureManager: ObservableObject {
    @Published var isRecording = false
    @Published var powerLevel: Float?
    private var audioRecorder: AVAudioRecorder!
    var recordingStartedAt: Date?
    var recordingEndedAt: Date?
    var splitPoints = [TimeInterval]()
    var runId: String?
    
    private let sampleRate: Double = 16000
    
    var noiseMonitor = NoiseStateMonitor()

    struct NoiseEvent {
        var state: NoiseState // noisy or quite
        var start: TimeInterval
        var end: TimeInterval
    }
    
    var noiseEvents: [NoiseEvent] {
        guard let recordingStartedAt = self.recordingStartedAt else {
            return []
        }
        var eventsOut: [NoiseEvent] = []
        let noiseEvents = noiseMonitor.noiseEvents
        
        for i in 0..<noiseEvents.count {
            let currentEvent = noiseEvents[i]
            var endTime: Date
            
            // If this is the last event, use the globalFinishTime as its end time
            if i == noiseEvents.count - 1 {
                endTime = recordingEndedAt ?? Date()
            } else {
                // If not the last event, use the next event's start time as its end time
                let nextEvent = noiseEvents[i+1]
                endTime = nextEvent.startTime
            }
            
            let startDate = currentEvent.startTime.timeIntervalSince(recordingStartedAt)
            let endDate = max(startDate, endTime.timeIntervalSince(recordingStartedAt))
//            print(startDate, endDate)
            
            let eventOut = NoiseEvent(state: currentEvent.state, start: startDate, end: endDate)
            eventsOut.append(eventOut)
        }

        return eventsOut
    }
    
    
    
    var latestNoiseEventDate: TimeInterval? {
        // Find the first 'NOISY' event in the list
        if let latestNoisyEvent = noiseEvents.reversed().first(where: { $0.state == .noisy }) {
            // Convert the event's end time to a Date and return it
            return latestNoisyEvent.end
        }

        // If no 'NOISY' event is found, return nil
        return nil
    }
    
    func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("Microphone Access granted")
                } else {
                    print("Microphone Access denied")
                }
            }
        case .denied:
            print("Microphone Access denied")
            break
        case .restricted:
            print("Microphone Access restricted")
            break
        @unknown default:
            break
        }
    }

    func setupAudioRecorder() {

    }

    var currentRecordingURL: URL? {
        guard let runId = self.runId else {return nil}
        return getDocumentsDirectory().appendingPathComponent("\(runId).wav")
    }
    
    func startRecording() {
        // Perhaps try to do just one tie
        let runId = UUID().uuidString
        let audioFilename = getDocumentsDirectory().appendingPathComponent("\(runId).wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder.isMeteringEnabled = true
            audioRecorder.prepareToRecord()
        } catch {
            print("Couldn't create the recorder")
        }
        
        //  For every run
        self.runId = runId
        recordingEndedAt = nil
        splitPoints = []
        recordingStartedAt = Date()
        audioRecorder.record()
        isRecording = true
        startMonitoringAudioLevels()
    }

    func stopRecording() {
        audioRecorder.stop()
        recordingEndedAt = Date()

        isRecording = false
     }

    func addSplitPoint() {
        guard let recordingStartedAt = recordingStartedAt else { return }
        let elapsedTime = Date().timeIntervalSince(recordingStartedAt)
        splitPoints.append(elapsedTime)
    }

    func startMonitoringAudioLevels() {
        guard isRecording, let recordingStartedAt = self.recordingStartedAt else {
            fatalError("Must be recording to start monitoring audio levels")
        }
        
        noiseMonitor.reset(recordingStartedAt: recordingStartedAt)
        
        Timer.scheduledTimer(withTimeInterval: noiseMonitor.updateInterval, repeats: true) { timer in
            guard self.isRecording  else {
                timer.invalidate()
                return
            }
            
//            self.audioRecorder.updateMeters()
            let power = self.positivePower(forChannel: 0)
            self.noiseMonitor.updatePowerLevel(power: power)
            self.powerLevel = self.noiseMonitor.powerLevel
//            print("Power level: \(self.powerLevel)")
        }
    }
    
    func positivePower(forChannel channelNumber: Int) -> Float {
        audioRecorder.updateMeters()
        let decibels = audioRecorder.averagePower(forChannel: channelNumber)

        // These constants are generally recommended for audio processing
        let MIN_DECIBELS: Float = -80.0
        let decibelClamp = max(decibels, MIN_DECIBELS)

        if decibelClamp == MIN_DECIBELS {
            return 0.0
        }
        else {
            return pow((decibelClamp + 80.0) / 80.0, 2.0)
        }
    }
    
    func audioData(startTime: TimeInterval? = nil, endTime: TimeInterval? = nil) -> [Float]? {
        guard let url = currentRecordingURL else {
            print("Recording URL is not set")
            return nil
        }
        
        let data = try! Data(contentsOf: url)
        let startSample = Int((startTime ?? 0.0) * sampleRate) * 2 + 44
        let endSampleUnbound = {
            if let endTime = endTime {
                return Int(endTime * sampleRate) * 2 + 44
            } else {
                return data.count
            }
        }()
        let endSample = min(endSampleUnbound, data.count)
                
        print("pulling sample from index \(startSample) to index \(endSample)")
        let floats = stride(from: startSample, to: endSample, by: 2).map {
            return data[$0..<$0 + 2].withUnsafeBytes {
                let short = Int16(littleEndian: $0.load(as: Int16.self))
                return max(-1.0, min(Float(short) / 32767.0, 1.0))
            }
        }
        return floats
    }

    func audioBuffer(startTime: TimeInterval? = nil, endTime: TimeInterval? = nil) -> AVAudioPCMBuffer? {
        guard let floats = audioData(startTime: startTime, endTime: endTime) else {
            return nil
        }
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat!, frameCapacity: AVAudioFrameCount(floats.count))!
        
        for (index, value) in floats.enumerated() {
            audioBuffer.floatChannelData?.pointee[index] = value
        }
        
        audioBuffer.frameLength = AVAudioFrameCount(floats.count)
        
        return audioBuffer
    }

    func wavFile(startTime: TimeInterval? = nil, endTime: TimeInterval? = nil) -> URL? {
        guard let audioBuffer = audioBuffer(startTime: startTime, endTime: endTime) else {
            return nil
        }
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsDirectory.appendingPathComponent("output.wav")
        
        do {
            let audioFile = try AVAudioFile(forWriting: outputURL, settings: audioBuffer.format.settings)
            try audioFile.write(from: audioBuffer)
            print("Audio file saved to \(outputURL)")
            return outputURL
        } catch {
            print("Error saving audio file: \(error.localizedDescription)")
            return nil
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
