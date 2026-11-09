import AVFoundation
import Foundation
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import Speech

private let log = Log(.media)

/// Escucha la nota de voz con el reconocimiento de voz de macOS (en el Mac, gratis) para saber en qué segundo
/// se dice cada palabra. Si no hay permiso o no se reconoce, devuelve una lista vacía y el video se reparte por largo.
enum VoiceListener {
    static let locales = ["es-CO", "es-MX", "es-US", "es-419", "es-ES"]

    static func words(in audio: URL) -> [WordTiming] {
        guard authorize() else {
            log.write("Contenido: sin permiso de reconocimiento de voz; el video se reparte por largo del texto")
            return []
        }
        guard let recognizer = locales.lazy.compactMap({ SFSpeechRecognizer(locale: Locale(identifier: $0)) })
            .first(where: { $0.isAvailable }) else {
            log.write("Contenido: el reconocimiento de voz en español no está disponible")
            return []
        }
        let request = SFSpeechURLRecognitionRequest(url: audio)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        request.taskHint = .dictation
        final class Box: @unchecked Sendable {
            var segments: [Double: WordTiming] = [:]
            var finished = false
        }
        let box = Box()
        let done = DispatchSemaphore(value: 0)
        let task = recognizer.recognitionTask(with: request) { result, error in
            guard !box.finished else { return }
            if let result {
                // En audios largos el reconocimiento puede entregar varias partes: se juntan todas por su tiempo.
                for segment in result.bestTranscription.segments {
                    box.segments[segment.timestamp] = WordTiming(word: segment.substring, start: segment.timestamp,
                                                                 end: segment.timestamp + segment.duration)
                }
            }
            if result?.isFinal == true || error != nil {
                box.finished = true
                done.signal()
            }
        }
        if done.wait(timeout: .now() + 180) == .timedOut { task.cancel() }
        let words = box.segments.values.sorted { $0.start < $1.start }
        log.write("Contenido: reconocí \(words.count) palabras en tu audio")
        return words
    }

    static func authorize() -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .denied, .restricted: return false
        default:
            let done = DispatchSemaphore(value: 0)
            var granted = false
            SFSpeechRecognizer.requestAuthorization { status in
                granted = status == .authorized
                done.signal()
            }
            _ = done.wait(timeout: .now() + 120)
            return granted
        }
    }

    static func duration(_ file: URL) -> Double? {
        guard let audio = try? AVAudioFile(forReading: file), audio.fileFormat.sampleRate > 0 else { return nil }
        let seconds = Double(audio.length) / audio.fileFormat.sampleRate
        return seconds > 0.3 ? seconds : nil
    }
}
