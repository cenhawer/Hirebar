import Foundation
import HirebarApplication
import HirebarDomain

public struct SystemMediaRenderer: MediaRenderer {
    public init() {}

    public func prepareSlides(for account: ContentAccount) {
        SlideRenderer.prepare(account)
    }

    public func renderSlides(for account: ContentAccount, completion: @escaping (_ made: [URL], _ failed: Int) -> Void) {
        SlideRenderer.renderAll(account, completion: completion)
    }

    public func renderVideoPreview(for account: ContentAccount, completion: @escaping (_ video: URL?, _ problem: String?) -> Void) {
        ReelRenderer.renderPreview(account, completion: completion)
    }

    public func renderVideoWithVoice(
        for account: ContentAccount, recording: URL, completion: @escaping (_ video: URL?, _ problem: String?) -> Void
    ) {
        ReelRenderer.renderWithVoice(account, recording: recording, completion: completion)
    }

    public func readingScript(for account: ContentAccount) -> String? {
        ReelRenderer.readingScript(account)
    }

    public func renderCVs(for profile: Profile, completion: @escaping (CVRenderResult) -> Void) {
        CVRenderer.renderAll(profile, completion: completion)
    }

    public func audioCheck(bytes: Int?, seconds: Int?) -> AudioCheck {
        guard let tools = try? SystemTools.bundled() else { return .toolsMissing }
        guard tools.ffmpegPath() != nil else { return .ffmpegMissing(install: tools.ffmpeg.install) }
        guard tools.acceptsAudio(bytes: bytes, seconds: seconds) else {
            return .tooLong(minutes: tools.maxAudioSeconds / 60, megabytes: tools.maxAudioMegabytes)
        }
        return .accepted
    }

    public func maxAudioBytes() -> Int? {
        (try? SystemTools.bundled())?.maxAudioBytes
    }
}
