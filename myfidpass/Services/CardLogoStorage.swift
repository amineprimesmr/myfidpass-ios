//
//  CardLogoStorage.swift
//  myfidpass
//
//  Médias carte en attente d’envoi API — **un dossier par commerce** (`CardLogos/{slug}/…`).
//  Les anciens chemins plats (`CardLogos/cardLogo.png`) ne doivent plus être réutilisés entre comptes.
//

import UIKit

enum CardLogoStorage {
    private static func notifyLocalFileChanged() {
        NotificationCenter.default.post(name: .myfidpassCardLocalAssetFileWritten, object: nil)
    }

    private static let subfolder = "CardLogos"
    private static let filename = "cardLogo.png"
    private static let iconFilename = "cardLogoIcon.png"
    private static let cardBackgroundFilename = "cardBackground.png"

    /// Chemins plats historiques (pré multi-commerce) — lecture / migration uniquement.
    static let legacyRelativeLogoPath = "\(subfolder)/\(filename)"
    static let legacyRelativeLogoIconPath = "\(subfolder)/\(iconFilename)"
    static let legacyRelativeCardBackgroundPath = "\(subfolder)/\(cardBackgroundFilename)"

    private static func safeSlug(_ slug: String) -> String {
        let t = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "_unknown" }
        return t
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "..", with: "_")
    }

    static func relativeLogoPath(for slug: String) -> String {
        "\(subfolder)/\(safeSlug(slug))/\(filename)"
    }

    static func relativeLogoIconPath(for slug: String) -> String {
        "\(subfolder)/\(safeSlug(slug))/\(iconFilename)"
    }

    static func relativeCardBackgroundPath(for slug: String) -> String {
        "\(subfolder)/\(safeSlug(slug))/\(cardBackgroundFilename)"
    }

    /// Référence locale en attente d’envoi (pas encore une URL API) : ne pas écraser avec une réponse serveur.
    static func isLocalPendingLogoReference(_ value: String) -> Bool {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        if t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://") { return false }
        return t.contains(subfolder) || t.hasPrefix("/") || t.hasPrefix("file:")
    }

    static func isLocalPendingLogoIconReference(_ value: String) -> Bool {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        if t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://") { return false }
        if t == legacyRelativeLogoIconPath || (t.contains(subfolder) && t.hasSuffix(iconFilename)) { return true }
        return t.hasPrefix("/") || t.hasPrefix("file:")
    }

    /// `true` si le chemin local appartient à **ce** commerce (évite le logo/fond d’un autre compte).
    static func belongsToBusiness(_ storedPath: String, slug: String) -> Bool {
        let t = storedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        if t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://") { return false }
        let ownedPrefix = "\(subfolder)/\(safeSlug(slug))/"
        if t.contains(ownedPrefix) { return true }
        let legacyPaths = [legacyRelativeLogoPath, legacyRelativeLogoIconPath, legacyRelativeCardBackgroundPath]
        if legacyPaths.contains(t) || legacyPaths.contains(where: { t.hasSuffix("/\($0.components(separatedBy: "/").last ?? "")") && !t.contains(ownedPrefix) }) {
            return MerchantMediaUploadOwnership.lastOwnerSlug == slug
        }
        return false
    }

    static func isLocalPendingLogoReference(_ value: String, slug: String) -> Bool {
        isLocalPendingLogoReference(value) && belongsToBusiness(value, slug: slug)
    }

    static func isLocalPendingLogoIconReference(_ value: String, slug: String) -> Bool {
        isLocalPendingLogoIconReference(value) && belongsToBusiness(value, slug: slug)
    }

    static var directoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent(subfolder, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func directoryURL(for slug: String) -> URL {
        let dir = directoryURL.appendingPathComponent(safeSlug(slug), isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Copie les fichiers plats legacy vers `CardLogos/{slug}/` si ce commerce en était propriétaire.
    static func migrateLegacyFlatAssetsIfNeeded(for slug: String) {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let owner = MerchantMediaUploadOwnership.lastOwnerSlug
        guard owner == nil || owner == trimmed else { return }
        let fm = FileManager.default
        let dest = directoryURL(for: trimmed)
        let pairs: [(String, String)] = [
            (legacyRelativeLogoPath, filename),
            (legacyRelativeLogoIconPath, iconFilename),
            (legacyRelativeCardBackgroundPath, cardBackgroundFilename),
        ]
        for (legacyRel, name) in pairs {
            guard let legacyFull = fullPath(forRelative: legacyRel), fm.fileExists(atPath: legacyFull) else { continue }
            let target = dest.appendingPathComponent(name)
            if !fm.fileExists(atPath: target.path) {
                try? fm.copyItem(at: URL(fileURLWithPath: legacyFull), to: target)
            }
        }
    }

    static func localLogoPathIfExists(for slug: String) -> String? {
        migrateLegacyFlatAssetsIfNeeded(for: slug)
        let rel = relativeLogoPath(for: slug)
        guard let full = fullPath(forRelative: rel), FileManager.default.fileExists(atPath: full) else { return nil }
        return rel
    }

    static func localCardBackgroundPathIfExists(for slug: String) -> String? {
        migrateLegacyFlatAssetsIfNeeded(for: slug)
        let rel = relativeCardBackgroundPath(for: slug)
        guard let full = fullPath(forRelative: rel), FileManager.default.fileExists(atPath: full) else { return nil }
        return rel
    }

    static func saveImage(_ image: UIImage, slug: String) -> String? {
        migrateLegacyFlatAssetsIfNeeded(for: slug)
        let url = directoryURL(for: slug).appendingPathComponent(filename)
        guard let data = image.pngData() else { return nil }
        do {
            try data.write(to: url)
            MerchantMediaUploadOwnership.recordLogoUpload(for: slug)
            notifyLocalFileChanged()
            return relativeLogoPath(for: slug)
        } catch {
            return nil
        }
    }

    static func saveLogoIconImage(_ image: UIImage, slug: String) -> String? {
        migrateLegacyFlatAssetsIfNeeded(for: slug)
        let url = directoryURL(for: slug).appendingPathComponent(iconFilename)
        guard let data = image.pngData() else { return nil }
        do {
            try data.write(to: url)
            MerchantMediaUploadOwnership.recordLogoIconUpload(for: slug)
            notifyLocalFileChanged()
            return relativeLogoIconPath(for: slug)
        } catch {
            return nil
        }
    }

    static func saveCardBackground(_ image: UIImage, slug: String) -> String? {
        migrateLegacyFlatAssetsIfNeeded(for: slug)
        let url = directoryURL(for: slug).appendingPathComponent(cardBackgroundFilename)
        let flat = image.imageOrientation == .up ? image : flattenOrientation(image)
        guard let data = flat.pngData() else { return nil }
        do {
            try data.write(to: url)
            MerchantMediaUploadOwnership.recordCardBackgroundUpload(for: slug)
            notifyLocalFileChanged()
            return relativeCardBackgroundPath(for: slug)
        } catch {
            return nil
        }
    }

    private static func flattenOrientation(_ image: UIImage) -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func removeLocalCardBackgroundFile(for slug: String) {
        let url = directoryURL(for: slug).appendingPathComponent(cardBackgroundFilename)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
            notifyLocalFileChanged()
        }
        let legacy = directoryURL.appendingPathComponent(cardBackgroundFilename)
        if FileManager.default.fileExists(atPath: legacy.path) {
            try? FileManager.default.removeItem(at: legacy)
            notifyLocalFileChanged()
        }
    }

    static func removeAllLocalCardAssets() {
        let fm = FileManager.default
        let root = directoryURL
        if fm.fileExists(atPath: root.path) {
            try? fm.removeItem(at: root)
            notifyLocalFileChanged()
        }
        MerchantMediaUploadOwnership.clearAll()
    }

    static func fullPath(forRelative relativePath: String) -> String? {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent(relativePath)
        return url.path
    }

    static func resolvedDisplayPath(forStoredPath path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else { return nil }
        if path.lowercased().hasPrefix("file:"), let u = URL(string: path) { return u.path }
        if path.hasPrefix("/") { return path }
        return fullPath(forRelative: path)
    }

    static func compressedBase64ForAPI(image: UIImage) -> String? {
        let maxSide: CGFloat = 800
        let size = image.size
        let scale = min(maxSide / max(size.width, size.height), 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return nil }
        return "data:image/jpeg;base64," + data.base64EncodedString()
    }

    private static let maxLogoUploadBytes = 4 * 1024 * 1024

    static func compressedWalletStripLogoBase64ForAPI(image: UIImage) -> String? {
        var maxSide: CGFloat = 800
        while maxSide >= 200 {
            let size = image.size
            let scale = min(maxSide / max(size.width, size.height), 1)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
            if let data = resized.pngData(), data.count <= maxLogoUploadBytes {
                return "data:image/png;base64," + data.base64EncodedString()
            }
            maxSide -= 120
        }
        return nil
    }

    static func compressedBase64ForLogoIconAPI(image: UIImage) -> String? {
        let maxBytes = 500 * 1024
        var maxSide: CGFloat = 512
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        while maxSide >= 200 {
            let size = image.size
            let scale = min(maxSide / max(size.width, size.height), 1)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
            let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
            var q: CGFloat = 0.82
            while q >= 0.38 {
                if let data = resized.jpegData(compressionQuality: q), data.count <= maxBytes {
                    return "data:image/jpeg;base64," + data.base64EncodedString()
                }
                q -= 0.07
            }
            maxSide -= 80
        }
        return nil
    }

    static func compressedBase64FromFile(path: String) -> String? {
        guard let image = imageFromResolvedPath(path) else { return nil }
        return compressedBase64ForAPI(image: image)
    }

    static func compressedWalletStripLogoBase64FromFile(path: String) -> String? {
        guard let image = imageFromResolvedPath(path) else { return nil }
        return compressedWalletStripLogoBase64ForAPI(image: image)
    }

    static func compressedBase64LogoIconFromFile(path: String) -> String? {
        guard let image = imageFromResolvedPath(path) else { return nil }
        return compressedBase64ForLogoIconAPI(image: image)
    }

    private static func imageFromResolvedPath(_ path: String) -> UIImage? {
        let resolvedPath: String
        if path.hasPrefix("/") || path.hasPrefix("file:") {
            resolvedPath = path.hasPrefix("file:") ? (URL(string: path)?.path ?? path) : path
        } else {
            guard let full = fullPath(forRelative: path) else { return nil }
            resolvedPath = full
        }
        return ImageIODownsampling.imageFromFile(at: resolvedPath, maxPixelDimension: 8192)
    }
}

/// Horodatages et propriétaire des uploads locaux — **par slug** (évite de mélanger deux commerces).
enum MerchantMediaUploadOwnership {
    private static let ownerSlugKey = "myfidpass.merchantMediaUploadOwnerSlug"

    static var lastOwnerSlug: String? {
        UserDefaults.standard.string(forKey: ownerSlugKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    static func lastLogoUploadDate(for slug: String) -> Date? {
        UserDefaults.standard.object(forKey: logoUploadKey(slug)) as? Date
    }

    static func lastLogoIconUploadDate(for slug: String) -> Date? {
        UserDefaults.standard.object(forKey: logoIconUploadKey(slug)) as? Date
    }

    static func recordLogoUpload(for slug: String) {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        UserDefaults.standard.set(Date(), forKey: logoUploadKey(s))
        UserDefaults.standard.set(s, forKey: ownerSlugKey)
    }

    static func recordLogoIconUpload(for slug: String) {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        UserDefaults.standard.set(Date(), forKey: logoIconUploadKey(s))
        UserDefaults.standard.set(s, forKey: ownerSlugKey)
    }

    static func recordCardBackgroundUpload(for slug: String) {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        UserDefaults.standard.set(s, forKey: ownerSlugKey)
    }

    static func clearAll() {
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        for k in keys where k.hasPrefix("myfidpass.lastLogoUploadAt.")
            || k.hasPrefix("myfidpass.lastLogoIconUploadAt.")
            || k.hasPrefix("myfidpass.merchantLogoStripeServerCacheDate.")
            || k.hasPrefix("myfidpass.merchantLogoIconServerCacheDate.") {
            UserDefaults.standard.removeObject(forKey: k)
        }
        UserDefaults.standard.removeObject(forKey: ownerSlugKey)
        UserDefaults.standard.removeObject(forKey: "myfidpass.lastLogoUploadAt")
        UserDefaults.standard.removeObject(forKey: "myfidpass.lastLogoIconUploadAt")
    }

    private static func logoUploadKey(_ slug: String) -> String {
        "myfidpass.lastLogoUploadAt.\(slug)"
    }

    private static func logoIconUploadKey(_ slug: String) -> String {
        "myfidpass.lastLogoIconUploadAt.\(slug)"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
