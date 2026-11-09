import AVFoundation
import AppKit
import CoreGraphics
import Foundation
import HirebarApplication
import HirebarDomain
import HirebarNotifications
import HirebarPortals
import HirebarStorage
import HirebarTelegram
import ImageIO

private let log = Log(.media)

public enum ReelRenderer {
    static let width = 1080
    static let height = 1920
    static let fps: Int32 = 30
    static let captionCenterFromTop = 1300.0
    static let wordsPerCaption = 3
    static let musicVolume: Float = 0.10
    /// Palabras por segundo al leer en voz alta con energía (para la vista previa).
    static let wordsPerSecond = 2.7

    struct Scene: Decodable {
        let archivo: String
        let texto: String?
        let segundos: Double?
    }

    struct Script: Decodable {
        let escenas: [Scene]
        let tono: String?
    }

    struct Clip {
        let page: URL
        let seconds: Double
        let words: [WordTiming]
    }

    struct Problem: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Video final, narrado con la voz de la persona.
    public static func output(_ account: ContentAccount) -> URL {
        account.videoFolder.appendingPathComponent("reel.mp4")
    }

    /// Vista previa sin voz.
    public static func preview(_ account: ContentAccount) -> URL {
        account.videoFolder.appendingPathComponent("vista-previa.mp4")
    }

    static func loadScript(_ account: ContentAccount) throws -> (scenes: [Scene], tone: String?) {
        let folder = account.videoFolder
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("guion.json")),
              let script = try? JSONDecoder().decode(Script.self, from: data) else {
            throw Problem(message: "\(AI.name) no dejó el guion del video (video/guion.json)")
        }
        let scenes = script.escenas.filter { FileManager.default.fileExists(atPath: folder.appendingPathComponent($0.archivo).path) }
        guard !scenes.isEmpty else { throw Problem(message: "no encontré las escenas del video") }
        return (scenes, script.tono)
    }

    /// Guion para leer en voz alta, escena por escena, listo para mandar a Telegram.
    public static func readingScript(_ account: ContentAccount) -> String? {
        guard let script = try? loadScript(account) else { return nil }
        let texts = script.scenes.compactMap { $0.texto?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !texts.isEmpty else { return nil }
        let words = texts.map { $0.split(whereSeparator: \.isWhitespace).count }.reduce(0, +)
        let seconds = Int((Double(words) / wordsPerSecond).rounded())
        var lines = ["Guion para grabar (\(account.title)), unos \(seconds) segundos:", ""]
        if let tone = script.tone, !tone.isEmpty { lines += ["Tono: \(tone)", ""] }
        for (index, text) in texts.enumerated() { lines.append("\(index + 1). \(text)") }
        lines += ["", "Léelo de corrido, sin decir los números, con energía y sonriendo (se nota en la voz). Si te equivocas, sigue: Hirebar acomoda las escenas a tu ritmo.",
                  "Responde a este chat con una nota de voz y te devuelvo el video con tu voz, listo para subir."]
        return lines.joined(separator: "\n")
    }

    /// Arma la vista previa sin voz (duración estimada de cada frase).
    public static func renderPreview(_ account: ContentAccount, completion: @escaping (_ video: URL?, _ problem: String?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let result: (URL?, String?)
            do {
                let script = try loadScript(account)
                let clips = script.scenes.map { scene -> Clip in
                    let text = scene.texto ?? ""
                    let words = Double(max(1, text.split(whereSeparator: \.isWhitespace).count))
                    let seconds = min(12, max(1.5, scene.segundos ?? (words / wordsPerSecond + 0.3)))
                    return Clip(page: account.videoFolder.appendingPathComponent(scene.archivo), seconds: seconds, words: [])
                }
                result = (try finish(account, clips: clips, voice: nil, to: preview(account)), nil)
            } catch {
                result = (nil, error.localizedDescription)
            }
            if let problem = result.1 { log.write("Contenido (\(account.id)): no salió la vista previa: \(problem)") }
            DispatchQueue.main.async { completion(result.0, result.1) }
        }
    }

    /// Arma el video final con la nota de voz de la persona.
    public static func renderWithVoice(_ account: ContentAccount, recording: URL,
                                       completion: @escaping (_ video: URL?, _ problem: String?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let result: (URL?, String?)
            do {
                let script = try loadScript(account)
                let voice = account.videoFolder.appendingPathComponent("mi-voz.m4a")
                try AudioTools.prepareVoice(recording, to: voice)
                guard let duration = VoiceListener.duration(voice) else { throw Problem(message: "el audio llegó vacío") }
                let heard = VoiceListener.words(in: voice)
                let texts = script.scenes.map { $0.texto ?? "" }
                let timings = ScriptAligner.align(texts, heard: heard, pauses: AudioTools.pauses(in: voice), duration: duration)
                let cuts = timings.map { String(format: "%.1f", $0.start) }.joined(separator: ", ")
                log.write("Contenido (\(account.id)): cortes de escena en \(cuts) s")
                let clips = zip(script.scenes, timings).map { scene, timing in
                    Clip(page: account.videoFolder.appendingPathComponent(scene.archivo), seconds: timing.end - timing.start,
                         words: account.captions ? timing.words : [])
                }
                log.write("Contenido (\(account.id)): tu voz dura \(Int(duration)) s")
                result = (try finish(account, clips: clips, voice: voice, to: output(account)), nil)
            } catch {
                result = (nil, error.localizedDescription)
            }
            if let problem = result.1 { log.write("Contenido (\(account.id)): no salió el video con tu voz: \(problem)") }
            DispatchQueue.main.async { completion(result.0, result.1) }
        }
    }

    /// Graba las escenas y les pone la voz (si hay) y la música (si hay).
    static func finish(_ account: ContentAccount, clips: [Clip], voice: URL?, to target: URL) throws -> URL {
        let folder = account.videoFolder
        let silent = folder.appendingPathComponent("grabando.mp4")
        try? FileManager.default.removeItem(at: silent)
        try? FileManager.default.removeItem(at: target)
        log.write("Contenido (\(account.id)): grabando \(clips.count) escenas" + (voice == nil ? " (vista previa sin voz)" : " con tu voz"))
        let animated = try writeVideo(clips, accent: color(account.palette.accent), to: silent)
        let music = account.music
        if voice != nil || music != nil {
            try mix(video: silent, voice: voice, music: music, to: target)
            try? FileManager.default.removeItem(at: silent)
        } else {
            try FileManager.default.moveItem(at: silent, to: target)
        }
        let total = clips.reduce(0) { $0 + $1.seconds }
        let extras = (voice == nil ? " sin voz" : " con tu voz") + (music == nil ? "" : " y música")
        log.write("Contenido (\(account.id)): video de \(clips.count) escenas (\(animated) animadas) y \(Int(total)) s listo\(extras)")
        return target
    }

    /// Escribe el video sin sonido. Devuelve cuántas escenas salieron animadas.
    static func writeVideo(_ clips: [Clip], accent: NSColor, to url: URL) throws -> Int {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        guard writer.canAdd(input) else { throw Problem(message: "no se pudo preparar el video") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? Problem(message: "no se pudo empezar el video") }
        writer.startSession(atSourceTime: .zero)

        let capture = WebFrameCapture(width: width, height: height)
        defer { capture.close() }
        let chrome = CVRenderer.chromePath()
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-chrome", isDirectory: true)
        var animated = 0
        var frameIndex: Int64 = 0
        for (number, clip) in clips.enumerated() {
            let count = max(1, Int((clip.seconds * Double(fps)).rounded()))
            let started = Date()
            // Animada: se graba cuadro por cuadro. Si no carga o no da imagen, queda fija (Chrome) con acercamiento.
            var live = capture.load(clip.page, seconds: clip.seconds)
            var still: CGImage?
            if live, capture.frame(at: 0) == nil { live = false }
            if !live, let chrome { still = stillImage(clip.page, chrome: chrome, scratch: scratch) }
            if live {
                animated += 1
            } else {
                log.write("Contenido: la escena \(clip.page.lastPathComponent) sale fija (no se pudo animar)")
            }
            for frame in 0..<count {
                let elapsed = Double(frame) / Double(fps)
                var image: CGImage?
                var zoom = 1.0
                if live {
                    image = capture.frame(at: elapsed)
                    if image == nil {
                        // Si el Mac deja de dar cuadros, la escena sigue fija para no quedarse esperando.
                        live = false
                        let second = String(format: "%.1f", elapsed)
                        log.write("Contenido: la escena \(clip.page.lastPathComponent) dejó de animarse en el segundo \(second)")
                    }
                }
                if image == nil {
                    if still == nil, let chrome { still = stillImage(clip.page, chrome: chrome, scratch: scratch) }
                    image = still
                    zoom = 1.0 + 0.035 * (elapsed / clip.seconds)
                }
                guard let image else { throw Problem(message: "no se pudo dibujar la escena \(clip.page.lastPathComponent)") }
                let caption = captionWords(clip.words, at: elapsed)
                while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
                guard let buffer = pixelBuffer(pool: adaptor.pixelBufferPool, image: image, zoom: zoom,
                                               caption: caption, accent: accent) else {
                    throw Problem(message: "no se pudo dibujar un cuadro del video")
                }
                adaptor.append(buffer, withPresentationTime: CMTime(value: frameIndex, timescale: fps))
                frameIndex += 1
            }
            let kind = live ? "animada" : "fija"
            let seconds = Int(Date().timeIntervalSince(started))
            log.write("Contenido: escena \(number + 1) de \(clips.count) grabada (\(kind), \(count) cuadros en \(seconds) s)")
        }
        input.markAsFinished()
        let done = DispatchSemaphore(value: 0)
        writer.finishWriting { done.signal() }
        done.wait()
        guard writer.status == .completed else { throw writer.error ?? Problem(message: "no se pudo terminar el video") }
        return animated
    }

    static func stillImage(_ page: URL, chrome: String, scratch: URL) -> CGImage? {
        let png = page.deletingPathExtension().appendingPathExtension("png")
        guard SlideRenderer.shoot(page, to: png, chrome: chrome, scratch: scratch, width: width, height: height),
              let source = CGImageSourceCreateWithURL(png as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Grupo de palabras que se ve en pantalla en ese momento y cuál de ellas está sonando.
    static func captionWords(_ words: [WordTiming], at elapsed: Double) -> (words: [String], active: Int)? {
        guard let first = words.first, elapsed >= first.start - 0.05 else { return nil }
        var active = words.count - 1
        for (index, word) in words.enumerated() where elapsed < word.end {
            active = index
            break
        }
        let start = (active / wordsPerCaption) * wordsPerCaption
        let end = min(words.count, start + wordsPerCaption)
        return (words[start..<end].map(\.word), active - start)
    }

    static func pixelBuffer(pool: CVPixelBufferPool?, image: CGImage, zoom: Double,
                            caption: (words: [String], active: Int)?, accent: NSColor) -> CVPixelBuffer? {
        var created: CVPixelBuffer?
        if let pool {
            _ = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &created)
        } else {
            _ = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32ARGB, nil, &created)
        }
        guard let buffer = created else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
        context.interpolationQuality = .high
        let w = Double(width) * zoom
        let h = Double(height) * zoom
        context.draw(image, in: CGRect(x: (Double(width) - w) / 2, y: (Double(height) - h) / 2, width: w, height: h))
        if let caption { drawCaption(caption.words, active: caption.active, accent: accent, in: context) }
        return buffer
    }

    static func drawCaption(_ words: [String], active: Int, accent: NSColor, in context: CGContext) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.7)
        shadow.shadowBlurRadius = 14
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        let font = NSFont.systemFont(ofSize: 84, weight: .heavy)
        let text = NSMutableAttributedString()
        for (index, word) in words.enumerated() {
            text.append(NSAttributedString(string: (index == 0 ? "" : " ") + word, attributes: [
                .font: font,
                .foregroundColor: index == active ? accent : NSColor.white,
                .strokeColor: NSColor.black,
                .strokeWidth: -6,
                .paragraphStyle: paragraph,
                .shadow: shadow,
            ]))
        }
        let margin = 90.0
        let box = CGSize(width: Double(width) - margin * 2, height: 600)
        let bounds = text.boundingRect(with: box, options: [.usesLineFragmentOrigin, .usesFontLeading])
        let rect = CGRect(x: margin, y: Double(height) - captionCenterFromTop - bounds.height / 2,
                          width: box.width, height: bounds.height + 12)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        text.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.restoreGraphicsState()
    }

    static func color(_ hex: String) -> NSColor {
        let clean = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard clean.count == 6, let value = UInt32(clean, radix: 16) else { return .systemYellow }
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    // MARK: - Sonido

    static func mix(video: URL, voice: URL?, music: URL?, to target: URL) throws {
        let composition = AVMutableComposition()
        let videoAsset = AVURLAsset(url: video)
        guard let source = videoAsset.tracks(withMediaType: .video).first,
              let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw Problem(message: "no se pudo leer el video para ponerle el sonido")
        }
        let total = videoAsset.duration
        try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: total), of: source, at: .zero)

        if let voice, let voiceTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let asset = AVURLAsset(url: voice)
            if let track = asset.tracks(withMediaType: .audio).first {
                let length = CMTimeMinimum(asset.duration, total)
                try? voiceTrack.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: track, at: .zero)
            }
        }

        var parameters: [AVMutableAudioMixInputParameters] = []
        if let music, let musicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let asset = AVURLAsset(url: music)
            if let track = asset.tracks(withMediaType: .audio).first, asset.duration.seconds > 1 {
                var at = CMTime.zero
                while CMTimeCompare(at, total) < 0 {
                    let length = CMTimeMinimum(asset.duration, CMTimeSubtract(total, at))
                    try? musicTrack.insertTimeRange(CMTimeRange(start: .zero, duration: length), of: track, at: at)
                    at = CMTimeAdd(at, length)
                }
                let volume = AVMutableAudioMixInputParameters(track: musicTrack)
                volume.setVolume(voice == nil ? 0.6 : musicVolume, at: .zero)
                parameters.append(volume)
            }
        }

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw Problem(message: "no se pudo preparar la exportación del video")
        }
        export.outputURL = target
        export.outputFileType = .mp4
        if !parameters.isEmpty {
            let audioMix = AVMutableAudioMix()
            audioMix.inputParameters = parameters
            export.audioMix = audioMix
        }
        let done = DispatchSemaphore(value: 0)
        export.exportAsynchronously { done.signal() }
        done.wait()
        guard export.status == .completed else {
            throw export.error ?? Problem(message: "no se pudo exportar el video")
        }
    }
}
