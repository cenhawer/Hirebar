import AVFoundation
import AppKit
import CoreGraphics
import Foundation
import HirebarApplication
import HirebarDomain
import ImageIO

private let log = Log(.media)

public enum ReelRenderer {
    public static let musicExtensions = ["mp3", "m4a", "wav", "aiff"]

    public static func music(for account: ContentAccount) -> URL? {
        musicExtensions.map { account.folder.appendingPathComponent("musica.\($0)") }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    public static let width = 1080
    public static let height = 1920
    public static let fps: Int32 = 30
    public static let captionCenterFromTop = 1300.0
    public static let wordsPerCaption = 3
    public static let musicVolume: Float = 0.10
    public static let wordsPerSecond = 2.7
    static let minimumPreviewSceneSeconds = 1.5
    static let maximumPreviewSceneSeconds = 12.0
    static let previewScenePadding = 0.3

    public struct Scene: Decodable {
        let archivo: String
        let texto: String?
        let segundos: Double?
    }

    public struct Script: Decodable {
        let escenas: [Scene]
        let tono: String?
    }

    public struct Clip: Sendable {
        let page: URL
        let seconds: Double
        let words: [WordTiming]
    }

    public struct Problem: LocalizedError {
        let message: String
        public var errorDescription: String? { message }
    }
    public static func output(_ account: ContentAccount) -> URL {
        account.videoFolder.appendingPathComponent("reel.mp4")
    }
    public static func preview(_ account: ContentAccount) -> URL {
        account.videoFolder.appendingPathComponent("vista-previa.mp4")
    }

    public static func loadScript(_ account: ContentAccount) throws -> (scenes: [Scene], tone: String?) {
        let folder = account.videoFolder
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("guion.json")),
            let script = try? JSONDecoder().decode(Script.self, from: data)
        else {
            throw Problem(message: String(localized: "La IA no dejó el guion del video (video/guion.json)"))
        }
        let scenes = script.escenas.filter { FileManager.default.fileExists(atPath: folder.appendingPathComponent($0.archivo).path) }
        guard !scenes.isEmpty else { throw Problem(message: String(localized: "no encontré las escenas del video")) }
        return (scenes, script.tono)
    }
    public static func readingScript(_ account: ContentAccount) -> String? {
        guard let script = try? loadScript(account) else { return nil }
        let texts = script.scenes.compactMap { $0.texto?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !texts.isEmpty else { return nil }
        let words = texts.map { $0.split(whereSeparator: \.isWhitespace).count }.reduce(0, +)
        let seconds = Int((Double(words) / wordsPerSecond).rounded())
        var lines = [String(localized: "Guion para grabar (\(account.title)), unos \(seconds) segundos:"), ""]
        if let tone = script.tone, !tone.isEmpty { lines += [String(localized: "Tono: \(tone)"), ""] }
        for (index, text) in texts.enumerated() { lines.append("\(index + 1). \(text)") }
        lines += [
            "",
            String(localized: "Léelo de corrido, sin decir los números, con energía y sonriendo (se nota en la voz). ")
                + String(localized: "Si te equivocas, sigue: Hirebar acomoda las escenas a tu ritmo."),
            String(localized: "Responde a este chat con una nota de voz y te devuelvo el video con tu voz, listo para subir."),
        ]
        return lines.joined(separator: "\n")
    }

    public static func renderPreview(
        _ account: ContentAccount, completion: @escaping VideoCompletion
    ) {
        Task.detached(priority: .utility) {
            let result: (URL?, String?)
            do {
                let script = try loadScript(account)
                let clips = script.scenes.map { scene -> Clip in
                    let text = scene.texto ?? ""
                    let words = Double(max(1, text.split(whereSeparator: \.isWhitespace).count))
                    let seconds = min(
                        maximumPreviewSceneSeconds,
                        max(minimumPreviewSceneSeconds, scene.segundos ?? (words / wordsPerSecond + previewScenePadding)))
                    return Clip(page: account.videoFolder.appendingPathComponent(scene.archivo), seconds: seconds, words: [])
                }
                result = (try await finish(account, clips: clips, voice: nil, to: preview(account)), nil)
            } catch {
                result = (nil, error.localizedDescription)
            }
            if let problem = result.1 { log.write("Contenido (\(account.id)): no salió la vista previa: \(problem)") }
            await completion(result.0, result.1)
        }
    }

    public static func renderWithVoice(
        _ account: ContentAccount, recording: URL,
        completion: @escaping VideoCompletion
    ) {
        Task.detached(priority: .utility) {
            let result: (URL?, String?)
            do {
                result = (try await voicedVideo(account, recording: recording), nil)
            } catch {
                result = (nil, error.localizedDescription)
            }
            if let problem = result.1 { log.write("Contenido (\(account.id)): no salió el video con tu voz: \(problem)") }
            await completion(result.0, result.1)
        }
    }

    static func voicedVideo(_ account: ContentAccount, recording: URL) async throws -> URL {
        let script = try loadScript(account)
        let voice = account.videoFolder.appendingPathComponent("mi-voz.m4a")
        try AudioTools.prepareVoice(recording, to: voice)
        guard let duration = VoiceListener.duration(voice) else { throw Problem(message: String(localized: "el audio llegó vacío")) }
        let heard = VoiceListener.words(in: voice)
        let texts = script.scenes.map { $0.texto ?? "" }
        let timings = ScriptAligner.align(texts, heard: heard, pauses: AudioTools.pauses(in: voice), duration: duration)
        let cuts = timings.map { String(format: "%.1f", $0.start) }.joined(separator: ", ")
        log.write("Contenido (\(account.id)): cortes de escena en \(cuts) s")
        let clips = zip(script.scenes, timings).map { scene, timing in
            Clip(
                page: account.videoFolder.appendingPathComponent(scene.archivo), seconds: timing.end - timing.start,
                words: account.captions ? timing.words : [])
        }
        log.write("Contenido (\(account.id)): tu voz dura \(Int(duration)) s")
        return try await finish(account, clips: clips, voice: voice, to: output(account))
    }

    static func finish(_ account: ContentAccount, clips: [Clip], voice: URL?, to target: URL) async throws -> URL {
        let folder = account.videoFolder
        let silent = folder.appendingPathComponent("grabando.mp4")
        try? FileManager.default.removeItem(at: silent)
        try? FileManager.default.removeItem(at: target)
        log.write("Contenido (\(account.id)): grabando \(clips.count) escenas" + (voice == nil ? " (vista previa sin voz)" : " con tu voz"))
        let animated = try await writeVideo(clips, accent: color(account.palette.accent), to: silent)
        let music = Self.music(for: account)
        if voice != nil || music != nil {
            try await mix(video: silent, voice: voice, music: music, to: target)
            try? FileManager.default.removeItem(at: silent)
        } else {
            try FileManager.default.moveItem(at: silent, to: target)
        }
        let total = clips.reduce(0) { $0 + $1.seconds }
        let extras =
            (voice == nil ? String(localized: " sin voz") : String(localized: " con tu voz"))
            + (music == nil ? "" : String(localized: " y música"))
        log.write("Contenido (\(account.id)): video de \(clips.count) escenas (\(animated) animadas) y \(Int(total)) s listo\(extras)")
        return target
    }
}
