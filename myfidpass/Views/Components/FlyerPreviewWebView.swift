//
//  FlyerPreviewWebView.swift
//  myfidpass
//
//  Aperçu du flyer QR (même bundle canvas que myfidpass.fr/flyer-embed.html).
//

import SwiftUI
import WebKit

struct FlyerPreviewWebView: UIViewRepresentable {
    /// Réponse JSON brute GET …/dashboard/flyer, encodée en base64 pour injection JS.
    let bootstrapBase64: String
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let escaped = bootstrapBase64
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        let js = "window.__FIDPASS_FLYER_B64__ = `\(escaped)`;"
        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = true

        Task { @MainActor in
            isLoading = true
        }
        wv.load(URLRequest(url: APIConfig.flyerEmbedURL))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
        }
    }
}
