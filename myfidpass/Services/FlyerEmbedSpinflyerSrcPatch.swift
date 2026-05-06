//
//  FlyerEmbedSpinflyerSrcPatch.swift
//  myfidpass
//
//  Aperçu `WKWebView` : le bundle web charge `/assets/spinflyer…`, `/assets/giftflyer…`, etc.
//  Sous iOS, ces requêtes ne passent souvent **pas** comme dans le navigateur (domaine, cache) → cadeau / promo
//  invisibles. On **réécrit** la même manière qu’`spinflyer` via `data:` depuis l’asset catalogue.
//  **Ne jamais** confondre avec d’éventuels `data:image/…` déjà en base64 (logos) : on ne cible que des `src` HTTP
//  contenant clairement `spinflyer` / `giftflyer` (voir garde côté JS).
//

import Foundation
import UIKit
import WebKit

enum FlyerEmbedSpinflyerSrcPatch {
    private static let defaultsKey = "myfidpass.flyerEmbed.spinflyerAssetAbsoluteURL"
    /// Dernier chemin connu côté build Vite (vérifié 200) — le refresh tâche de fond met à jour quand le hash change.
    private static let fallbackTextureURL = "https://www.myfidpass.fr/assets/flyer-wheels/spinflyer.png"
    private static var cachedXcodeTextureDataURL: String?
    private static var cachedXcodeGiftflyerDataURL: String?
    private static let defaultsKeyGift = "myfidpass.flyerEmbed.giftflyerAssetAbsoluteURL"

    /// Texture injectée dans le patch `src` (Xcode d’abord, puis cache réseau, puis URL fixe myfidpass.fr).
    static var preferredTextureAbsoluteURL: String {
        if cachedXcodeTextureDataURL == nil, let fromAsset = Self.pngDataURLFromXcodeSpinflyerAsset() {
            cachedXcodeTextureDataURL = fromAsset
        }
        if let c = cachedXcodeTextureDataURL, !c.isEmpty { return c }
        if let c = UserDefaults.standard.string(forKey: defaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            let lc = c.lowercased()
            if (c.hasPrefix("http://") || c.hasPrefix("https://")) && lc.contains("spinflyer") { return c }
        }
        return fallbackTextureURL
    }

    /// Image catalogue `spinflyer` — **PNG** pour conserver l’alpha (le JPEG y ajoutait un fond blanc plein sur l’aperçu WK).
    /// Taille ajustée pour rester < ~200 k car. UTF-8 de data URL (scripts WK) ; repli rare en JPEG.
    private static func pngDataURLFromXcodeSpinflyerAsset() -> String? {
        guard let ui = UIImage(named: "spinflyer") else { return nil }
        let imgScale = max(1.0, ui.scale)
        let pw = ui.size.width * imgScale
        let ph = ui.size.height * imgScale
        let longer0 = max(pw, ph)
        let maxUtf8 = 200_000
        let maxSideSteps: [CGFloat] = [512, 448, 384, 320, 280, 256, 220, 192]
        for maxPx in maxSideSteps {
            let factor = longer0 > maxPx ? maxPx / longer0 : 1.0
            let targetW = max(1, (pw * factor).rounded())
            let targetH = max(1, (ph * factor).rounded())
            let rendered = renderSpinflyerForDataURL(ui, targetW: targetW, targetH: targetH)
            if let p = rendered.pngData(), !p.isEmpty {
                let s = "data:image/png;base64,\(p.base64EncodedString())"
                if s.utf8.count <= maxUtf8 { return s }
            }
        }
        for maxPx in maxSideSteps {
            let factor = longer0 > maxPx ? maxPx / longer0 : 1.0
            let targetW = max(1, (pw * factor).rounded())
            let targetH = max(1, (ph * factor).rounded())
            let rendered = renderSpinflyerForDataURL(ui, targetW: targetW, targetH: targetH)
            if let j = rendered.jpegData(compressionQuality: 0.72), !j.isEmpty {
                let s = "data:image/jpeg;base64,\(j.base64EncodedString())"
                if s.utf8.count <= maxUtf8 { return s }
            }
        }
        return nil
    }

    private static func renderSpinflyerForDataURL(_ ui: UIImage, targetW: CGFloat, targetH: CGFloat) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat()
        fmt.opaque = false
        fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetW, height: targetH), format: fmt)
        return renderer.image { _ in
            ui.draw(in: CGRect(origin: .zero, size: CGSize(width: targetW, height: targetH)))
        }
    }

    /// Cadeau au centre de la roue (`drawFlyerGiftflyerPromo` dans le bundle) — réécriture pour WK comme `spinflyer`.
    private static var preferredGiftflyerAbsoluteURL: String {
        if cachedXcodeGiftflyerDataURL == nil, let fromAsset = Self.jpegDataURLFromXcodeGiftflyerAsset() {
            cachedXcodeGiftflyerDataURL = fromAsset
        }
        if let c = cachedXcodeGiftflyerDataURL, !c.isEmpty { return c }
        if let c = UserDefaults.standard.string(forKey: defaultsKeyGift)?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty,
           (c.hasPrefix("http://") || c.hasPrefix("https://")),
           c.lowercased().contains("giftflyer")
        {
            return c
        }
        return ""
    }

    /// Même principe que `spinflyer` — mais **PNG impératif** pour préserver l’alpha (sinon fond noir en JPEG).
    /// Rendu en pixels réels (scale=1.0) pour limiter la taille de la base64 dans WKUserScript.
    private static func jpegDataURLFromXcodeGiftflyerAsset() -> String? {
        guard let ui = UIImage(named: "giftflyer") else { return nil }
        let imgScale = max(1.0, ui.scale)
        let pw = ui.size.width * imgScale
        let ph = ui.size.height * imgScale
        let longer = max(pw, ph)
        let maxPx: CGFloat = 512
        let factor = longer > maxPx ? maxPx / longer : 1.0
        let targetW = max(1, (pw * factor).rounded())
        let targetH = max(1, (ph * factor).rounded())
        let fmt = UIGraphicsImageRendererFormat()
        fmt.opaque = false
        fmt.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetW, height: targetH), format: fmt)
        let rendered = renderer.image { _ in
            ui.draw(in: CGRect(origin: .zero, size: CGSize(width: targetW, height: targetH)))
        }
        if let p = rendered.pngData(), !p.isEmpty {
            return "data:image/png;base64,\(p.base64EncodedString())"
        }
        if let j = rendered.jpegData(compressionQuality: 0.86), !j.isEmpty {
            return "data:image/jpeg;base64,\(j.base64EncodedString())"
        }
        return nil
    }

    static func addTo(_ config: WKWebViewConfiguration) {
        let u = jsEscapedString(preferredTextureAbsoluteURL)
        let g = jsEscapedString(preferredGiftflyerAbsoluteURL)
        let source = """
        (function(){
          const U_FIX='\(u)';
          const G_FIX='\(g)';
          if (U_FIX) { window.__FIDPASS_SPINFLYER_DATA_URL = U_FIX; }
          if (G_FIX) { window.__FIDPASS_GIFTFLYER_DATA_URL = G_FIX; }
          if (!U_FIX && !G_FIX) { return; }
          const isSpin = function(s){
            try {
              if (typeof s !== 'string') { return false; }
              if (s.indexOf('data:') === 0) { return false; }
              if (s.indexOf('spinflyer') >= 0 && s.toLowerCase().indexOf('.png') > 0) { return true; }
              if (s.toLowerCase().indexOf('flyergame') >= 0) { return true; }
              if (s.indexOf('/flyer-wheels/') >= 0 || s.indexOf('flyer-wheels') >= 0) { return true; }
              if (s.indexOf('/assets/spinflyer') >= 0) { return true; }
              if (s.indexOf('/assets/flyergame') >= 0) { return true; }
            } catch(e) { return false; }
            return false;
          };
          const isGift = function(s){
            try {
              if (typeof s !== 'string') { return false; }
              if (s.indexOf('data:') === 0) { return false; }
              if (s.toLowerCase().indexOf('giftflyer') >= 0) { return true; }
              if (s.indexOf('/assets/giftflyer') >= 0) { return true; }
            } catch(e) { return false; }
            return false;
          };
          const p = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
          if (!p || typeof p.set !== 'function') { return; }
          const oldSet = p.set;
          p.set = function(v) {
            if (U_FIX && isSpin(v)) { v = U_FIX; }
            else if (G_FIX && isGift(v)) { v = G_FIX; }
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

    /// Télécharge l’HTML + le bundle draw : met à jour l’URL absolue `spinflyer` **et** `giftflyer` (hashs Vite).
    static func refreshRemoteTexturePathIfNeeded() {
        Task.detached(priority: .utility) {
            await Self.resolveAndStoreTextureURLsFromRemote()
        }
    }

    private static func resolveAndStoreTextureURLsFromRemote() async {
        let base = "https://www.myfidpass.fr"
        do {
            let (htmlData, htmlResp) = try await URLSession.shared.data(
                for: URLRequest(url: APIConfig.flyerEmbedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            )
            guard (htmlResp as? HTTPURLResponse)?.statusCode == 200 else { return }
            guard let html = String(data: htmlData, encoding: .utf8) else { return }
            let drawName: String? = {
                if let r = html.range(of: #"/assets/app-flyer-qr-draw-[^"'\s>]+"#, options: .regularExpression) {
                    return String(html[r])
                }
                return nil
            }()
            guard let drawName else { return }
            let drawURL = URL(string: base + drawName) ?? APIConfig.flyerEmbedURL
            let (jsData, jsResp) = try await URLSession.shared.data(
                for: URLRequest(url: drawURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            )
            guard (jsResp as? HTTPURLResponse)?.statusCode == 200 else { return }
            guard let js = String(data: jsData, encoding: .utf8) else { return }
            if let sPath = extractSpinflyerAssetPath(from: js),
               (sPath.hasPrefix("/assets/spinflyer") || sPath.hasPrefix("/assets/flyer-wheels/spinflyer")) {
                let absURL = base + sPath
                await MainActor.run { UserDefaults.standard.set(absURL, forKey: Self.defaultsKey) }
            }
            if let gPath = extractGiftflyerAssetPath(from: js), gPath.hasPrefix("/assets/") {
                let absG = base + gPath
                await MainActor.run { UserDefaults.standard.set(absG, forKey: Self.defaultsKeyGift) }
            }
        } catch {
            return
        }
    }

    private static func extractGiftflyerAssetPath(from drawBundle: String) -> String? {
        // Chemin stable public/ (sans hash)
        if let r = drawBundle.range(of: #"/assets/flyer-wheels/giftflyer\.png"#, options: .regularExpression) {
            return String(drawBundle[r])
        }
        // Repli : ancien chemin hasché Vite
        if let r = drawBundle.range(of: #"/assets/giftflyer[^"']+"#, options: .regularExpression) {
            return String(drawBundle[r])
        }
        return nil
    }

    private static func extractSpinflyerAssetPath(from drawBundle: String) -> String? {
        // Chemin stable public/ (sans hash)
        if let r = drawBundle.range(of: #"/assets/flyer-wheels/spinflyer\.png"#, options: .regularExpression) {
            return String(drawBundle[r])
        }
        // Repli : ancien chemin hasché Vite
        if let r = drawBundle.range(of: #"/assets/spinflyer[^"']+"#, options: .regularExpression) {
            return String(drawBundle[r])
        }
        return nil
    }
}
