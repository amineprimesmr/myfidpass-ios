//
//  CardLogoStorage.swift
//  myfidpass
//
//  Sauvegarde du logo de carte choisi depuis la photothèque (fichier local pour l’aperçu).
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

    /// Chemin relatif pour stockage persistant (évite chemins absolus qui changent après mise à jour app).
    static let relativeLogoPath = "\(subfolder)/\(filename)"
    /// Logo carré (notifications / profil) — fichier distinct du bandeau pour ne pas l’écraser.
    static let relativeLogoIconPath = "\(subfolder)/\(iconFilename)"
    static let relativeCardBackgroundPath = "\(subfolder)/\(cardBackgroundFilename)"

    /// Référence locale en attente d’envoi (pas encore une URL API) : ne pas écraser avec une réponse serveur.
    static func isLocalPendingLogoReference(_ value: String) -> Bool {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        if t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://") { return false }
        return t.contains(subfolder) || t.hasPrefix("/") || t.hasPrefix("file:")
    }

    /// Logo carré : fichier dédié ou chemin fichier absolu. (L’ancienne app utilisait `cardLogo.png` pour l’icône : on laisse le serveur corriger.)
    static func isLocalPendingLogoIconReference(_ value: String) -> Bool {
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return false }
        if t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://") { return false }
        if t.contains(relativeLogoIconPath) || t.hasSuffix(iconFilename) { return true }
        return t.hasPrefix("/") || t.hasPrefix("file:")
    }

    static var directoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent(subfolder, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Enregistre l’image et retourne le chemin pour l’affichage (ou nil en cas d’échec).
    static func saveImage(_ image: UIImage) -> String? {
        let url = directoryURL.appendingPathComponent(filename)
        guard let data = image.pngData() else { return nil }
        do {
            try data.write(to: url)
            notifyLocalFileChanged()
            return relativeLogoPath
        } catch {
            return nil
        }
    }

    /// Logo carré (512 px recommandé) — fichier dédié `cardLogoIcon.png`.
    static func saveLogoIconImage(_ image: UIImage) -> String? {
        let url = directoryURL.appendingPathComponent(iconFilename)
        guard let data = image.pngData() else { return nil }
        do {
            try data.write(to: url)
            notifyLocalFileChanged()
            return relativeLogoIconPath
        } catch {
            return nil
        }
    }

    /// Enregistre l'image de fond de carte (strip Wallet) et retourne le chemin relatif.
    static func saveCardBackground(_ image: UIImage) -> String? {
        let url = directoryURL.appendingPathComponent(cardBackgroundFilename)
        let flat = image.imageOrientation == .up ? image : flattenOrientation(image)
        guard let data = flat.pngData() else { return nil }
        do {
            try data.write(to: url)
            notifyLocalFileChanged()
            return relativeCardBackgroundPath
        } catch {
            return nil
        }
    }

    /// Aplatit la rotation EXIF dans un nouveau bitmap `.up` — `pngData()` ne bake pas l’orientation.
    private static func flattenOrientation(_ image: UIImage) -> UIImage {
        guard image.size.width > 0, image.size.height > 0 else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Supprime le fichier image de fond (ex. après retrait dans l’UI ou changement de compte).
    static func removeLocalCardBackgroundFile() {
        let url = directoryURL.appendingPathComponent(cardBackgroundFilename)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
            notifyLocalFileChanged()
        }
    }

    /// Déconnexion / reset compte : logos + fond carte locaux (chemins globaux, pas liés au slug sur disque).
    static func removeAllLocalCardAssets() {
        let fm = FileManager.default
        var removedAny = false
        for name in [filename, iconFilename, cardBackgroundFilename] {
            let url = directoryURL.appendingPathComponent(name)
            if fm.fileExists(atPath: url.path) {
                try? fm.removeItem(at: url)
                removedAny = true
            }
        }
        if removedAny { notifyLocalFileChanged() }
    }

    /// Retourne le chemin complet pour un chemin relatif (ex. CardLogos/cardLogo.png).
    static func fullPath(forRelative relativePath: String) -> String? {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent(relativePath)
        return url.path
    }

    /// Chemin fichier pour l’aperçu carte : relatif `CardLogos/...`, absolu `/var/...`, ou `file:`.
    static func resolvedDisplayPath(forStoredPath path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else { return nil }
        if path.lowercased().hasPrefix("file:"), let u = URL(string: path) { return u.path }
        if path.hasPrefix("/") { return path }
        return fullPath(forRelative: path)
    }

    /// Compresse pour le **fond de carte** (strip) : JPEG — photos, pas besoin d’alpha.
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

    /// Logo bandeau Wallet (coin haut gauche) : **PNG** pour garder la transparence. Le JPEG ci-dessus tue l’alpha → bloc blanc sur la carte réelle.
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
            let resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            if let data = resized.pngData(), data.count <= maxLogoUploadBytes {
                return "data:image/png;base64," + data.base64EncodedString()
            }
            maxSide -= 120
        }
        return nil
    }

    /// Compresse pour `logo_icon_base64` : le backend refuse au-delà de 512 Ko (octets décodés).
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

    /// Charge l'image depuis le chemin (relatif ou absolu) et retourne le base64 JPEG pour l'API (fond de carte), ou nil.
    static func compressedBase64FromFile(path: String) -> String? {
        let resolvedPath: String
        if path.hasPrefix("/") || path.hasPrefix("file:") {
            resolvedPath = path.hasPrefix("file:") ? (URL(string: path)?.path ?? path) : path
        } else {
            guard let full = fullPath(forRelative: path) else { return nil }
            resolvedPath = full
        }
        guard let image = ImageIODownsampling.imageFromFile(at: resolvedPath, maxPixelDimension: 8192) else { return nil }
        return compressedBase64ForAPI(image: image)
    }

    /// Logo bandeau Wallet depuis fichier : PNG avec alpha (même résolution de chemin que `compressedBase64FromFile`).
    static func compressedWalletStripLogoBase64FromFile(path: String) -> String? {
        let resolvedPath: String
        if path.hasPrefix("/") || path.hasPrefix("file:") {
            resolvedPath = path.hasPrefix("file:") ? (URL(string: path)?.path ?? path) : path
        } else {
            guard let full = fullPath(forRelative: path) else { return nil }
            resolvedPath = full
        }
        guard let image = ImageIODownsampling.imageFromFile(at: resolvedPath, maxPixelDimension: 8192) else { return nil }
        return compressedWalletStripLogoBase64ForAPI(image: image)
    }

    /// Base64 logo carré depuis fichier (même résolution de chemin que `compressedBase64FromFile`).
    static func compressedBase64LogoIconFromFile(path: String) -> String? {
        let resolvedPath: String
        if path.hasPrefix("/") || path.hasPrefix("file:") {
            resolvedPath = path.hasPrefix("file:") ? (URL(string: path)?.path ?? path) : path
        } else {
            guard let full = fullPath(forRelative: path) else { return nil }
            resolvedPath = full
        }
        guard let image = ImageIODownsampling.imageFromFile(at: resolvedPath, maxPixelDimension: 8192) else { return nil }
        return compressedBase64ForLogoIconAPI(image: image)
    }
}
