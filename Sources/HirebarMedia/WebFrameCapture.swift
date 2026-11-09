import AppKit
import HirebarDomain
import WebKit

/// Graba una escena HTML animada cuadro por cuadro con el motor web de macOS.
/// Las animaciones CSS se pausan y se llevan al instante exacto de cada cuadro, así el video sale fluido
/// sin importar lo que tarde cada captura. Se llama desde un hilo de fondo; el trabajo web corre en el principal.
public final class WebFrameCapture: NSObject, WKNavigationDelegate {
    private let size: CGSize
    private var window: NSWindow?
    private var webView: WKWebView?
    private var onLoad: ((Bool) -> Void)?

    public init(width: Int, height: Int) {
        size = CGSize(width: width, height: height)
    }

    /// Carga la escena con su duración (variable CSS --dur, en segundos). Devuelve false si no cargó.
    public func load(_ page: URL, seconds: Double) -> Bool {
        let done = DispatchSemaphore(value: 0)
        var ok = false
        DispatchQueue.main.async {
            let configuration = WKWebViewConfiguration()
            configuration.userContentController.addUserScript(
                WKUserScript(source: Self.prelude(seconds), injectionTime: .atDocumentStart, forMainFrameOnly: true))
            let view = WKWebView(frame: NSRect(origin: .zero, size: self.size), configuration: configuration)
            view.navigationDelegate = self
            if self.window == nil {
                let window = NSWindow(contentRect: NSRect(x: -30000, y: -30000, width: self.size.width, height: self.size.height),
                                      styleMask: .borderless, backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.ignoresMouseEvents = true
                self.window = window
            }
            self.window?.contentView = view
            self.window?.orderBack(nil)
            self.webView = view
            self.onLoad = { success in
                ok = success
                done.signal()
            }
            view.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }
        guard done.wait(timeout: .now() + 30) == .success, ok else { return false }
        return run("await document.fonts.ready; return true;")
    }

    /// Imagen de la escena en el segundo t.
    func frame(at t: Double) -> CGImage? {
        guard run("window.__hirebarSeek(t); return true;", ["t": t]) else { return nil }
        let done = DispatchSemaphore(value: 0)
        var image: CGImage?
        DispatchQueue.main.async {
            guard let view = self.webView else {
                done.signal()
                return
            }
            let configuration = WKSnapshotConfiguration()
            configuration.afterScreenUpdates = false
            let scale = self.window?.backingScaleFactor ?? 1
            configuration.snapshotWidth = NSNumber(value: Double(self.size.width / scale))
            view.takeSnapshot(with: configuration) { snapshot, _ in
                image = snapshot?.cgImage(forProposedRect: nil, context: nil, hints: nil)
                done.signal()
            }
        }
        guard done.wait(timeout: .now() + 10) == .success else { return nil }
        return image
    }

    public func close() {
        DispatchQueue.main.async {
            self.webView?.navigationDelegate = nil
            self.window?.contentView = nil
            self.window?.orderOut(nil)
            self.webView = nil
            self.window = nil
        }
    }

    private func run(_ body: String, _ arguments: [String: Any] = [:]) -> Bool {
        let done = DispatchSemaphore(value: 0)
        var ok = false
        DispatchQueue.main.async {
            guard let view = self.webView else {
                done.signal()
                return
            }
            view.callAsyncJavaScript(body, arguments: arguments, in: nil, in: .page) { result in
                if case .success = result { ok = true }
                done.signal()
            }
        }
        guard done.wait(timeout: .now() + 10) == .success else { return false }
        return ok
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoad?(true)
        onLoad = nil
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onLoad?(false)
        onLoad = nil
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        onLoad?(false)
        onLoad = nil
    }

    /// Se inyecta antes que la página: deja --dur y la función que lleva todas las animaciones al instante t.
    public static func prelude(_ seconds: Double) -> String {
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
