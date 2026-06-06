//
//  FlyerPreviewWebView.swift
//  myfidpass
//
//  Aperçu du flyer QR (même bundle canvas que myfidpass.fr/flyer-embed.html).
//  Une seule WKWebView : les changements réinjectent le JSON en JS (pas de reload → pas de flash noir).
//

import SwiftUI
import WebKit

/// Cible du document chargé dans la `WKWebView` (canvas flyer vs page jeu QR).
enum FlyerPreviewWebViewEmbedKind: Sendable {
    /// `flyer-embed.html` + `__FIDPASS_FLYER_APPLY__`
    case flyerCanvas
    /// `qr-game-embed.html` + `__FIDPASS_QR_GAME_APPLY__` (même JSON `flyer_prefs`).
    case qrGamePage

    fileprivate var applyGlobalPropertyName: String {
        switch self {
        case .flyerCanvas: "__FIDPASS_FLYER_APPLY__"
        case .qrGamePage: "__FIDPASS_QR_GAME_APPLY__"
        }
    }

    fileprivate var pageURL: URL {
        switch self {
        case .flyerCanvas: APIConfig.flyerEmbedURL
        case .qrGamePage: APIConfig.qrGameEmbedURL
        }
    }
}

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
    /// Patch JSON léger (`__FIDPASS_FLYER_PATCH_STATE__`) — couleurs / textes sans logo.
    var statePatchJSON: String = ""
    @Binding var isLoading: Bool
    /// Document + hook `APPLY` : flyer canvas ou page jeu QR (après scan).
    var embedKind: FlyerPreviewWebViewEmbedKind = .flyerCanvas
    /// Si `true` : le canvas ne remplit pas le dégradé de secours (fond IA affiché en **UIImage** sous la WebView).
    var skipCanvasSolidBackground: Bool = false
    /// Pour `qrGamePage` dans un petit cadre : met le document à l’échelle dans la zone visible (évite le cadrage « coin »).
    var scalesEmbeddedDocumentToViewport: Bool = false
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
            embedKind: embedKind,
            skipCanvasSolidBackground: skipCanvasSolidBackground,
            scalesEmbeddedDocumentToViewport: scalesEmbeddedDocumentToViewport,
            onNavigationFailure: onNavigationFailure
        )
    }

    /// Mise à l’échelle « aperçu mini » : la page jeu a souvent la hauteur d’un écran mobile ; sans ça seul le haut-gauche est visible.
    private static let qrGameViewportFitJS: String = """
    (function(){
      function fit(){
        try {
          var html = document.documentElement;
          var body = document.body;
          var root = document.getElementById("fidelity-app");
          if (!body) return;
          body.style.transform = "none";
          if (root) root.style.transform = "none";
          body.style.margin = "0";
          html.style.margin = "0";
          html.style.padding = "0";
          body.style.padding = "0";
          var target = root && root.nodeType === 1 ? root : body;
          var w = Math.max(target.scrollWidth, target.offsetWidth, target.getBoundingClientRect().width);
          var h = Math.max(target.scrollHeight, target.offsetHeight, target.getBoundingClientRect().height);
          var vw = window.innerWidth || html.clientWidth || 1;
          var vh = window.innerHeight || html.clientHeight || 1;
          if (w < 8 || h < 8 || vw < 8 || vh < 8) return;
          var scale = Math.min(vw / w, vh / h);
          if (!isFinite(scale) || scale <= 0) return;
          if (scale > 1) scale = 1;
          target.style.transformOrigin = "0 0";
          target.style.transform = "scale(" + scale + ")";
          html.style.overflow = "hidden";
          html.style.maxWidth = "100%";
          body.style.overflow = "hidden";
          body.style.maxWidth = "100%";
          if (root) {
            root.style.overflowX = "hidden";
            root.style.maxWidth = "100%";
          }
          window.scrollTo(0, 0);
        } catch (e) {}
      }
      fit();
      requestAnimationFrame(function(){ fit(); });
      setTimeout(fit, 80);
      setTimeout(fit, 240);
    })();
    """

    func makeUIView(context: Context) -> WKWebView {
        // ── Chemin rapide : WKWebView préchauffée (flyer-embed uniquement) ─────────────
        if embedKind == .flyerCanvas, let warm = FlyerEmbedWarmup.dequeue() {
            warm.navigationDelegate = context.coordinator
            warm.isOpaque = false
            warm.backgroundColor = .clear
            warm.scrollView.backgroundColor = .clear
            warm.scrollView.isScrollEnabled = true
            if #available(iOS 15.0, *) {
                warm.underPageBackgroundColor = .clear
            }
            context.coordinator.webView = warm
            context.coordinator.embedKind = embedKind
            context.coordinator.latestBootstrap = bootstrapBase64
            context.coordinator.latestStatePatch = statePatchJSON
            context.coordinator.lastFlushedBootstrap = ""
            context.coordinator.lastFlushedStatePatch = ""
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
        let previewMode = "window.__FIDPASS_PREVIEW_MODE=true;"
        let bootstrapPlaceholder = "\(previewMode)\(skipFlag)window.__FIDPASS_FLYER_B64__='';"
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
        context.coordinator.embedKind = embedKind
        context.coordinator.latestBootstrap = bootstrapBase64
        context.coordinator.latestStatePatch = statePatchJSON
        context.coordinator.lastFlushedBootstrap = ""

        Task { @MainActor in
            isLoading = true
        }
        /// Toujours revalider le document : cache local pour un 2ᵉ affichage instantané.
        let req = URLRequest(
            url: embedKind.pageURL,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 60
        )
        wv.load(req)
        Self.applyScrollBehavior(forEmbedKind: embedKind, scalesToFit: scalesEmbeddedDocumentToViewport, webView: wv)
        onWebViewCreated?(wv)
        return wv
    }

    /// Aperçu jeu dans un cadre fixe : pas de scroll natif (évite de « déplacer » le contenu / conflits avec le `ScrollView` parent).
    private static func applyScrollBehavior(
        forEmbedKind kind: FlyerPreviewWebViewEmbedKind,
        scalesToFit: Bool,
        webView: WKWebView
    ) {
        guard kind == .qrGamePage, scalesToFit else {
            webView.scrollView.isScrollEnabled = true
            webView.scrollView.bounces = true
            webView.scrollView.alwaysBounceHorizontal = false
            webView.scrollView.alwaysBounceVertical = true
            webView.scrollView.panGestureRecognizer.isEnabled = true
            return
        }
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.panGestureRecognizer.isEnabled = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.webView = uiView
        let bootstrapChanged = context.coordinator.latestBootstrap != bootstrapBase64
        let statePatchChanged = context.coordinator.latestStatePatch != statePatchJSON
        let skipChanged = context.coordinator.skipCanvasSolidBackground != skipCanvasSolidBackground
        let kindChanged = context.coordinator.embedKind != embedKind
        let scaleFitChanged = context.coordinator.scalesEmbeddedDocumentToViewport != scalesEmbeddedDocumentToViewport
        context.coordinator.latestBootstrap = bootstrapBase64
        context.coordinator.latestStatePatch = statePatchJSON
        context.coordinator.skipCanvasSolidBackground = skipCanvasSolidBackground
        context.coordinator.embedKind = embedKind
        context.coordinator.scalesEmbeddedDocumentToViewport = scalesEmbeddedDocumentToViewport
        if scaleFitChanged || kindChanged {
            Self.applyScrollBehavior(
                forEmbedKind: embedKind,
                scalesToFit: scalesEmbeddedDocumentToViewport,
                webView: uiView
            )
        }
        if kindChanged {
            let req = URLRequest(
                url: embedKind.pageURL,
                cachePolicy: .returnCacheDataElseLoad,
                timeoutInterval: 60
            )
            uiView.load(req)
            context.coordinator.isPageReady = false
            context.coordinator.lastFlushedBootstrap = ""
            context.coordinator.lastFlushedStatePatch = ""
            Task { @MainActor in
                isLoading = true
            }
            return
        }
        if bootstrapChanged || skipChanged {
            context.coordinator.flushBootstrap(showLoading: !context.coordinator.isEmbedRenderReady)
        } else if statePatchChanged {
            context.coordinator.flushStatePatch()
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

    private static func javaScriptToPatchState(escapedJsonForBacktick: String) -> String {
        """
        (function(){
          var fn="__FIDPASS_FLYER_PATCH_STATE__";
          if(typeof window[fn]==="function"){window[fn](`\(escapedJsonForBacktick)`);return;}
          if(typeof window.__FIDPASS_FLYER_APPLY__==="function"){window.__FIDPASS_FLYER_APPLY__();}
        })();
        """
    }

    // MARK: - Relance APPLY tant que le bundle n’est pas prêt

    /// Polling court — évite l’aperçu « vide » jusqu’à un 2ᵉ refocus / pastille, sans 2ᵉ rechargement côté natif.
    private static func javaScriptToAssignB64AndPollApply(
        skipCanvasBgFill: Bool,
        escapedB64ForBacktick: String,
        applyGlobalProperty: String
    ) -> String {
        let s = skipCanvasBgFill ? "true" : "false"
        let fn = applyGlobalProperty
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        (function(){
          window.__FIDPASS_SKIP_CANVAS_BG_FILL=\(s);
          window.__FIDPASS_FLYER_B64__=`\(escapedB64ForBacktick)`;
          var n=0;
          function t(){
            var fn="\(fn)";
            if(typeof window[fn]==='function'){window[fn]();return;}
            n+=1;if(n<200){setTimeout(t,8);}
          }
          t();
        })();
        """
    }

    private static func javaScriptToPollApplyAfterChunkedBootstrap(skipCanvasBgFill: Bool, applyGlobalProperty: String) -> String {
        let s = skipCanvasBgFill ? "true" : "false"
        let fn = applyGlobalProperty
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        (function(){
          window.__FIDPASS_SKIP_CANVAS_BG_FILL=\(s);
          var n=0;
          function t(){
            var fn="\(fn)";
            if(typeof window[fn]==='function'){window[fn]();return;}
            n+=1;if(n<200){setTimeout(t,8);}
          }
          t();
        })();
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        /// Stockage explicite — `@Binding` sur une sous-classe `NSObject` peut faire planter le runtime Swift
        /// (conformance / métadonnées) au lancement ou dans `WKNavigationDelegate`.
        var isLoading: Binding<Bool>
        var embedKind: FlyerPreviewWebViewEmbedKind
        var skipCanvasSolidBackground: Bool
        var scalesEmbeddedDocumentToViewport: Bool
        weak var webView: WKWebView?
        var latestBootstrap: String = ""
        var latestStatePatch: String = ""
        var lastFlushedBootstrap: String = ""
        var lastFlushedStatePatch: String = ""
        var lastFlushedSkipCanvasBg: Bool = false
        /// Réinitialisable depuis `updateUIView` (changement de document embed).
        var isPageReady = false
        private var debounceInjectWorkItem: DispatchWorkItem?
        private var renderPhase: RenderPhase = .hydrating

        /// Exposé à `updateUIView` (évite d’accéder à `renderPhase` privé).
        var isEmbedRenderReady: Bool { renderPhase == .ready }
        /// Début du flush JS courant (injection evaluateJavaScript).
        private var lastInjectFlushStart = Date()
        private var injectionCountInSession = 0
        private var loadingWatchdog: DispatchWorkItem?
        private var didAttemptRecoveryAfterTermination = false

        var onNavigationFailure: ((Error) -> Void)?

        init(
            isLoading: Binding<Bool>,
            embedKind: FlyerPreviewWebViewEmbedKind,
            skipCanvasSolidBackground: Bool,
            scalesEmbeddedDocumentToViewport: Bool,
            onNavigationFailure: ((Error) -> Void)? = nil
        ) {
            self.isLoading = isLoading
            self.embedKind = embedKind
            self.skipCanvasSolidBackground = skipCanvasSolidBackground
            self.scalesEmbeddedDocumentToViewport = scalesEmbeddedDocumentToViewport
            self.onNavigationFailure = onNavigationFailure
        }

        private func applyQrGameViewportFitIfNeeded(using wv: WKWebView) {
            guard embedKind == .qrGamePage, scalesEmbeddedDocumentToViewport else { return }
            wv.evaluateJavaScript(FlyerPreviewWebView.qrGameViewportFitJS, completionHandler: nil)
        }

        /// Appelé quand la page est déjà prête (WKWebView récupérée du pool) — injecte le bootstrap immédiatement.
        func markPageReady() {
            guard !isPageReady else { return }
            isPageReady = true
            renderPhase = .loadingWeb
            lastInjectFlushStart = Date()
            injectionCountInSession = 0
            setLoading(true)
            armLoadingWatchdog()
            flushBootstrap(showLoading: true)
        }

        /// Injection immédiate (plus de debounce 80 ms) — patch couleur/texte ou bootstrap complet.
        func flushBootstrap(showLoading: Bool = true) {
            debounceInjectWorkItem?.cancel()
            guard isPageReady, webView != nil else { return }
            if latestBootstrap == lastFlushedBootstrap, lastFlushedSkipCanvasBg == skipCanvasSolidBackground { return }
            if renderPhase == .ready {
                renderPhase = .applying
            }
            let work = DispatchWorkItem { [weak self] in
                guard let self, let wv = self.webView else { return }
                if self.latestBootstrap == self.lastFlushedBootstrap, self.lastFlushedSkipCanvasBg == self.skipCanvasSolidBackground { return }
                if showLoading { self.setLoading(true) }
                self.executeInjectFlush(using: wv, showLoading: showLoading)
            }
            debounceInjectWorkItem = work
            DispatchQueue.main.async(execute: work)
        }

        func flushStatePatch() {
            guard embedKind == .flyerCanvas else { return }
            guard isPageReady, let wv = webView else { return }
            let patch = latestStatePatch.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !patch.isEmpty else { return }
            if patch == lastFlushedStatePatch { return }
            let escaped = FlyerPreviewWebView.escapeForJSTemplateLiteral(patch)
            let js = FlyerPreviewWebView.javaScriptToPatchState(escapedJsonForBacktick: escaped)
            wv.evaluateJavaScript(js) { [weak self] _, error in
                guard let self else { return }
                if error == nil {
                    self.lastFlushedStatePatch = patch
                    self.renderPhase = .ready
                }
            }
        }

        private func executeInjectFlush(using wv: WKWebView, showLoading: Bool) {
            if latestBootstrap == lastFlushedBootstrap, lastFlushedSkipCanvasBg == skipCanvasSolidBackground { return }
            guard isPageReady else { return }
            lastInjectFlushStart = Date()
            let payload = latestBootstrap
            let maxSingle = 100_000
            if payload.count <= maxSingle {
                injectSingleChunk(wv: wv, payload: payload, showLoading: showLoading)
            } else {
                injectChunked(wv: wv, payload: payload, showLoading: showLoading)
            }
        }

        private func injectSingleChunk(wv: WKWebView, payload: String, showLoading: Bool) {
            let escaped = FlyerPreviewWebView.escapeForJSTemplateLiteral(payload)
            let js = FlyerPreviewWebView.javaScriptToAssignB64AndPollApply(
                skipCanvasBgFill: skipCanvasSolidBackground,
                escapedB64ForBacktick: escaped,
                applyGlobalProperty: embedKind.applyGlobalPropertyName
            )
            renderPhase = .applying
            injectionCountInSession += 1
            if showLoading { armLoadingWatchdog() }
            wv.evaluateJavaScript(js) { [weak self] _, error in
                guard let self else { return }
                if error == nil {
                    self.lastFlushedBootstrap = self.latestBootstrap
                    self.lastFlushedSkipCanvasBg = self.skipCanvasSolidBackground
                    self.lastFlushedStatePatch = self.latestStatePatch.trimmingCharacters(in: .whitespacesAndNewlines)
                    self.renderPhase = .ready
                    self.didAttemptRecoveryAfterTermination = false
                    let elapsed = Int(Date().timeIntervalSince(self.lastInjectFlushStart) * 1000)
                    FlyerPreviewWebView.RenderTelemetry.mark(
                        "ready",
                        ms: elapsed,
                        extras: "injections=\(self.injectionCountInSession)"
                    )
                    self.applyQrGameViewportFitIfNeeded(using: wv)
                } else {
                    self.renderPhase = .failed
                }
                if showLoading {
                    self.disarmLoadingWatchdog()
                    self.setLoading(false)
                }
            }
        }

        /// Au-delà de ~100k caractères, `evaluateJavaScript` peut échouer silencieusement sur certains iOS ; on concatène.
        private func injectChunked(wv: WKWebView, payload: String, showLoading: Bool) {
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
            if showLoading { armLoadingWatchdog() }
            wv.evaluateJavaScript("window.__FIDPASS_FLYER_B64__='';") { [weak self] _, err in
                guard let self else { return }
                if err != nil {
                    self.renderPhase = .failed
                    if showLoading {
                        self.disarmLoadingWatchdog()
                        self.setLoading(false)
                    }
                    return
                }
                self.appendChunks(wv: wv, parts: parts, index: 0, showLoading: showLoading)
            }
        }

        private func appendChunks(wv: WKWebView, parts: [String], index: Int, showLoading: Bool) {
            if index >= parts.count {
                let apply = FlyerPreviewWebView.javaScriptToPollApplyAfterChunkedBootstrap(
                    skipCanvasBgFill: skipCanvasSolidBackground,
                    applyGlobalProperty: embedKind.applyGlobalPropertyName
                )
                wv.evaluateJavaScript(apply) { [weak self] _, error in
                    guard let self else { return }
                    if error == nil {
                        self.lastFlushedBootstrap = self.latestBootstrap
                        self.lastFlushedSkipCanvasBg = self.skipCanvasSolidBackground
                        self.lastFlushedStatePatch = self.latestStatePatch.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.renderPhase = .ready
                        self.didAttemptRecoveryAfterTermination = false
                        let elapsed = Int(Date().timeIntervalSince(self.lastInjectFlushStart) * 1000)
                        FlyerPreviewWebView.RenderTelemetry.mark(
                            "ready",
                            ms: elapsed,
                            extras: "injections=\(self.injectionCountInSession)"
                        )
                        self.applyQrGameViewportFitIfNeeded(using: wv)
                    } else {
                        self.renderPhase = .failed
                    }
                    if showLoading {
                        self.disarmLoadingWatchdog()
                        self.setLoading(false)
                    }
                }
                return
            }
            let esc = FlyerPreviewWebView.escapeForJSDoubleQuotedChunk(parts[index])
            let j = "window.__FIDPASS_FLYER_B64__ += \"\(esc)\";"
            wv.evaluateJavaScript(j) { [weak self] _, err in
                guard let self else { return }
                if err != nil {
                    self.renderPhase = .failed
                    if showLoading {
                        self.disarmLoadingWatchdog()
                        self.setLoading(false)
                    }
                    return
                }
                self.appendChunks(wv: wv, parts: parts, index: index + 1, showLoading: showLoading)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isPageReady = true
            renderPhase = .applying
            lastInjectFlushStart = Date()
            injectionCountInSession = 0
            armLoadingWatchdog()
            flushBootstrap(showLoading: true)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isPageReady = true
            flushBootstrap(showLoading: true)
            Task { @MainActor in
                self.disarmLoadingWatchdog()
                self.isLoading.wrappedValue = false
                self.renderPhase = .failed
                if FlyerPreviewWebView.shouldReportEmbedNavigationFailure(error) {
                    self.onNavigationFailure?(error)
                }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isPageReady = true
            flushBootstrap(showLoading: true)
            Task { @MainActor in
                self.disarmLoadingWatchdog()
                self.isLoading.wrappedValue = false
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
                url: embedKind.pageURL,
                cachePolicy: .reloadRevalidatingCacheData,
                timeoutInterval: 60
            )
            webView.load(req)
            setLoading(true)
            armLoadingWatchdog()
        }

        private func setLoading(_ value: Bool) {
            Task { @MainActor in
                if self.isLoading.wrappedValue != value {
                    self.isLoading.wrappedValue = value
                }
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
