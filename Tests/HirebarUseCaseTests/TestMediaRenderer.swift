import Foundation
import HirebarApplication
import HirebarDomain

final class TestMediaRenderer: MediaRenderer {
    var audio = AudioCheck.accepted
    private(set) var preparedSlides: [String] = []

    func prepareSlides(for account: ContentAccount) { preparedSlides.append(account.id) }
    func renderSlides(for account: ContentAccount, completion: @escaping (_ made: [URL], _ failed: Int) -> Void) { completion([], 0) }
    func renderVideoPreview(for account: ContentAccount, completion: @escaping (_ video: URL?, _ problem: String?) -> Void) {
        completion(nil, nil)
    }
    func renderVideoWithVoice(
        for account: ContentAccount, recording: URL, completion: @escaping (_ video: URL?, _ problem: String?) -> Void
    ) { completion(nil, nil) }
    func readingScript(for account: ContentAccount) -> String? { nil }
    func renderCVs(for profile: Profile, completion: @escaping (CVRenderResult) -> Void) { completion(CVRenderResult()) }
    func audioCheck(bytes: Int?, seconds: Int?) -> AudioCheck { audio }
    func maxAudioBytes() -> Int? { nil }
}
