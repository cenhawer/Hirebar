import Foundation
import HirebarApplication

extension Housekeeping {
    static let recordingPrefixes = ["grabacion.", "mi-voz."]
    static let generatedVideos: Set<String> = ["reel.mp4", "vista-previa.mp4"]
    static let discardedDraftPrefix = "descartado-"
    static let discardedEmailsPrefix = "descartados-"

    static func removeMedia(policy: RetentionPolicy, now: Date) -> [String] {
        var notes: [String] = []
        let accounts = (try? FileManager.default.contentsOfDirectory(at: Paths.content, includingPropertiesForKeys: nil)) ?? []
        var recordings = 0
        var videos = 0
        var drafts = 0
        for account in accounts where account.hasDirectoryPath {
            let video = account.appendingPathComponent("video", isDirectory: true)
            recordings += removeOlder(than: policy.recordings, in: video, now: now) { name in
                recordingPrefixes.contains { name.hasPrefix($0) }
            }
            videos += removeOlder(than: policy.videos, in: video, now: now) { generatedVideos.contains($0) }
            drafts += removeOlder(than: policy.discarded, in: account, now: now) { $0.hasPrefix(discardedDraftPrefix) }
        }
        let emails = removeOlder(than: policy.discarded, in: Paths.prospecting, now: now) { $0.hasPrefix(discardedEmailsPrefix) }
        if recordings > 0 { notes.append(String(localized: "\(recordings) grabaciones de voz")) }
        if videos > 0 { notes.append(String(localized: "\(videos) videos armados")) }
        if drafts + emails > 0 { notes.append(String(localized: "\(drafts + emails) borradores y listas descartadas")) }
        return notes
    }

    static func removeOlder(than age: TimeInterval, in folder: URL, now: Date, matching include: (String) -> Bool = { _ in true }) -> Int {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return 0
        }
        var removed = 0
        for file in files where include(file.lastPathComponent) {
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
            if now.timeIntervalSince(date) > age, (try? manager.removeItem(at: file)) != nil {
                removed += 1
            }
        }
        return removed
    }
}
