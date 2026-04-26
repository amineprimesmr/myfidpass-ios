//
//  FlyerEmbedSpinflyerSrcPatch.swift
//  myfidpass
//
//  Aperçu `WKWebView` : le bundle web peut résoudre la texture roue en URL `/assets/spinflyer…` ou chemin
//  `flyer-wheels`. **Ne jamais** traiter les longues `data:image/…` génériques comme la roue : ce sont en pratique
//  toujours des **logos commerce** (`custom_logo_data_url`) — l’ancien seuil `length > 8000` les remplaçait par
//  la texture spinflyer (bug « la roue en logo »).
//

import Foundation
import UIKit
import WebKit

enum FlyerEmbedSpinflyerSrcPatch {
    private static let defaultsKey = "myfidpass.flyerEmbed.spinflyerAssetAbsoluteURL"
    /// Dernier chemin connu côté build Vite (vérifié 200) — le refresh tâche de fond met à jour quand le hash change.
    private static let fallbackTextureURL = "https://www.myfidpass.fr/assets/spinflyer-BHvVeFjE.png?inline"
    private static var cachedXcodeTextureDataURL: String?

    /// Texture injectée dans le patch `src` (Xcode d’abord, puis cache réseau, puis URL fixe myfidpass.fr).
    static var preferredTextureAbsoluteURL: String {
        if cachedXcodeTextureDataURL == nil, let fromAsset = Self.jpegDataURLFromXcodeSpinflyerAsset() {
            cachedXcodeTextureDataURL = fromAsset
        }
        if let c = cachedXcodeTextureDataURL, !c.isEmpty { return c }
        if let c = UserDefaults.standard.string(forKey: defaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            if c.hasPrefix("http://") || c.hasPrefix("https://") { return c }
        }
        return fallbackTextureURL
    }

    /// Image catalogue `spinflyer` — JPEG raisonnable pour rester dans des limites de user script WebKit.
    private static func jpegDataURLFromXcodeSpinflyerAsset() -> String? {
        guard let ui = UIImage(named: "spinflyer") else { return nil }
        let maxSide: CGFloat = 900
        let s = max(ui.size.width, ui.size.height)
        let scale = s > maxSide ? maxSide / s : 1
        let newSize = CGSize(width: max(1, ui.size.width * scale), height: max(1, ui.size.height * scale))
        let img: UIImage
        if scale < 0.999 {
            let r = UIGraphicsImageRenderer(size: newSize)
            img = r.image { _ in ui.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            img = ui
        }
        guard let j = img.jpegData(compressionQuality: 0.86), !j.isEmpty else { return nil }
        return "data:image/jpeg;base64,\(j.base64EncodedString())"
    }

    static func addTo(_ config: WKWebViewConfiguration) {
        let u = jsEscapedString(preferredTextureAbsoluteURL)
        let source = """
        (function(){
          const U_FIX='\(u)';
          if(!U_FIX)return;
          const isSpin = function(s){
            try {
              if (typeof s !== 'string') { return false; }
              if (s.indexOf('spinflyer') >= 0 && s.toLowerCase().indexOf('.png') > 0) { return true; }
              if (s.indexOf('/flyer-wheels/') >= 0 || s.indexOf('flyer-wheels') >= 0) { return true; }
              if (s.indexOf('/assets/spinflyer') >= 0) { return true; }
            } catch(e) { return false; }
            return false;
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
