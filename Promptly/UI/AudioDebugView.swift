import SwiftUI
import AVFoundation
import Combine

struct AudioDebugView: View {
    @StateObject private var audioPlaybackManager = AudioPlaybackManager()
    @EnvironmentObject var sessionManager: SessionManager
    
    @State private var selectedTime: TimeInterval = 0
    var currentLogEntry: LogEntry? {
        sessionManager.audioCaptureManager.noiseMonitor.logEntries.first {
            $0.timestamp >= selectedTime
            
        }
    }

    
    var clampedPowerLevel: Double {
        get {
            let level = Double(sessionManager.audioCaptureManager.powerLevel ?? 0)
            return min(max(level, 0), 1)
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    if self.sessionManager.audioCaptureManager.isRecording {
                        self.sessionManager.stop()
                        
                    } else {
                        self.sessionManager.start()
                    }
                }) {
                    Text(self.sessionManager.audioCaptureManager.isRecording ? "Stop" : "Start")
                }
                Spacer()
            }
            .pickerStyle(SegmentedPickerStyle())
            HStack {
                Text("Time: \(String(format: "%.3f", currentLogEntry?.timestamp ?? 0.0))")
                    .frame(width: 150)
                Text("Min Power: \(String(format: "%.3f", currentLogEntry?.minPower ?? 0.0))")
                    .frame(width: 100)
                Text("Max Power: \(String(format: "%.3f", currentLogEntry?.maxPower ?? 0.0))")
                    .frame(width: 100)
                Text("Power: \(String(format: "%.3f", currentLogEntry?.powerLevel ?? 0.0))")
                    .frame(width: 100)
                Text("STA: \(String(format: "%.3f", currentLogEntry?.sta ?? 0.0))")
                    .frame(width: 100)
                Text("Noise Level: \(String(format: "%.3f", currentLogEntry?.noisePercentile ?? 0.0))")
                    .frame(width: 100)
                Text("Min Thresh: \(String(format: "%.3f", currentLogEntry?.lowThreshold ?? 0.0))")
                    .frame(width: 100)
                Text("Max Thresh: \(String(format: "%.3f", currentLogEntry?.highThreshold ?? 0.0))")
                    .frame(width: 100)
            }
            ProgressView(value: currentLogEntry?.powerLevel ?? 0, total: 1)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            HStack {
                Button(action: {selectedTime = selectedTime - 0.05}, label: {Text("-")})
                VStack {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                        Rectangle()
                            .fill(Color.green)
                        ForEach(sessionManager.audioCaptureManager.noiseEvents, id: \.start) { event in
        //                    let _ = print((event.end - event.start)*10)
                            Rectangle()
                                .fill(event.state == .noisy ? Color.red : Color.brown)
                                .frame(width: CGFloat(event.end - event.start)*10)
                                .offset(x: CGFloat(event.start)*10)
                                .onTapGesture {
                                    Task {
                                        if let audioData = sessionManager.audioCaptureManager.audioData(startTime: event.start, endTime: event.end) {

                                        }
                                    }
                                }
                        }
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 2)
                            .offset(x: selectedTime*10)

                    }
                    .frame(height: 30)
                    Slider(value: $selectedTime, in: 0...85, step: 0.25) // replace maximumTime with the max timestamp
                }
                Button(action: {selectedTime = selectedTime + 0.05}, label: {Text("+")})
            }
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sessionManager.transcriptionActivity.reversed(), id: \.uuid) { transcription in
                        let duration = transcription.endDate?.timeIntervalSince(transcription.startDate)
                        let durationString: String = {
                            guard let duration = duration else {return "na"}
                            return String(format: "%.2f", duration)
                        }()
                        
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Time:").bold()
                                Text("\((transcription.endDate?.formattedTime()).NAIfNil)")
                                Spacer()
                                Text("Duration:").bold()
                                Text(durationString)
                            }
                            
                            HStack {
                                Text("Transcription:").bold()
                                Text(transcription.transcriptionText ?? "N/A").lineLimit(1)
                            }
                            
                            HStack {
                                Text("Model:").bold()
                                Text("\(transcription.modelName.rawValue)")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .padding()
        .onAppear {
            self.sessionManager.audioCaptureManager.checkMicrophonePermission()
        }
        .onChange(of: sessionManager.audioCaptureManager.noiseMonitor.logEntries.last?.timestamp ?? 0) { newValue in
            selectedTime = newValue
        }
    }
}



// MARK: - AudioPlaybackManager
fileprivate class AudioPlaybackManager: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    
    func playAudio(from url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing audio file: \(error.localizedDescription)")
        }
    }
}


extension Date {
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: self)
    }
}
