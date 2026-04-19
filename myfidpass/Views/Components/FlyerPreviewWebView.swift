//
//  FlyerPreviewWebView.swift
//  myfidpass
//
//  Aperçu du flyer QR (même bundle canvas que myfidpass.fr/flyer-embed.html).
//  Une seule WKWebView : les changements réinjectent le JSON en JS (pas de reload → pas de flash noir).
//

import SwiftUI
import WebKit

struct FlyerPreviewWebView: UIViewRepresentable {
    /// Réponse JSON brute GET …/dashboard/flyer, encodée en base64 pour injection JS.
    let bootstrapBase64: String
    @Binding var isLoading: Bool
    /// Si `true` : le canvas ne remplit pas le dégradé de secours (fond IA affiché en **UIImage** sous la WebView).
    var skipCanvasSolidBackground: Bool = false
    /// Appelé quand la `WKWebView` est prête (aperçu plein écran : impression / capture).
    var onWebViewCreated: ((WKWebView) -> Void)? = nil

    /// Retire `custom_bg_data_url` du JSON pour alléger l’injection + mode « calque » natif sous la WebView.
    nonisolated static func stripCustomBgFromBootstrapBase64(_ b64: String) -> String? {
        guard let data = Data(base64Encoded: b64),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var fp = root["flyer_prefs"] as? [String: Any] else { return nil }
        fp.removeValue(forKey: "custom_bg_data_url")
        root["flyer_prefs"] = fp
        guard let out = try? JSONSerialization.data(withJSONObject: root, options: []) else { return nil }
        return out.base64EncodedString()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, skipCanvasSolidBackground: skipCanvasSolidBackground)
    }

    func makeUIView(context: Context) -> WKWebView {
        // ── Chemin rapide : WKWebView préchauffée (HTML déjà chargé) ─────────────
        if let warm = FlyerEmbedWarmup.dequeue() {
            warm.navigationDelegate = context.coordinator
            warm.isOpaque = false
            warm.backgroundColor = .clear
            warm.scrollView.backgroundColor = .clear
            warm.scrollView.isScrollEnabled = true
            if #available(iOS 15.0, *) {
                warm.underPageBackgroundColor = .clear
            }
            context.coordinator.webView = warm
            context.coordinator.latestBootstrap = bootstrapBase64
            context.coordinator.lastFlushedBootstrap = ""
            context.coordinator.skipCanvasSolidBackground = skipCanvasSolidBackground
            // La page est déjà chargée — on injecte le bootstrap immédiatement.
            context.coordinator.markPageReady()
            onWebViewCreated?(warm)
            return warm
        }

        // ── Chemin normal : nouvelle WKWebView ────────────────────────────────────
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        /// Ne **pas** injecter le JSON flyer (souvent > 1 Mo avec `custom_bg_data_url`) en `WKUserScript` :
        /// WebKit tronque les scripts très longs → JSON incomplet → pas de fond IA.
        let skipFlag = skipCanvasSolidBackground
            ? "window.__FIDPASS_SKIP_CANVAS_BG_FILL=true;"
            : "window.__FIDPASS_SKIP_CANVAS_BG_FILL=false;"
        let bootstrapPlaceholder = "window.__FIDPASS_FLYER_B64__=’’;\(skipFlag)"
        let script = WKUserScript(source: bootstrapPlaceholder, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = true
        if #available(iOS 15.0, *) {
            wv.underPageBackgroundColor = .clear
        }

        context.coordinator.webView = wv
        context.coordinator.latestBootstrap = bootstrapBase64
        context.coordinator.lastFlushedBootstrap = ""

        Task { @MainActor in
            isLoading = true
        }
        /// Cache local : `reloadRevalidatingCacheData` rallonge chaque ouverture d’aperçu ; le HTML embed change rarement.
        let req = URLRequest(
            url: APIConfig.flyerEmbedURL,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 60
        )
        wv.load(req)
        onWebViewCreated?(wv)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.webView = uiView
        context.coordinator.latestBootstrap = bootstrapBase64
        context.coordinator.skipCanvasSolidBackground = skipCanvasSolidBackground
        onWebViewCreated?(uiView)
        context.coordinator.flush()
    }

    private static func escapeForJSTemplateLiteral(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
    }

    /// Base64 [A-Za-z0-9+/=] — pas de guillemets ; échappement minimal pour concat JS.
    private static func escapeForJSDoubleQuotedChunk(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        var skipCanvasSolidBackground: Bool
        weak var webView: WKWebView?
        var latestBootstrap: String = ""
        var lastFlushedBootstrap: String = ""
        private var isPageReady = false

        init(isLoading: Binding<Bool>, skipCanvasSolidBackground: Bool) {
            _isLoading = isLoading
            self.skipCanvasSolidBackground = skipCanvasSolidBackground
        }

        /// Appelé quand la page est déjà prête (WKWebView récupérée du pool) — injecte le bootstrap immédiatement.
        func markPageReady() {
            guard !isPageReady else { return }
            isPageReady = true
            Task { @MainActor in
                self.isLoading = true
            }
            flush()
        }

        func flush() {
            guard let wv = webView else { return }
            guard latestBootstrap != lastFlushedBootstrap else { return }
            guard isPageReady else { return }

            let payload = latestBootstrap
            let maxSingle = 100_000
            if payload.count <= maxSingle {
                injectSingleChunk(wv: wv, payload: payload)
                return
            }
            injectChunked(wv: wv, payload: payload)
        }

        private func injectSingleChunk(wv: WKWebView, payload: String) {
            let escaped = FlyerPreviewWebView.escapeForJSTemplateLiteral(payload)
            let js = """
            (function(){
              window.__FIDPASS_SKIP_CANVAS_BG_FILL = \(skipCanvasSolidBackground ? "true" : "false");
              window.__FIDPASS_FLYER_B64__ = `\(escaped)`;
              if (typeof window.__FIDPASS_FLYER_APPLY__ === 'function') {
                window.__FIDPASS_FLYER_APPLY__();
              }
            })();
            """
            wv.evaluateJavaScript(js) { [weak self] _, error in
                guard let self else { return }
                if error == nil {
                    self.lastFlushedBootstrap = self.latestBootstrap
                }
                Task { @MainActor in
                    self.isLoading = false
                }
            }
        }

        /// Au-delà de ~100k caractères, `evaluateJavaScript` peut échouer silencieusement sur certains iOS ; on concatène.
        private func injectChunked(wv: WKWebView, payload: String) {
            let chunkSize = 80_000
            var parts: [String] = []
            parts.reserveCapacity(payload.count / chunkSize + 1)
            var start = payload.startIndex
            while start < payload.endIndex {
                let end = payload.index(start, offsetBy: min(chunkSize, payload.distance(from: start, to: payload.endIndex)), limitedBy: payload.endIndex) ?? payload.endIndex
                parts.append(String(payload[start..<end]))
                start = end
            }

            wv.evaluateJavaScript("window.__FIDPASS_FLYER_B64__='';") { [weak self] _, err in
                guard let self else { return }
                if err != nil {
                    Task { @MainActor in self.isLoading = false }
                    return
                }
                self.appendChunks(wv: wv, parts: parts, index: 0)
            }
        }

        private func appendChunks(wv: WKWebView, parts: [String], index: Int) {
            if index >= parts.count {
                let apply = """
                window.__FIDPASS_SKIP_CANVAS_BG_FILL = \(skipCanvasSolidBackground ? "true" : "false");
                if (typeof window.__FIDPASS_FLYER_APPLY__ === 'function') window.__FIDPASS_FLYER_APPLY__();
                """
                wv.evaluateJavaScript(apply) { [weak self] _, error in
                    guard let self else { return }
                    if error == nil {
                        self.lastFlushedBootstrap = self.latestBootstrap
                    }
                    Task { @MainActor in
                        self.isLoading = false
                    }
                }
                return
            }
            let esc = FlyerPreviewWebView.escapeForJSDoubleQuotedChunk(parts[index])
            let j = "window.__FIDPASS_FLYER_B64__ += \"\(esc)\";"
            wv.evaluateJavaScript(j) { [weak self] _, err in
                guard let self else { return }
                if err != nil {
                    Task { @MainActor in self.isLoading = false }
                    return
                }
                self.appendChunks(wv: wv, parts: parts, index: index + 1)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageReady = true
            flush()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isPageReady = true
            flush()
            Task { @MainActor in
                self.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isPageReady = true
            flush()
            Task { @MainActor in
                self.isLoading = false
            }
        }
    }
}
