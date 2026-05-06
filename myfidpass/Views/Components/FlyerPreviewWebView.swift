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
    private enum RenderPhase: String {
        case hydrating
        case loadingWeb
        case applying
        case ready
        case failed
    }

    private enum RenderTelemetry {
        static func mark(_ name: String, ms: Int, extras: String = "") {
            #if DEBUG
            if extras.isEmpty {
                print("FlyerPreviewTelemetry \(name) \(ms)ms")
            } else {
                print("FlyerPreviewTelemetry \(name) \(ms)ms \(extras)")
            }
            #endif
        }
    }
    /// Évite les faux « échecs » quand WebKit annule une navigation (remplacement de requête, reload).
    private static func shouldReportEmbedNavigationFailure(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled { return false }
        return true
    }

    /// Certains bundles tiers tentent de charger `default.csv` (resource inexistante côté app) :
    /// on coupe ces navigations pour éviter le bruit console.
    private static func shouldBlockNoisyResource(_ url: URL?) -> Bool {
        guard let url else { return false }
        let last = url.lastPathComponent.lowercased()
        return last == "default.csv"
    }

    /// Coupe `fetch` / XHR vers `default.csv` avant même la couche réseau WebKit.
    private static func addNoisyResourceBlockerScript(to config: WKWebViewConfiguration) {
        let js = """
        (function(){
          function isBlocked(u){
            try {
              var s = String(u || '').toLowerCase();
              return s.indexOf('default.csv') >= 0;
            } catch(e) { return false; }
          }
          var _fetch = window.fetch;
          if (typeof _fetch === 'function') {
            window.fetch = function(input, init){
              var u = (typeof input === 'string') ? input : (input && input.url);
              if (isBlocked(u)) {
                return Promise.resolve(new Response('', { status: 204, statusText: 'No Content' }));
              }
              return _fetch.call(this, input, init);
            };
          }
          var _open = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function(method, url){
            if (isBlocked(url)) {
              return _open.call(this, method, 'about:blank');
            }
            return _open.apply(this, arguments);
          };
        })();
        """
        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
    }

    /// Réponse JSON brute GET …/dashboard/flyer, encodée en base64 pour injection JS.
    let bootstrapBase64: String
    @Binding var isLoading: Bool
    /// Si `true` : le canvas ne remplit pas le dégradé de secours (fond IA affiché en **UIImage** sous la WebView).
    var skipCanvasSolidBackground: Bool = false
    /// Appelé quand la `WKWebView` est prête (aperçu plein écran : impression / capture).
    var onWebViewCreated: ((WKWebView) -> Void)? = nil
    /// Échec de chargement du document embed (réseau, URL, etc.) — pour afficher un message plutôt qu’un cadre vide.
    var onNavigationFailure: ((Error) -> Void)? = nil

    /// Retire `custom_bg_data_url` du JSON pour alléger l’injection + mode « calque » natif sous la WebView.
    nonisolated static func stripCustomBgFromBootstrapBase64(_ b64: String) -> String? {
        guard let data = Data(base64Encoded: b64),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var fp = root["flyer_prefs"] as? [String: Any] else { return nil }
        fp.removeValue(forKey: "custom_bg_data_url")
        root["flyer_prefs"] = fp
        /// Clés triées : sans cela, la ré-écriture du JSON pouvait varier d’un appel à l’autre et produire un base64 différent
        /// pour le même contenu → le WebView croyait un nouveau bootstrap et réinjectait (flash) à chaque re-render.
        guard let out = try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys]) else { return nil }
        return out.base64EncodedString()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isLoading: $isLoading,
            skipCanvasSolidBackground: skipCanvasSolidBackground,
            onNavigationFailure: onNavigationFailure
        )
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
        /// Avant le module `flyer-embed` : `atob` + UTF-8 (voir `FlyerEmbedAtobUTF8Patch`).
        FlyerEmbedAtobUTF8Patch.addTo(config)
        /// Texture roue : `spinflyer` de l’asset catalogue en priorité, repli URL myfidpass (voir `FlyerEmbedSpinflyerSrcPatch`).
        FlyerEmbedSpinflyerSrcPatch.addTo(config)
        FlyerPreviewWebView.addNoisyResourceBlockerScript(to: config)
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
        /// Toujours revalider `flyer-embed` : évite de rester bloqué sur un ancien bundle JS après déploiement (bug roue/gift).
        let req = URLRequest(
            url: APIConfig.flyerEmbedURL,
            cachePolicy: .reloadRevalidatingCacheData,
            timeoutInterval: 60
        )
        wv.load(req)
        onWebViewCreated?(wv)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.webView = uiView
        let bootstrapChanged = context.coordinator.latestBootstrap != bootstrapBase64
        let skipChanged = context.coordinator.skipCanvasSolidBackground != skipCanvasSolidBackground
        context.coordinator.latestBootstrap = bootstrapBase64
        context.coordinator.skipCanvasSolidBackground = skipCanvasSolidBackground
        /// Ne pas rappeler `onWebViewCreated` ici : c’est un hook « création », le relancer à chaque `updateUIView` cassait
        /// les hypothèses côté parent et inutile si la closure fait du travail coûteux.
        if bootstrapChanged || skipChanged {
            context.coordinator.flush()
        }
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

    // MARK: - Relance APPLY tant que le bundle n’est pas prêt (1er `evaluate` souvent **avant** `__FIDPASS_FLYER_APPLY__`).

    /// Polling court — évite l’aperçu « vide » jusqu’à un 2ᵉ refocus / pastille, sans 2ᵉ rechargement côté natif.
    private static func javaScriptToAssignB64AndPollApply(skipCanvasBgFill: Bool, escapedB64ForBacktick: String) -> String {
        let s = skipCanvasBgFill ? "true" : "false"
        return """
        (function(){
          window.__FIDPASS_SKIP_CANVAS_BG_FILL=\(s);
          window.__FIDPASS_FLYER_B64__=`\(escapedB64ForBacktick)`;
          var n=0;
          function t(){
            if(typeof window.__FIDPASS_FLYER_APPLY__==='function'){window.__FIDPASS_FLYER_APPLY__();return;}
            n+=1;if(n<200){setTimeout(t,8);}
          }
          t();
        })();
        """
    }

    private static func javaScriptToPollApplyAfterChunkedBootstrap(skipCanvasBgFill: Bool) -> String {
        let s = skipCanvasBgFill ? "true" : "false"
        return """
        (function(){
          window.__FIDPASS_SKIP_CANVAS_BG_FILL=\(s);
          var n=0;
          function t(){
            if(typeof window.__FIDPASS_FLYER_APPLY__==='function'){window.__FIDPASS_FLYER_APPLY__();return;}
            n+=1;if(n<200){setTimeout(t,8);}
          }
          t();
        })();
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        var skipCanvasSolidBackground: Bool
        weak var webView: WKWebView?
        var latestBootstrap: String = ""
        var lastFlushedBootstrap: String = ""
        var lastFlushedSkipCanvasBg: Bool = false
        private var isPageReady = false
        private var debounceInjectWorkItem: DispatchWorkItem?
        private var renderPhase: RenderPhase = .hydrating
        private var lastRenderStart = Date()
        private var injectionCountInSession = 0
        private var loadingWatchdog: DispatchWorkItem?
        private var didAttemptRecoveryAfterTermination = false

        var onNavigationFailure: ((Error) -> Void)?

        init(
            isLoading: Binding<Bool>,
            skipCanvasSolidBackground: Bool,
            onNavigationFailure: ((Error) -> Void)? = nil
        ) {
            _isLoading = isLoading
            self.skipCanvasSolidBackground = skipCanvasSolidBackground
            self.onNavigationFailure = onNavigationFailure
        }

        /// Appelé quand la page est déjà prête (WKWebView récupérée du pool) — injecte le bootstrap immédiatement.
        func markPageReady() {
            guard !isPageReady else { return }
            isPageReady = true
            renderPhase = .loadingWeb
            lastRenderStart = Date()
            setLoading(true)
            armLoadingWatchdog()
            flush()
        }

        /// Regroupe les mises à jour rapides (roue, pastilles) : un seul `evaluate` ~40 ms après le dernier changement → moins de flash.
        /// Le **polling** JS ci-dessous gère l’ordre d’arrivée du bundle `__FIDPASS_FLYER_APPLY__` au 1ʳᵉ affichage.
        func flush() {
            debounceInjectWorkItem?.cancel()
            guard isPageReady, webView != nil else { return }
            if latestBootstrap == lastFlushedBootstrap, lastFlushedSkipCanvasBg == skipCanvasSolidBackground { return }
            if renderPhase == .ready {
                renderPhase = .applying
            }
            let work = DispatchWorkItem { [weak self] in
                guard let self, let wv = self.webView else { return }
                if self.latestBootstrap == self.lastFlushedBootstrap, self.lastFlushedSkipCanvasBg == self.skipCanvasSolidBackground { return }
                self.executeInjectFlush(using: wv)
            }
            debounceInjectWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
        }

        private func executeInjectFlush(using wv: WKWebView) {
            if latestBootstrap == lastFlushedBootstrap, lastFlushedSkipCanvasBg == skipCanvasSolidBackground { return }
            guard isPageReady else { return }
            let payload = latestBootstrap
            let maxSingle = 100_000
            if payload.count <= maxSingle {
                injectSingleChunk(wv: wv, payload: payload)
            } else {
                injectChunked(wv: wv, payload: payload)
            }
        }

        private func injectSingleChunk(wv: WKWebView, payload: String) {
            let escaped = FlyerPreviewWebView.escapeForJSTemplateLiteral(payload)
            let js = FlyerPreviewWebView.javaScriptToAssignB64AndPollApply(
                skipCanvasBgFill: skipCanvasSolidBackground,
                escapedB64ForBacktick: escaped
            )
            renderPhase = .applying
            injectionCountInSession += 1
            armLoadingWatchdog()
            wv.evaluateJavaScript(js) { [weak self] _, error in
                guard let self else { return }
                if error == nil {
                    self.lastFlushedBootstrap = self.latestBootstrap
                    self.lastFlushedSkipCanvasBg = self.skipCanvasSolidBackground
                    self.renderPhase = .ready
                    self.didAttemptRecoveryAfterTermination = false
                    let elapsed = Int(Date().timeIntervalSince(self.lastRenderStart) * 1000)
                    FlyerPreviewWebView.RenderTelemetry.mark(
                        "ready",
                        ms: elapsed,
                        extras: "injections=\(self.injectionCountInSession)"
                    )
                } else {
                    self.renderPhase = .failed
                }
                self.disarmLoadingWatchdog()
                self.setLoading(false)
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

            renderPhase = .applying
            injectionCountInSession += 1
            armLoadingWatchdog()
            wv.evaluateJavaScript("window.__FIDPASS_FLYER_B64__='';") { [weak self] _, err in
                guard let self else { return }
                if err != nil {
                    self.renderPhase = .failed
                    self.disarmLoadingWatchdog()
                    self.setLoading(false)
                    return
                }
                self.appendChunks(wv: wv, parts: parts, index: 0)
            }
        }

        private func appendChunks(wv: WKWebView, parts: [String], index: Int) {
            if index >= parts.count {
                let apply = FlyerPreviewWebView.javaScriptToPollApplyAfterChunkedBootstrap(skipCanvasBgFill: skipCanvasSolidBackground)
                wv.evaluateJavaScript(apply) { [weak self] _, error in
                    guard let self else { return }
                    if error == nil {
                        self.lastFlushedBootstrap = self.latestBootstrap
                        self.lastFlushedSkipCanvasBg = self.skipCanvasSolidBackground
                        self.renderPhase = .ready
                        self.didAttemptRecoveryAfterTermination = false
                        let elapsed = Int(Date().timeIntervalSince(self.lastRenderStart) * 1000)
                        FlyerPreviewWebView.RenderTelemetry.mark(
                            "ready",
                            ms: elapsed,
                            extras: "injections=\(self.injectionCountInSession)"
                        )
                    } else {
                        self.renderPhase = .failed
                    }
                    self.disarmLoadingWatchdog()
                    self.setLoading(false)
                }
                return
            }
            let esc = FlyerPreviewWebView.escapeForJSDoubleQuotedChunk(parts[index])
            let j = "window.__FIDPASS_FLYER_B64__ += \"\(esc)\";"
            wv.evaluateJavaScript(j) { [weak self] _, err in
                guard let self else { return }
                if err != nil {
                    self.renderPhase = .failed
                    self.disarmLoadingWatchdog()
                    self.setLoading(false)
                    return
                }
                self.appendChunks(wv: wv, parts: parts, index: index + 1)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageReady = true
            renderPhase = .applying
            armLoadingWatchdog()
            flush()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isPageReady = true
            flush()
            Task { @MainActor in
                self.disarmLoadingWatchdog()
                self.isLoading = false
                self.renderPhase = .failed
                if FlyerPreviewWebView.shouldReportEmbedNavigationFailure(error) {
                    self.onNavigationFailure?(error)
                }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isPageReady = true
            flush()
            Task { @MainActor in
                self.disarmLoadingWatchdog()
                self.isLoading = false
                self.renderPhase = .failed
                if FlyerPreviewWebView.shouldReportEmbedNavigationFailure(error) {
                    self.onNavigationFailure?(error)
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if FlyerPreviewWebView.shouldBlockNoisyResource(navigationAction.request.url) {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if FlyerPreviewWebView.shouldBlockNoisyResource(navigationResponse.response.url) {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            renderPhase = .failed
            disarmLoadingWatchdog()
            setLoading(false)
            guard !didAttemptRecoveryAfterTermination else { return }
            didAttemptRecoveryAfterTermination = true
            isPageReady = false
            let req = URLRequest(
                url: APIConfig.flyerEmbedURL,
                cachePolicy: .reloadRevalidatingCacheData,
                timeoutInterval: 60
            )
            webView.load(req)
            setLoading(true)
            armLoadingWatchdog()
        }

        private func setLoading(_ value: Bool) {
            Task { @MainActor in
                self.isLoading = value
            }
        }

        private func armLoadingWatchdog() {
            loadingWatchdog?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard self.renderPhase == .loadingWeb || self.renderPhase == .applying else { return }
                self.renderPhase = .failed
                self.setLoading(false)
            }
            loadingWatchdog = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 12.0, execute: work)
        }

        private func disarmLoadingWatchdog() {
            loadingWatchdog?.cancel()
            loadingWatchdog = nil
        }
    }
}
