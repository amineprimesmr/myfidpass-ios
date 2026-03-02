//
//  CardLogoStorage.swift
//  myfidpass
//
//  Sauvegarde du logo de carte choisi depuis la photothèque (fichier local pour l’aperçu).
//

import UIKit

enum CardLogoStorage {
    private static let subfolder = "CardLogos"
    private static let filename = "cardLogo.png"

    /// Chemin relatif pour stockage persistant (évite chemins absolus qui changent après mise à jour app).
    static let relativeLogoPath = "\(subfolder)/\(filename)"

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
            return relativeLogoPath
        } catch {
            return nil
        }
    }

    /// Retourne le chemin complet pour un chemin relatif (ex. CardLogos/cardLogo.png).
    static func fullPath(forRelative relativePath: String) -> String? {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent(relativePath)
        return url.path
    }

    /// Compresse l'image pour l'envoi API (max 800 px, JPEG 0.85) — évite dépassement 4 Mo et synchro avec le SaaS.
    static func compressedBase64ForAPI(image: UIImage) -> String? {
        let maxSide: CGFloat = 800
        let size = image.size
        let scale = min(maxSide / max(size.width, size.height), 1)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let img = resized, let data = img.jpegData(compressionQuality: 0.85) else { return nil }
        return "data:image/jpeg;base64," + data.base64EncodedString()
    }

    /// Charge l'image depuis le chemin (relatif ou absolu) et retourne le base64 compressé pour l'API, ou nil.
    static func compressedBase64FromFile(path: String) -> String? {
        let resolvedPath: String
        if path.hasPrefix("/") || path.hasPrefix("file:") {
            resolvedPath = path.hasPrefix("file:") ? (URL(string: path)?.path ?? path) : path
        } else {
            guard let full = fullPath(forRelative: path) else { return nil }
            resolvedPath = full
        }
        guard let image = UIImage(contentsOfFile: resolvedPath) else { return nil }
        return compressedBase64ForAPI(image: image)
    }
}
