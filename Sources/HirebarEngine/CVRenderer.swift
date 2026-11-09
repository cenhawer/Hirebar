import Foundation
import HirebarCore
import HirebarDomain

public enum CVRenderer {
    public struct Result {
        public var made: [URL] = []
        public var missing: [String] = []
        public var failed: [String] = []
    }

    static let timeout: TimeInterval = 90
    static var htmlFolder: URL { Paths.workspace.appendingPathComponent("hv", isDirectory: true) }

    static func chromePath() -> String? {
        let home = Paths.home.path
        return [
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "\(home)/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Chromium.app/Contents/MacOS/Chromium",
            "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
        ].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public static func html(for variant: CVVariant) -> URL {
        htmlFolder.appendingPathComponent("\(variant.id).html")
    }

    public static func pdf(for variant: CVVariant) -> URL {
        Paths.workspaceFile("\(variant.file).pdf")
    }

    public static func renderAll(_ profile: Profile, completion: @escaping (Result) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            var result = Result()
            guard let chrome = chromePath() else {
                result.failed = profile.cvVariants.map(\.id)
                Log.write("Hojas de vida: no encontré Google Chrome para crear los PDF")
                DispatchQueue.main.async { completion(result) }
                return
            }
            let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("hirebar-chrome", isDirectory: true)
            for variant in profile.cvVariants {
                let source = html(for: variant)
                guard FileManager.default.fileExists(atPath: source.path) else {
                    result.missing.append(variant.id)
                    continue
                }
                let target = pdf(for: variant)
                if print(source, to: target, chrome: chrome, scratch: scratch) {
                    result.made.append(target)
                } else {
                    result.failed.append(variant.id)
                }
            }
            Log.write("Hojas de vida: \(result.made.count) PDF creados, faltan \(result.missing), fallaron \(result.failed)")
            DispatchQueue.main.async { completion(result) }
        }
    }

    static func print(_ source: URL, to target: URL, chrome: String, scratch: URL) -> Bool {
        let temporary = target.deletingPathExtension().appendingPathExtension("tmp.pdf")
        try? FileManager.default.removeItem(at: temporary)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: chrome)
        process.arguments = ["--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
                             "--user-data-dir=\(scratch.path)", "--no-pdf-header-footer", "--print-to-pdf-no-header",
                             "--print-to-pdf=\(temporary.path)", source.absoluteString]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.5) }
        if process.isRunning { process.terminate() }
        let size = (try? FileManager.default.attributesOfItem(atPath: temporary.path)[.size] as? NSNumber)?.intValue ?? 0
        guard size > 1000 else { return false }
        try? FileManager.default.removeItem(at: target)
        return (try? FileManager.default.moveItem(at: temporary, to: target)) != nil
    }
}
