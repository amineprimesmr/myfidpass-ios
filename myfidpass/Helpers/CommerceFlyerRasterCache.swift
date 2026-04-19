//
//  CommerceFlyerRasterCache.swift
//  myfidpass
//
//  Cache mémoire du fond flyer (data URL → UIImage) pour éviter un décodage base64
//  à chaque apparition de l’onglet Commerce / chaque sync.
//

import UIKit

/// Empreinte courte (longueurs + hash d’échantillons) : évite de mettre des Mo de base64 dans `.task(id:)`
/// et reste stable tant que le fond + le bootstrap ne changent pas (contrairement à `updated_at` dans le JSON).
enum CommerceFlyerHydrationFingerprint {
    static func token(slug: String?, customBg: String?, bootstrapB64: String?) -> String {
        let s = slug ?? ""
        let b = customBg ?? ""
        let b64 = bootstrapB64 ?? ""
        let sample = "\(String(b.prefix(2_000)))\(String(b.suffix(2_000)))\(String(b64.prefix(4_000)))\(String(b64.suffix(4_000)))"
        var h: UInt64 = 5381
        for u in sample.utf8 {
            h = h &* 33 &+ UInt64(u)
        }
        return "\(s)|\(b.count)|\(b64.count)|\(h)"
    }
}

enum CommerceFlyerRasterCache {
    private static let decodedBg = NSCache<NSString, UIImage>()

    static func image(forCustomBgDataURL key: String) -> UIImage? {
        decodedBg.object(forKey: key as NSString)
    }

    static func setImage(_ image: UIImage, forCustomBgDataURL key: String) {
        decodedBg.setObject(image, forKey: key as NSString)
    }
}
