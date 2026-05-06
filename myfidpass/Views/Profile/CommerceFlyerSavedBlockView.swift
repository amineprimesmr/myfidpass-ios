//
//  CommerceFlyerSavedBlockView.swift
//  myfidpass
//
//  Utilitaires de chargement de l'image de fond du flyer (réseau + cache).
//

import UIKit
import ImageIO

/// Même fichier que `custom_bg_data_url` dans les prefs : `GET …/public/flyer-custom-bg` (robuste si le GET JSON ne renvoie pas le data URL complet côté app).
enum CommerceFlyerPublicBgThumbnail {
    private static func uiImageFromImageData(_ data: Data, screenScale: CGFloat) -> UIImage? {
        if let u = UIImage(data: data) { return u }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return UIImage(cgImage: cg, scale: screenScale, orientation: .up)
    }

    /// Mémoire → disque (dernier GET) → réseau ; remplit cache pour la prochaine ouverture Commerce.
    static func loadUIImage(slug: String, revisionKey: String? = nil) async -> UIImage? {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let mem = CommerceFlyerRasterCache.image(forPublicFlyerBgSlug: trimmed, revisionKey: revisionKey) {
            return mem
        }
        let screenScale = await MainActor.run { UITraitCollection.current.displayScale }
        if let disk = CommerceFlyerStateCache.readPublicFlyerBackgroundImageData(slug: trimmed, revisionKey: revisionKey) {
            let ui = await Task.detached(priority: .userInitiated) {
                uiImageFromImageData(disk, screenScale: screenScale)
            }.value
            if let ui {
                await MainActor.run { CommerceFlyerRasterCache.setPublicFlyerBgImage(ui, slug: trimmed, revisionKey: revisionKey) }
                return ui
            }
        }
        let enc = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmed
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/businesses/\(enc)/public/flyer-custom-bg") else { return nil }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 25
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode), !data.isEmpty else { return nil }
            let ui = await Task.detached(priority: .userInitiated) {
                uiImageFromImageData(data, screenScale: screenScale)
            }.value
            guard let ui else { return nil }
            await MainActor.run {
                CommerceFlyerRasterCache.setPublicFlyerBgImage(ui, slug: trimmed, revisionKey: revisionKey)
            }
            CommerceFlyerStateCache.writePublicFlyerBackgroundImageData(data, slug: trimmed, revisionKey: revisionKey)
            return ui
        } catch {
            return nil
        }
    }
}


// MARK: - Précache GET public (remplit le fichier disque pour l'ouverture suivante de l'onglet Commerce)

enum CommerceFlyerPublicBackgroundWarmup {
    /// Quand le dashboard ne fournit pas de `data:` complet, l'app charge `…/public/flyer-custom-bg` : on remplit le cache tôt.
    static func prefetchFromNetworkIfNoCustomBgInPrefs(slug: String, customBgDataUrl: String?, revisionKey: String? = nil) {
        let c = (customBgDataUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !c.isEmpty { return }
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        Task(priority: .utility) {
            if CommerceFlyerRasterCache.image(forPublicFlyerBgSlug: s, revisionKey: revisionKey) != nil { return }
            if CommerceFlyerStateCache.readPublicFlyerBackgroundImageData(slug: s, revisionKey: revisionKey) != nil { return }
            _ = await CommerceFlyerPublicBgThumbnail.loadUIImage(slug: s, revisionKey: revisionKey)
        }
    }
}
