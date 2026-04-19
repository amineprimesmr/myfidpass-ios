//
//  FidelityClientPageWebView.swift
//  myfidpass
//
//  Aperçu embarqué de la page fidélité client (myfidpass.fr/fidelity/…) : roue, récompenses, etc.
//

import SwiftUI
import WebKit

struct FidelityClientPageWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.isOpaque = true
        wv.backgroundColor = .systemBackground
        wv.scrollView.backgroundColor = .systemBackground
        // Hauteur fixée par l’app (fenêtre type téléphone) : le document scroll comme dans Safari.
        wv.scrollView.isScrollEnabled = true
        wv.scrollView.bounces = true

        Task { @MainActor in
            isLoading = true
        }
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        var isLoading: Binding<Bool>

        init(isLoading: Binding<Bool>) {
            self.isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading.wrappedValue = false
        }
    }
}
