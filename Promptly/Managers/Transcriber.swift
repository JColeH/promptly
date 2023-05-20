import Foundation
import SwiftUI
import AVFoundation
import Combine

@MainActor
class Transcriber: ObservableObject {
    @Published private(set) var isTranscribing = false
    private(set) var canTranscribe = false

    private(set) var isModelLoaded = false
    private(set) var transcriptionID: UUID? = nil
    private let modelName: ModelName
    private var whisperContext: WhisperContext?
    
        
    enum ModelName: String, CaseIterable, Identifiable {
        case tiny = "ggml-tiny.en"
        case small = "ggml-small.en"
        case medium = "ggml-medium.en"
        var id: String { self.rawValue }
        
        var upgradedModel: ModelName? {
            switch self {
            case .tiny:
                return .small
            case .small:
                return .medium
            default:
                return nil
            }
        }
    }
    
    private var modelUrl: URL? {
//        Bundle.main.url(forResource: modelName.rawValue, withExtension: "bin", subdirectory: "Resources")
        Bundle.main.url(forResource: modelName.rawValue, withExtension: "bin")
    }
    
    private enum LoadError: Error {
        case couldNotLocateModel
    }
    
    init(modelName: ModelName) {
        self.modelName = modelName
        do {
            try loadModel()
            canTranscribe = true
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func loadModel() throws {
        guard let modelUrl = modelUrl else {
            throw LoadError.couldNotLocateModel
        }
        whisperContext = try WhisperContext.createContext(path: modelUrl.path())
    }

    func unloadModel() {
        whisperContext = nil
    }
    
    func requestTranscription(from url: URL) async throws -> (UUID, String?) {
        let data = try readAudioSamples(url)
        return try await requestTranscription(from: data)
    }
    
    func requestTranscription(from samples: [Float]) async throws -> (UUID, String?) {
        guard let whisperContext = whisperContext else {
            throw LoadError.couldNotLocateModel
        }
        
        let transcriptionID = UUID()
        isTranscribing = true
        self.transcriptionID = transcriptionID
        await whisperContext.fullTranscribe(samples: samples)
        let text = await whisperContext.getTranscription()
        let transcription = text.removingCharactersBetweenBrackets()
        isTranscribing = false
        return (transcriptionID, transcription)
    }

//    func cancelTranscription() {
//        whisperContext?.cancelTranscription()
//        self.liveTranscription = nil
//        self.transcriptionID = nil
//        isTranscribing = true = nil
//    }

    private func readAudioSamples(_ url: URL) throws -> [Float] {
        return try decodeWaveFile(url)
    }
    
    func decodeWaveFile(_ url: URL) throws -> [Float] {
        let data = try Data(contentsOf: url)
        let floats = stride(from: 44, to: data.count, by: 2).map {
            return data[$0..<$0 + 2].withUnsafeBytes {
                let short = Int16(littleEndian: $0.load(as: Int16.self))
                return max(-1.0, min(Float(short) / 32767.0, 1.0))
            }
        }
        return floats
    }
}


extension String {
    func removingCharactersBetweenBrackets() -> String{
        let start: Character = "["
        let end: Character = "]"
        var returnString = self
        while let startIndex = returnString.firstIndex(of: start), let endIndex = returnString.firstIndex(of: end) {
            if startIndex < endIndex {
                returnString.removeSubrange(startIndex...endIndex)
            } else {
                break
            }
        }
        return returnString
    }
}
