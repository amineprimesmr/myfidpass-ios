//
//  FlyerEmbedWarmup.swift
//  myfidpass
//
//  Pool de WKWebViews préchauffées (flyer-embed.html déjà chargé).
//  FlyerPreviewWebView prend une vue du pool → pas de délai de chargement HTML.
//

import UIKit
import WebKit

enum FlyerEmbedWarmup {

    // MARK: - Pool state (main thread only)

    private static var poolViews: [WKWebView] = []
    private static var readyViews: [WKWebView] = []
    private static let maxPool = 2
    private static let warmupDelegate = WarmupNavigationDelegate()

    // MARK: - Init

    /// Appelé au lancement de l'app. Remplit le pool.
    static func startIfNeeded() {
        guard poolViews.isEmpty else { return }
        replenish()
    }

    // MARK: - Pool management

    /// Retourne une WKWebView déjà chargée (flyer-embed.html prêt), ou nil si aucune n'est prête.
    /// Déclenche automatiquement le remplacement.
    static func dequeue() -> WKWebView? {
        guard let wv = readyViews.last else { return nil }
        readyViews.removeLast()
        poolViews.removeAll(where: { $0 === wv })
        wv.removeFromSuperview()
        wv.navigationDelegate = nil
        replenish()
        return wv
    }

    static func markReady(_ wv: WKWebView) {
        guard poolViews.contains(where: { $0 === wv }) else { return }
        guard !readyViews.contains(where: { $0 === wv }) else { return }
        readyViews.append(wv)
    }

    // MARK: - Private

    private static func replenish() {
        let needed = maxPool - poolViews.count
        guard needed > 0 else { return }
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first
            else { return }

            let toCreate = maxPool - poolViews.count
            guard toCreate > 0 else { return }
            for _ in 0 ..< toCreate {
                let config = WKWebViewConfiguration()
                config.websiteDataStore = .default()
                let wv = WKWebView(
                    frame: CGRect(x: -20, y: -20, width: 2, height: 2),
                    configuration: config
                )
                wv.isOpaque = false
                wv.backgroundColor = .clear
                wv.scrollView.backgroundColor = .clear
                wv.isUserInteractionEnabled = false
                wv.navigationDelegate = warmupDelegate
                window.addSubview(wv)
                let req = URLRequest(
                    url: APIConfig.flyerEmbedURL,
                    cachePolicy: .returnCacheDataElseLoad,
                    timeoutInterval: 60
                )
                wv.load(req)
                poolViews.append(wv)
            }
        }
    }
}

// MARK: - Navigation delegate

private final class WarmupNavigationDelegate: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async { FlyerEmbedWarmup.markReady(webView) }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {}
}
