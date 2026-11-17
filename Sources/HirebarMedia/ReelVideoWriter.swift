import AVFoundation
import AppKit
import Foundation
import HirebarApplication

private let log = Log(.media)

extension ReelRenderer {
    static let bitRate = 10_000_000
    static let stillZoom = 0.035
    static let writerPoll: Duration = .milliseconds(5)

    static func writeVideo(_ clips: [Clip], accent: NSColor, to url: URL) async throws -> Int {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
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
        guard writer.canAdd(input) else { throw Problem(message: String(localized: "no se pudo preparar el video")) }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? Problem(message: String(localized: "no se pudo empezar el video")) }
        writer.startSession(atSourceTime: .zero)
        let capture = await WebFrameCapture(width: width, height: height)
        let animated: Int
        do {
            animated = try await record(clips, capture: capture, input: input, adaptor: adaptor, accent: accent)
            await capture.close()
        } catch {
            await capture.close()
            throw error
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? Problem(message: String(localized: "no se pudo terminar el video")) }
        return animated
    }

    static func record(
        _ clips: [Clip], capture: WebFrameCapture, input: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor,
        accent: NSColor
    ) async throws -> Int {
        var recorder = SceneRecorder(capture: capture, input: input, adaptor: adaptor, accent: accent)
        for (number, clip) in clips.enumerated() {
            let started = Date()
            let outcome = try await recorder.record(clip)
            let seconds = Int(Date().timeIntervalSince(started))
            let kind = outcome.live ? "animada" : "fija"
            log.write("Contenido: escena \(number + 1) de \(clips.count) grabada (\(kind), \(outcome.frames) cuadros en \(seconds) s)")
        }
        return recorder.animated
    }
}

struct SceneRecorder {
    let capture: WebFrameCapture
    let input: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
    let accent: NSColor
    let chrome = CVRenderer.chromePath()
    let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-chrome", isDirectory: true)
    var animated = 0
    var frameIndex: Int64 = 0

    init(capture: WebFrameCapture, input: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor, accent: NSColor) {
        self.capture = capture
        self.input = input
        self.adaptor = adaptor
        self.accent = accent
    }

    mutating func record(_ clip: ReelRenderer.Clip) async throws -> (live: Bool, frames: Int) {
        let count = max(1, Int((clip.seconds * Double(ReelRenderer.fps)).rounded()))
        var live = await capture.load(clip.page, seconds: clip.seconds)
        if live, await capture.frame(at: 0) == nil { live = false }
        var still = live ? nil : stillImage(clip)
        if live {
            animated += 1
        } else {
            log.write("Contenido: la escena \(clip.page.lastPathComponent) sale fija (no se pudo animar)")
        }
        for frame in 0..<count {
            let elapsed = Double(frame) / Double(ReelRenderer.fps)
            var image = live ? await capture.frame(at: elapsed) : nil
            if live && image == nil {
                live = false
                let second = String(format: "%.1f", elapsed)
                log.write("Contenido: la escena \(clip.page.lastPathComponent) dejó de animarse en el segundo \(second)")
            }
            var zoom = 1.0
            if image == nil {
                still = still ?? stillImage(clip)
                image = still
                zoom = 1.0 + ReelRenderer.stillZoom * (elapsed / clip.seconds)
            }
            guard let image else {
                throw ReelRenderer.Problem(message: String(localized: "no se pudo dibujar la escena \(clip.page.lastPathComponent)"))
            }
            try await append(image, zoom: zoom, caption: ReelRenderer.captionWords(clip.words, at: elapsed))
        }
        return (live, count)
    }

    func stillImage(_ clip: ReelRenderer.Clip) -> CGImage? {
        chrome.flatMap { ReelRenderer.stillImage(clip.page, chrome: $0, scratch: scratch) }
    }

    mutating func append(_ image: CGImage, zoom: Double, caption: (words: [String], active: Int)?) async throws {
        while !input.isReadyForMoreMediaData { try await Task.sleep(for: ReelRenderer.writerPoll) }
        guard
            let buffer = ReelRenderer.pixelBuffer(
                pool: adaptor.pixelBufferPool, image: image, zoom: zoom, caption: caption, accent: accent)
        else {
            throw ReelRenderer.Problem(message: String(localized: "no se pudo dibujar un cuadro del video"))
        }
        adaptor.append(buffer, withPresentationTime: CMTime(value: frameIndex, timescale: ReelRenderer.fps))
        frameIndex += 1
    }
}
