import Foundation
import HirebarDomain

public struct CVRenderResult: Sendable {
    public var made: [URL] = []
    public var missing: [String] = []
    public var failed: [String] = []

    public init(made: [URL] = [], missing: [String] = [], failed: [String] = []) {
        self.made = made
        self.missing = missing
        self.failed = failed
    }
}

public enum AudioCheck: Equatable, Sendable {
    case accepted
    case toolsMissing
    case ffmpegMissing(install: String)
    case tooLong(minutes: Int, megabytes: Int)
}

public protocol MediaRenderer {
    func prepareSlides(for account: ContentAccount)
    func renderSlides(for account: ContentAccount, completion: @escaping (_ made: [URL], _ failed: Int) -> Void)
    func renderVideoPreview(for account: ContentAccount, completion: @escaping (_ video: URL?, _ problem: String?) -> Void)
    func renderVideoWithVoice(
        for account: ContentAccount, recording: URL, completion: @escaping (_ video: URL?, _ problem: String?) -> Void)
    func readingScript(for account: ContentAccount) -> String?
    func renderCVs(for profile: Profile, completion: @escaping (CVRenderResult) -> Void)
    func audioCheck(bytes: Int?, seconds: Int?) -> AudioCheck
    func maxAudioBytes() -> Int?
}
