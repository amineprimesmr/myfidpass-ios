//
//  MerchantSaasPaymentWebView.swift
//  myfidpass
//
//  Paywall web : charge la page SaaS `/paiement` (plan Pro) au lieu du paywall natif.
//

import SwiftUI
import UIKit
import WebKit

/// WKWebView pour la page de paiement du site (cohérent avec la vitrine / Stripe Payment Link).
struct MerchantSaasPaymentWebContent: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.isOpaque = false
        wv.backgroundColor = .black
        wv.scrollView.backgroundColor = .black
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let current = uiView.url?.absoluteString
        let next = url.absoluteString
        if current != next {
            uiView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        /// Liens `target="_blank"` : même WebView (CTA Stripe).
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            if url.scheme?.lowercased() == "myfidpass", url.host == "subscription-paid" {
                NotificationCenter.default.post(name: .myfidpassSubscriptionPaymentCompleted, object: nil)
                decisionHandler(.cancel)
                return
            }
            // Paiement hébergé Stripe (Payment Link, etc.) : Safari si besoin.
            // Ne pas inclure js.stripe.com : Stripe Elements charge `m-outer-…` dans la WebView ; l’ouvrir
            // dans Safari annule le chargement ici → écran blanc hors app (voir decidePolicyFor + .cancel).
            if Self.shouldOpenStripeOrPaymentInSafari(url) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        private static func shouldOpenStripeOrPaymentInSafari(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased() else { return false }
            // Iframes / scripts Stripe.js — doivent rester dans la même WKWebView que myfidpass.fr.
            if host == "js.stripe.com" { return false }
            if host == "m.stripe.network" { return false }
            if host == "buy.stripe.com" { return true }
            if host.hasSuffix(".stripe.com") || host == "stripe.com" { return true }
            if host.hasSuffix(".link.co") { return true }
            return false
        }
    }
}

/// Conteneur SwiftUI : page web plein écran + fermeture optionnelle (feuille modale).
struct MerchantSaasPaymentWebView: View {
    @Environment(\.dismiss) private var dismiss

    /// Paywall bloquant : pas de bouton fermer.
    var allowsCloseButton: Bool = true
    var onCloseRequested: (() -> Void)? = nil
    var headerExtraTopPadding: CGFloat = 4
    var closeButtonRevealDelay: TimeInterval = 5
    /// Décale le contenu web sous le bord arrondi de la **sheet** iOS (WKWebView ignorait tout le safe area).
    var webContentExtraTopInset: CGFloat = 18

    @State private var isCloseButtonRevealed = false

    private var paymentURL: URL {
        buildPaymentURLWithAuthHandoff(base: LegalURLs.merchantSaasProPaymentPage)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MerchantSaasPaymentWebContent(url: paymentURL)
                .padding(.top, webContentExtraTopInset)
                .ignoresSafeArea()

            if allowsCloseButton, isCloseButtonRevealed {
                Button {
                    if let onCloseRequested {
                        onCloseRequested()
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, headerExtraTopPadding + 8 + webContentExtraTopInset)
                .padding(.trailing, 12)
                .accessibilityLabel("Fermer")
            }
        }
        .preferredColorScheme(.dark)
        .task(id: "\(allowsCloseButton)-\(closeButtonRevealDelay)") {
            guard allowsCloseButton else {
                isCloseButtonRevealed = false
                return
            }
            isCloseButtonRevealed = false
            let nanos = UInt64(max(0, closeButtonRevealDelay) * 1_000_000_000)
            if nanos > 0 {
                try? await Task.sleep(nanoseconds: nanos)
            }
            isCloseButtonRevealed = true
        }
    }

    /// Handoff explicite des tokens via hash pour que `myfidpass.fr/paiement` restaure
    /// la session web sans redemander la connexion.
    private func buildPaymentURLWithAuthHandoff(base: URL) -> URL {
        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else { return base }
        var items = components.queryItems ?? []
        if !items.contains(where: { $0.name == "app_embed" }) {
            items.append(URLQueryItem(name: "app_embed", value: "1"))
        }
        components.queryItems = items
        if let access = AuthStorage.authToken?.trimmingCharacters(in: .whitespacesAndNewlines), !access.isEmpty {
            let refresh = AuthStorage.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let accessEncoded = access.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? access
            let refreshEncoded = refresh.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? refresh
            var fragment = "fid_auth=\(accessEncoded)"
            if !refreshEncoded.isEmpty {
                fragment += "&fid_refresh=\(refreshEncoded)"
            }
            components.fragment = fragment
        }
        return components.url ?? base
    }
}

#Preview {
    MerchantSaasPaymentWebView()
}
