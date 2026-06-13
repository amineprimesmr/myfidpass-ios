//
//  MerchantProgramFlyerSupport.swift
//  myfidpass — extrait de MerchantProgramHubView.swift
//

import SwiftUI
import UIKit

// MARK: - Flyer QR (édition in-app + aperçu)

/// Plafonds `fidelity/backend/src/lib/flyer-prefs.js` : logo &lt; 5 Mo, fond &lt; 6 Mo (longueur chaîne), JSON `flyer_prefs` total plafonné (`MAX_JSON_CHARS`).
/// Le logo et le fond doivent tenir **ensemble** dans le JSON : on cible des data URLs nettement sous les plafonds par champ.
enum FlyerDashboardFlyerPrefsLimits {
    /// Marge sous `MAX_JSON_CHARS` côté API (évite 400 « Flyer trop volumineux » après stringify serveur).
    static let serverFlyerPrefsJSONMaxBytes = 10 * 1024 * 1024 - 384_000
    static let maxBgDataURLUtf8Bytes = 6 * 1024 * 1024 - 1
    static let maxLogoDataURLUtf8Bytes = 5 * 1024 * 1024 - 1
    /// JPEG décodé pour le fond IA : marge avec logo (~2,4 Mo de chaîne max) + `state` dans le même JSON.
    static let aiBackgroundJPEGMaxDecodedBytes = 2_800_000
    /// Chaîne `custom_logo_data_url` (souvent JPEG) — cible sous le plafond JSON avec `flyerLogoExportDataURLReliable`.
    static let logoPngMaxEncodedUtf8Bytes = 2_400_000
}

enum FlyerGeneratedImageDecode {
    /// `UIImage(data:)` échoue parfois (profils ICC, PNG exotiques) — même stratégème que le sélecteur photo.
    static func uiImage(fromBase64PNG raw: String) -> UIImage? {
        guard let data = Data(base64Encoded: raw), !data.isEmpty else { return nil }
        if let u = UIImage(data: data) { return u }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return UIImage(cgImage: cg, scale: 1.0, orientation: .up)
    }
}

/// Sauvegarde du fond IA généré sur disque entre les sessions — survit à un force-quit.
/// Effacé après enregistrement serveur réussi ; restauré au prochain lancement si le serveur n’a pas encore le fond.
final class FlyerPendingBgStorage {
    static let shared = FlyerPendingBgStorage()
    private init() {}

    private func fileURL(slug: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let safe = slug.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "flyer"
        return caches.appendingPathComponent("flyerPendingBg_\(safe).dat")
    }

    func save(pngBase64: String, slug: String) {
        guard !pngBase64.isEmpty, let data = Data(base64Encoded: pngBase64) else { return }
        try? data.write(to: fileURL(slug: slug), options: .atomic)
    }

    func loadBase64(slug: String) -> String? {
        let url = fileURL(slug: slug)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return data.base64EncodedString()
    }

    func clear(slug: String) {
        try? FileManager.default.removeItem(at: fileURL(slug: slug))
    }

    func hasPending(slug: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(slug: slug).path)
    }
}

/// Copie de l’illustration **avant** un « Recréer » — indépendant de `flyerPendingBg`.
final class FlyerRecreatePreviousBackupStorage {
    static let shared = FlyerRecreatePreviousBackupStorage()
    private init() {}

    private func fileURL(slug: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let safe = slug.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "flyer"
        return caches.appendingPathComponent("flyerRecreatePrevious_\(safe).dat")
    }

    func save(rawBase64: String, slug: String) {
        guard !rawBase64.isEmpty, let data = Data(base64Encoded: rawBase64) else { return }
        try? data.write(to: fileURL(slug: slug), options: .atomic)
    }

    func loadBase64(slug: String) -> String? {
        let url = fileURL(slug: slug)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return data.base64EncodedString()
    }

    func clear(slug: String) {
        try? FileManager.default.removeItem(at: fileURL(slug: slug))
    }
}

/// Décode `data:image/…;base64,…` (PNG, JPEG, WebP) — même fond qu’après GET dashboard.
enum FlyerDataURLImageDecode {
    static func uiImage(fromDataURLString s: String?) -> UIImage? {
        let t = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard t.hasPrefix("data:image/"), let comma = t.firstIndex(of: ",") else { return nil }
        let b64 = String(t[t.index(after: comma)...])
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        return FlyerGeneratedImageDecode.uiImage(fromBase64PNG: b64)
    }
}

struct FlyerEditSnapshot: Equatable {
    var state: FlyerStateDTO
    var logo: FlyerRemoteImagePayload
    var bg: FlyerRemoteImagePayload
}

enum FlyerBackgroundSelectionState: Equatable {
    case none
    case template(String)
    case custom
}
