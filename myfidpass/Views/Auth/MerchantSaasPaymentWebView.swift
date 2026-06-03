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
    /// Appelé après chaque chargement réussi — injection session web alignée sur `AuthStorage` natif.
    var onPageDidFinish: ((WKWebView) -> Void)?
    /// Deep link `myfidpass://subscription-paid` — uniquement après confirmation serveur.
    var onSubscriptionPaidDeepLink: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onPageDidFinish: onPageDidFinish, onSubscriptionPaidDeepLink: onSubscriptionPaidDeepLink)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.preferredContentMode = .mobile
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.isOpaque = false
        /// Même graphite que l’écran flyer (`#0e1113`) — letterboxing / rebond scroll cohérents avec l’éditeur.
        let chrome = UIColor(red: 14 / 255, green: 17 / 255, blue: 19 / 255, alpha: 1)
        wv.backgroundColor = chrome
        wv.scrollView.backgroundColor = chrome
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
        private let onPageDidFinish: ((WKWebView) -> Void)?
        private let onSubscriptionPaidDeepLink: (() -> Void)?

        init(
            onPageDidFinish: ((WKWebView) -> Void)?,
            onSubscriptionPaidDeepLink: (() -> Void)?
        ) {
            self.onPageDidFinish = onPageDidFinish
            self.onSubscriptionPaidDeepLink = onSubscriptionPaidDeepLink
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onPageDidFinish?(webView)
        }

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
                onSubscriptionPaidDeepLink?()
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
    @EnvironmentObject private var authService: AuthService

    /// `true` : `/paiement?app_embed=1` (1 € Stripe). `false` : Payment Link hébergé.
    var useEmbeddedStripeCheckout: Bool = false
    var embeddedPlanAnnual: Bool = false
    var embeddedCommerceSlots: Int = 1

    /// Paywall bloquant : pas de bouton fermer.
    var allowsCloseButton: Bool = true
    var onCloseRequested: (() -> Void)? = nil
    var headerExtraTopPadding: CGFloat = 4
    var closeButtonRevealDelay: TimeInterval = 5
    /// Décale le contenu web sous le bord arrondi de la **sheet** iOS (WKWebView ignorait tout le safe area).
    var webContentExtraTopInset: CGFloat = 18

    @State private var isCloseButtonRevealed = false
    @State private var paymentWebViewRef: WKWebView?

    /// URL de paiement : checkout intégré (1 € garanti) ou Payment Link Stripe.
    private var paymentURL: URL {
        let email = authService.currentUserEmail ?? AuthStorage.userEmail
        if useEmbeddedStripeCheckout {
            return LegalURLs.merchantEmbeddedSaasPaymentPage(
                prefilledEmail: email,
                planAnnual: embeddedPlanAnnual,
                commerceSlots: embeddedCommerceSlots
            )
        }
        return LegalURLs.merchantSaasProPaymentPage(prefilledEmail: email)
    }

    /// Commerce actif (`slug` stocké) ou premier commerce du compte — affiché comme contexte de paiement.
    private var paymentBusinessDisplayName: String? {
        let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let list = authService.businesses
        guard !list.isEmpty else { return nil }
        let biz: BusinessDTO = {
            if !slug.isEmpty, let m = list.first(where: { $0.slug == slug }) { return m }
            return list[0]
        }()
        let org = biz.organizationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !org.isEmpty { return org }
        let n = biz.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? nil : n
    }

    /// Espace sous la zone chrome ; sans chrome, conserve l’ancien retrait pour la sheet arrondie.
    private var webViewTopInsetAfterChrome: CGFloat {
        shouldShowPaymentTopChrome ? 4 : webContentExtraTopInset
    }

    private var shouldShowPaymentTopChrome: Bool {
        paymentBusinessDisplayName != nil || (allowsCloseButton && isCloseButtonRevealed)
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let endR = max(proxy.size.width, proxy.size.height) * 0.95
                ZStack {
                    FlyerEditorSurfaceColors.canvas
                    RadialGradient(
                        colors: [
                            FlyerEditorSurfaceColors.glowDepth.opacity(0.65),
                            FlyerEditorSurfaceColors.glowDepth.opacity(0.28),
                            FlyerEditorSurfaceColors.canvas.opacity(0)
                        ],
                        center: UnitPoint(x: 0.5, y: 0.08),
                        startRadius: 0,
                        endRadius: endR
                    )
                    .blur(radius: 24)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                if shouldShowPaymentTopChrome {
                    paymentPageTopChrome
                }
                MerchantSaasPaymentWebContent(
                    url: paymentURL,
                    onPageDidFinish: { webView in
                        paymentWebViewRef = webView
                        Task { @MainActor in
                            await APIClient.shared.ensureValidAccessToken()
                            Self.injectNativeAuthSession(into: webView)
                        }
                    },
                    onSubscriptionPaidDeepLink: {
                        Task { @MainActor in
                            _ = await authService.refreshMerchantBillingStateFromServer(force: true)
                            await authService.reconcileMerchantSubscriptionFromServer(force: true)
                            guard authService.hasEncashedMerchantSubscription else { return }
                            NotificationCenter.default.post(name: .myfidpassSubscriptionPaymentCompleted, object: nil)
                        }
                    }
                )
                    .padding(.top, webViewTopInsetAfterChrome)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .preferredColorScheme(.dark)
        .task {
            await APIClient.shared.ensureValidAccessToken()
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassAuthTokensUpdated)) { _ in
            guard let webView = paymentWebViewRef else { return }
            Task { @MainActor in
                Self.injectNativeAuthSession(into: webView)
            }
        }
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

    private var paymentPageTopChrome: some View {
        HStack(alignment: .top, spacing: 10) {
            if let name = paymentBusinessDisplayName {
                paymentBusinessContextCard(displayName: name)
            }
            Spacer(minLength: 4)
            if allowsCloseButton, isCloseButtonRevealed {
                paymentCloseButton
            }
        }
        .padding(.horizontal, 12)
        /// Avec carte commerce : retrait modéré ; croix seule : même logique que l’ancienne overlay (sheet + tiret).
        .padding(
            .top,
            headerExtraTopPadding + 6 + (paymentBusinessDisplayName == nil ? webContentExtraTopInset : 0)
        )
        .padding(.bottom, paymentBusinessDisplayName != nil ? 8 : 6)
        .animation(.easeOut(duration: 0.28), value: isCloseButtonRevealed)
    }

    private var paymentCloseButton: some View {
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
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fermer")
    }

    private func paymentBusinessContextCard(displayName: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.58, green: 0.38, blue: 0.99).opacity(0.95),
                                Color(red: 0.38, green: 0.28, blue: 0.88).opacity(0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "storefront.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Abonnement pour")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                    .textCase(.uppercase)
                    .tracking(0.85)
                Text(displayName)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.96))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.35), radius: 14, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Abonnement pour \(displayName)")
    }

    /// Écrit uniquement `fidpass_token` dans la WebView (`?app_embed=1` ne doit pas appeler POST /auth/refresh côté web).
    /// Injecter le refresh provoquait une rotation serveur sans mise à jour du Keychain iOS → faux « session expirée » plus tard.
    @MainActor
    private static func injectNativeAuthSession(into webView: WKWebView) {
        guard let access = AuthStorage.authToken?.trimmingCharacters(in: .whitespacesAndNewlines), !access.isEmpty else { return }
        let accessEsc = jsStringLiteral(access)
        let script = """
        (function() {
          try {
            localStorage.setItem('fidpass_token', '\(accessEsc)');
            localStorage.removeItem('fidpass_refresh_token');
            window.dispatchEvent(new CustomEvent('fidpass-auth-restored'));
          } catch (e) {}
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private static func jsStringLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
    }
}

#Preview {
    MerchantSaasPaymentWebView()
        .environmentObject(AuthService())
}
