//
//  FlyerEmbedSpinflyerSrcPatch.swift
//  myfidpass
//
//  L’aperçu flyer s’exécute dans `WKWebView` (flyer-embed + app-flyer-qr-draw.js) : la texture roue
//  vient d’une **URL** sur myfidpass.fr (`/assets/spinflyer-*.png`), **pas** de l’`Images.xcassets` Xcode.
//  Si l’utilisateur teste un mauvais lien, oubli de `www`, hash obsolète, etc., le canvas ne charge qu’
//  les teintes (secteurs) — d’où l’idée d’échec côté « mode png ». On patche le setter `src` des `Image`
//  pour forcer l’**URL actuelle** connue (cache + refresh en tâche de fond).
//

import Foundation
import WebKit

enum FlyerEmbedSpinflyerSrcPatch {
    private static let defaultsKey = "myfidpass.flyerEmbed.spinflyerAssetAbsoluteURL"
    /// Dernier chemin connu côté build Vite (vérifié 200) — le refresh tâche de fond met à jour quand le hash change.
    private static let fallbackTextureURL = "https://www.myfidpass.fr/assets/spinflyer-BHvVeFjE.png?inline"

    /// URL utilisée par le user script d’injection (petite, pas de gros base64).
    static var preferredTextureAbsoluteURL: String {
        if let c = UserDefaults.standard.string(forKey: defaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            if c.hasPrefix("http://") || c.hasPrefix("https://") { return c }
        }
        return fallbackTextureURL
    }

    static func addTo(_ config: WKWebViewConfiguration) {
        let u = jsEscapedString(preferredTextureAbsoluteURL)
        let source = """
        (function(){
          const U_FIX='\(u)';
          if(!U_FIX)return;
          const isSpin = function(s){
            try { return typeof s==='string' && s.indexOf('spinflyer')>=0 && s.toLowerCase().indexOf('.png')>0; }
            catch(e){ return false; }
          };
          const p = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
          if (!p || typeof p.set !== 'function') { return; }
          const oldSet = p.set;
          p.set = function(v) {
            if (isSpin(v)) { v = U_FIX; }
            return oldSet.call(this, v);
          };
          try { Object.defineProperty(HTMLImageElement.prototype, 'src', p); } catch (e) {}
        })();
        """
        let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
    }

    private static func jsEscapedString(_ s: String) -> String {
        s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    /// Télécharge l’HTML + le bundle draw pour extraire `const xe="…"`, puis mémorise l’URL absolue.
    static func refreshRemoteTexturePathIfNeeded() {
        Task.detached(priority: .utility) {
            let next = await Self.resolveTextureURLFromRemote()
            if let next, !next.isEmpty {
                await MainActor.run {
                    UserDefaults.standard.set(next, forKey: Self.defaultsKey)
                }
            }
        }
    }

    private static func resolveTextureURLFromRemote() async -> String? {
        let base = "https://www.myfidpass.fr"
        do {
            let (htmlData, htmlResp) = try await URLSession.shared.data(
                for: URLRequest(url: APIConfig.flyerEmbedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            )
            guard (htmlResp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            guard let html = String(data: htmlData, encoding: .utf8) else { return nil }
            let drawName: String? = {
                if let r = html.range(of: #"/assets/app-flyer-qr-draw-[^"'\s>]+"#, options: .regularExpression) {
                    return String(html[r])
                }
                return nil
            }()
            guard let drawName else { return nil }
            let drawURL = URL(string: base + drawName) ?? APIConfig.flyerEmbedURL
            let (jsData, jsResp) = try await URLSession.shared.data(
                for: URLRequest(url: drawURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            )
            guard (jsResp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            guard let js = String(data: jsData, encoding: .utf8) else { return nil }
            guard let path = extractSpinflyerAssetPath(from: js), path.hasPrefix("/assets/spinflyer") else { return nil }
            return base + path
        } catch {
            return nil
        }
    }

    /// Ex. `const xe="/assets/spinflyer-….png?inline"`
    private static func extractSpinflyerAssetPath(from drawBundle: String) -> String? {
        let marker = "const xe=\""
        guard let r = drawBundle.range(of: marker) else { return nil }
        let rest = drawBundle[r.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }
}
