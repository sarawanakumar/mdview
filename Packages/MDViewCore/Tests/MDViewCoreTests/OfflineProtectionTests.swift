import Foundation
import Network
import Testing
import WebKit
@testable import MDViewCore

/// ADR 0006, spec 9.1: the app has the outgoing-network entitlement only
/// because WebKit needs it, so these layers are what keep it offline. Each
/// is tested on its own in a real WKWebView.
///
/// Fully offline: the "remote" server is a tiny HTTP server on 127.0.0.1
/// that counts the requests it gets. A layer passes if the page makes no
/// request to it at all.
@Suite("Offline protection (9.1, ADR 0006)", .serialized)
@MainActor
struct OfflineProtectionTests {
    @Test(.timeLimit(.minutes(1)))
    func blockListAloneStopsEveryRemoteLoad() async throws {
        let requests = try await requestsMade(blockList: true, securityPolicy: false)
        #expect(requests == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func securityPolicyAloneStopsEveryRemoteLoad() async throws {
        let requests = try await requestsMade(blockList: false, securityPolicy: true)
        #expect(requests == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func bothLayersTogetherAsInTheApp() async throws {
        let requests = try await requestsMade(blockList: true, securityPolicy: true)
        #expect(requests == 0)
    }

    /// Control: with neither layer, the same page does reach the server, so
    /// a zero above really means "blocked", not "the test can't see it".
    @Test(.timeLimit(.minutes(1)))
    func withoutProtectionThePageWouldLoadRemoteContent() async throws {
        let requests = try await requestsMade(blockList: false, securityPolicy: false)
        #expect(requests > 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func pageScriptsNeverRun() async throws {
        let server = try await CountingServer.start()
        defer { server.stop() }
        let webView = try await makeWebView(blockList: false)
        let html = page(port: server.port, securityPolicy: false)
        try await load(html, in: webView)
        // The app's own script can still read the page; the page's can't run.
        let marker = try await webView.evaluateJavaScript("document.getElementById('js').textContent") as? String
        #expect(marker == "script did not run")
    }

    @Test func blockListCompiles() async throws {
        let store = try #require(WKContentRuleListStore(url: Self.temporaryStore()))
        let list = try await store.compileContentRuleList(
            forIdentifier: "compile-check", encodedContentRuleList: PageSecurity.blockList
        )
        #expect(list != nil)
    }

    // MARK: Helpers

    private func requestsMade(blockList: Bool, securityPolicy: Bool) async throws -> Int {
        let server = try await CountingServer.start()
        defer { server.stop() }
        let webView = try await makeWebView(blockList: blockList)
        try await load(page(port: server.port, securityPolicy: securityPolicy), in: webView)
        // Give any subresource requests time to arrive.
        try await Task.sleep(for: .milliseconds(800))
        return server.requestCount
    }

    /// The app's web view setup: page JavaScript off, nothing stored, our
    /// scheme, and (optionally) the block list.
    private func makeWebView(blockList: Bool) async throws -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(FailingSchemeHandler(), forURLScheme: PageSecurity.scheme)
        if blockList {
            let store = try #require(WKContentRuleListStore(url: Self.temporaryStore()))
            let rules = try #require(try await store.compileContentRuleList(
                forIdentifier: PageSecurity.blockListID, encodedContentRuleList: PageSecurity.blockList
            ))
            config.userContentController.add(rules)
        }
        return WKWebView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), configuration: config)
    }

    /// Every kind of remote load a page could try, all pointing at the
    /// counting server.
    private func page(port: UInt16, securityPolicy: Bool) -> String {
        let remote = "http://127.0.0.1:\(port)"
        let csp = securityPolicy
            ? "<meta http-equiv=\"Content-Security-Policy\" content=\"\(PageSecurity.contentSecurityPolicy)\">"
            : ""
        return """
            <!doctype html><html><head><meta charset="utf-8">\(csp)
            <link rel="stylesheet" href="\(remote)/style.css">
            <link rel="icon" href="\(remote)/favicon.ico">
            <style>
              body { background-image: url(\(remote)/background.png); }
              @font-face { font-family: Remote; src: url(\(remote)/font.woff2); }
              p { font-family: Remote; }
            </style>
            </head><body>
            <p id="js">script did not run</p>
            <script>document.getElementById('js').textContent = 'SCRIPT RAN'; fetch('\(remote)/fetch');</script>
            <script src="\(remote)/script.js"></script>
            <img src="\(remote)/image.png">
            <picture><source srcset="\(remote)/source.png"><img src="\(remote)/picture.png"></picture>
            <iframe src="\(remote)/frame.html"></iframe>
            <video src="\(remote)/video.mp4" preload="auto"></video>
            <audio src="\(remote)/audio.mp3" preload="auto"></audio>
            <object data="\(remote)/object.pdf"></object>
            </body></html>
            """
    }

    private func load(_ html: String, in webView: WKWebView) async throws {
        let waiter = NavigationWaiter()
        webView.navigationDelegate = waiter
        webView.loadHTMLString(html, baseURL: URL(string: "\(PageSecurity.scheme)://document/"))
        try await waiter.finished()
    }

    private static func temporaryStore() -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "mdview-rule-lists-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

// MARK: - Test helpers

/// Waits for a web view's page load to finish (or fail).
@MainActor
private final class NavigationWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, any Error>?
    private var result: Result<Void, any Error>?

    func finished() async throws {
        if let result { return try result.get() }
        try await withCheckedThrowingContinuation { continuation = $0 }
    }

    private func complete(_ result: Result<Void, any Error>) {
        guard self.result == nil else { return }
        self.result = result
        continuation?.resume(with: result)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { complete(.success(())) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) { complete(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        complete(.failure(error))
    }
}

/// Stands in for the app's scheme handler: serves nothing.
@MainActor
private final class FailingSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) { task.didFailWithError(URLError(.fileDoesNotExist)) }
    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}

/// A minimal HTTP server on 127.0.0.1 that answers every request with a
/// tiny empty response and counts them.
private final class CountingServer: @unchecked Sendable {
    private let listener: NWListener
    private let lock = NSLock()
    private var count = 0
    let port: UInt16

    var requestCount: Int { lock.withLock { count } }

    private init(listener: NWListener, port: UInt16) {
        self.listener = listener
        self.port = port
    }

    static func start() async throws -> CountingServer {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        let queue = DispatchQueue(label: "counting-server")
        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            nonisolated(unsafe) var resumed = false
            listener.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                case .ready:
                    resumed = true
                    continuation.resume(returning: listener.port?.rawValue ?? 0)
                case .failed(let error):
                    resumed = true
                    continuation.resume(throwing: error)
                default: break
                }
            }
            listener.newConnectionHandler = { _ in }
            listener.start(queue: queue)
        }
        let server = CountingServer(listener: listener, port: port)
        listener.newConnectionHandler = { [server] connection in server.handle(connection, on: queue) }
        return server
    }

    func stop() { listener.cancel() }

    private func handle(_ connection: NWConnection, on queue: DispatchQueue) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [self] data, _, _, _ in
            if let data, !data.isEmpty { lock.withLock { count += 1 } }
            let response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}
