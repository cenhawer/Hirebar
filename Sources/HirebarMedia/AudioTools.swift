import Foundation
import HirebarApplication
import HirebarDomain

private let log = Log(.media)

public enum AudioTools {
    public static var legacyFolder: URL { Paths.root.appendingPathComponent("herramientas", isDirectory: true) }

    public struct Problem: LocalizedError {
        let message: String
        public var errorDescription: String? { message }
    }

    public static func ffmpeg() throws -> String {
        guard let tools = try? SystemTools.bundled() else {
            throw Problem(message: "falta herramientas.json dentro de la app; vuelve a instalarla con scripts/bundle.sh --install")
        }
        guard let path = tools.ffmpegPath() else {
            throw Problem(message: "falta ffmpeg en el Mac. Instálalo con: \(tools.ffmpeg.install)")
        }
        return path
    }

    public static func removeLegacyCopy() {
        guard FileManager.default.fileExists(atPath: legacyFolder.path) else { return }
        try? FileManager.default.removeItem(at: legacyFolder)
        log.write("Contenido: borré la copia de ffmpeg que Hirebar instalaba con Python; ahora usa la del sistema")
    }

    public static func prepareVoice(_ input: URL, to output: URL) throws {
        let tool = try ffmpeg()
        try? FileManager.default.removeItem(at: output)
        let trim = "silenceremove=start_periods=1:start_threshold=-42dB:start_silence=0.08,"
            + "areverse,silenceremove=start_periods=1:start_threshold=-42dB:start_silence=0.15,areverse,"
            + "silenceremove=stop_periods=-1:stop_duration=0.45:stop_threshold=-40dB:stop_silence=0.3"
        let filters = "highpass=f=80,\(trim),afftdn=nf=-25,acompressor=threshold=-18dB:ratio=3:attack=5:release=60,loudnorm=I=-14:TP=-1.5:LRA=11"
        var result = run(tool, ["-y", "-i", input.path, "-vn", "-af", filters, "-ar", "48000", "-ac", "1",
                                "-c:a", "aac", "-b:a", "192k", output.path], timeout: 180)
        if !result.ok {
            // Si algún filtro no está disponible, al menos se convierte.
            result = run(tool, ["-y", "-i", input.path, "-vn", "-ar", "48000", "-ac", "1", "-c:a", "aac", "-b:a", "192k", output.path],
                         timeout: 180)
        }
        guard result.ok, FileManager.default.fileExists(atPath: output.path) else {
            throw Problem(message: "no pude convertir el audio (\(result.output.suffix(200)))")
        }
    }

    public static func pauses(in audio: URL) -> [VoicePause] {
        guard let tool = try? ffmpeg() else { return [] }
        let result = run(tool, ["-hide_banner", "-i", audio.path, "-af", "silencedetect=noise=-35dB:d=0.18", "-f", "null", "-"], timeout: 60)
        var found: [(Double, Double)] = []
        var open: Double?
        for line in result.output.split(separator: "\n") {
            if let range = line.range(of: "silence_start: ") {
                open = Double(line[range.upperBound...].split(separator: " ").first ?? "")
            } else if let range = line.range(of: "silence_end: "), let start = open,
                      let end = Double(line[range.upperBound...].split(separator: " ").first ?? "") {
                found.append((start, end))
                open = nil
            }
        }
        return found.map { VoicePause(start: $0.0, end: $0.1) }
    }

    public static func run(_ path: String, _ arguments: [String], timeout: TimeInterval) -> (ok: Bool, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return (false, "no se pudo ejecutar \(path)") }
        final class Box: @unchecked Sendable { var data = Data() }
        let box = Box()
        let reader = DispatchQueue(label: "hirebar.audio-tools.output")
        reader.async { box.data = pipe.fileHandleForReading.readDataToEndOfFile() }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
        reader.sync {}
        return (process.terminationStatus == 0, String(decoding: box.data, as: UTF8.self))
    }
}
