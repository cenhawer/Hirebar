import AppKit
import HirebarDomain
import WebKit

@MainActor
public final class WebFrameCapture: NSObject, WKNavigationDelegate {
    static let loadTimeout: Duration = .seconds(30)
    private let size: CGSize
    private var window: NSWindow?
    private var webView: WKWebView?
    private var pendingLoad: CheckedContinuation<Bool, Never>?
    private var loadNumber = 0

    public init(width: Int, height: Int) {
        size = CGSize(width: width, height: height)
    }

    public func load(_ page: URL, seconds: Double) async -> Bool {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(
            WKUserScript(source: Self.prelude(seconds), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let view = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: configuration)
        view.navigationDelegate = self
        hostingWindow().contentView = view
        window?.orderBack(nil)
        webView = view
        loadNumber += 1
        let number = loadNumber
        let loaded = await withCheckedContinuation { continuation in
            pendingLoad = continuation
            view.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
            Task { [weak self] in
                try? await Task.sleep(for: Self.loadTimeout)
                guard let self, self.loadNumber == number else { return }
                self.finishLoad(false)
            }
        }
        guard loaded else { return false }
        return await run("await document.fonts.ready; return true;")
    }

    func frame(at second: Double) async -> CGImage? {
        guard await run("window.__hirebarSeek(t); return true;", ["t": second]), let view = webView else { return nil }
        let configuration = WKSnapshotConfiguration()
        configuration.afterScreenUpdates = false
        let scale = window?.backingScaleFactor ?? 1
        configuration.snapshotWidth = NSNumber(value: Double(size.width / scale))
        let snapshot = try? await view.takeSnapshot(configuration: configuration)
        return snapshot?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    public func close() {
        finishLoad(false)
        webView?.navigationDelegate = nil
        window?.contentView = nil
        window?.orderOut(nil)
        webView = nil
        window = nil
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishLoad(true)
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishLoad(false)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishLoad(false)
    }

    private func hostingWindow() -> NSWindow {
        if let window { return window }
        let created = NSWindow(
            contentRect: NSRect(x: -30000, y: -30000, width: size.width, height: size.height), styleMask: .borderless,
            backing: .buffered, defer: false)
        created.isReleasedWhenClosed = false
        created.ignoresMouseEvents = true
        window = created
        return created
    }

    private func finishLoad(_ loaded: Bool) {
        pendingLoad?.resume(returning: loaded)
        pendingLoad = nil
    }

    private func run(_ body: String, _ arguments: [String: Any] = [:]) async -> Bool {
        guard let view = webView else { return false }
        do {
            _ = try await view.callAsyncJavaScript(body, arguments: arguments, contentWorld: .page)
            return true
        } catch {
            return false
        }
    }

    public nonisolated static func prelude(_ seconds: Double) -> String {
        """
        document.documentElement.style.setProperty('--dur', '\(seconds)');
        window.__hirebarSeek = function (t) {
          document.documentElement.style.setProperty('--t', String(t));
          document.getAnimations().forEach(function (a) { a.pause(); a.currentTime = t * 1000; });
          if (typeof window.onFrame === 'function') { window.onFrame(t, \(seconds)); }
          void document.documentElement.offsetHeight;
        };
        """
    }
}
