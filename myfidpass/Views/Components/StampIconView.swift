import ImageIO
import SwiftUI
import UIKit

enum StampIconCatalog {
    /// Noms d’`imageset` sous `Assets.xcassets/icons` (un tampon = une image).
    private static let rasterAssetNames: [String] = [
        "baguette",
        "burger",
        "cafe",
        "checkvert",
        "coiffeur",
        "croissant",
        "giftgold",
        "giftsilver",
        "kebab",
        "ongle",
        "pizza",
        "riz",
        "salade",
        "sourcil",
        "spa",
        "steak",
        "sushi",
    ]

    /// Clés affichées dans le sélecteur (champ serveur `stamp_emoji`).
    /// Les alias `darkburger` / `iconcafe` ne figurent pas ici (même visuel que `burger` / `cafe`) — ils restent résolus via `keyToRasterBase` pour l’existant.
    static let selectableKeys: [String] = {
        rasterAssetNames.sorted()
    }()

    /// Nom de l’imageset **sans** dossier (fichiers sous `Assets.xcassets/icons/*.imageset`).
    private static let keyToRasterBase: [String: String] = {
        var m: [String: String] = [:]
        for n in rasterAssetNames {
            m[n] = n
        }
        m["iconcafe"] = "cafe"
        m["darkburger"] = "burger"
        return m
    }()

    /// Anciens noms `Stamp*.imageset` à la racine du catalogue (avant déplacement dans `icons/`).
    private static let legacyStampAssetName: [String: String] = [
        "cafe": "StampCafe",
        "iconcafe": "StampIconcafe",
        "pizza": "StampPizza",
        "burger": "StampBurger",
        "darkburger": "StampDarkburger",
        "kebab": "StampKebab",
        "sushi": "StampSushi",
        "salade": "StampSalade",
        "croissant": "StampCroissant",
        "steak": "StampSteak",
        "riz": "StampRiz",
        "baguette": "StampBaguette",
        "giftgold": "StampGiftgold",
        "giftsilver": "StampGiftsilver",
        "checkvert": "StampCheckvert",
        "coiffeur": "StampCoiffeur",
        "ongle": "StampOngle",
        "sourcil": "StampSourcil",
        "spa": "StampSpa",
    ]

    static let defaultKey = "cafe"

    static func normalizeKey(_ rawValue: String?) -> String {
        guard let rawValue else { return defaultKey }
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return defaultKey }
        let lower = raw.lowercased()
        if keyToRasterBase[lower] != nil { return lower }
        if lower.hasPrefix("stamp"), lower.count > 5 {
            let stripped = String(lower.dropFirst(5))
            if keyToRasterBase[stripped] != nil { return stripped }
        }
        return defaultKey
    }

    /// Nom résolu pour `Image(_:)` : d’abord `icons/…` (dossier avec espace de noms Xcode), puis nom seul, puis ancien `Stamp*`.
    static func resolvedCatalogName(for rawValue: String?) -> String {
        let key = normalizeKey(rawValue)
        let base = keyToRasterBase[key] ?? keyToRasterBase[defaultKey]!
        let candidates: [String] = [
            "icons/\(base)",
            base,
            legacyStampAssetName[key],
        ].compactMap { $0 }
        for name in candidates {
            if UIImage(named: name) != nil { return name }
        }
        return "icons/\(base)"
    }
}

/// Décode `data:image/…;base64,…` (PNG, JPEG, WebP) — tampon importé.
enum StampIconDataURLImage {
    static func uiImage(fromDataURLString s: String?) -> UIImage? {
        let t = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard t.hasPrefix("data:image/"), let comma = t.firstIndex(of: ",") else { return nil }
        let b64 = String(t[t.index(after: comma)...])
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        guard let data = Data(base64Encoded: b64, options: [.ignoreUnknownCharacters]), !data.isEmpty else { return nil }
        if let u = UIImage(data: data) { return u }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return UIImage(cgImage: cg, scale: UITraitCollection.current.displayScale, orientation: .up)
    }
}

/// Tampon : image importée (data URL) ou URL API, sinon picto catalogue.
struct StampIconDisplayView: View {
    var dataURL: String? = nil
    var remoteURL: URL? = nil
    var catalogEmoji: String? = nil
    var size: CGFloat = 40
    var tint: Color = .white

    var body: some View {
        let d = dataURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !d.isEmpty, let img = StampIconDataURLImage.uiImage(fromDataURLString: d) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else if let r = remoteURL {
            AuthenticatedLogoView(url: r, stripBackgroundFill: false)
                .frame(width: size, height: size)
        } else {
            StampIconView(stampEmoji: catalogEmoji, size: size, tint: tint)
        }
    }
}

/// Vue qui affiche uniquement les icônes images du catalogue.
struct StampIconView: View {
    /// Clé d’icône (ex. "cafe", "pizza") stockée dans `stamp_emoji`.
    let stampEmoji: String?
    /// Taille du côté (carré).
    var size: CGFloat = 40
    /// Conservé pour compat API des appels existants.
    var tint: Color = .white

    var body: some View {
        let imageName = StampIconCatalog.resolvedCatalogName(for: stampEmoji)
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 12) {
        StampIconView(stampEmoji: "cafe", size: 44)
        StampIconView(stampEmoji: "burger", size: 44)
        StampIconView(stampEmoji: "giftsilver", size: 44)
        StampIconView(stampEmoji: nil, size: 44)
    }
    .padding()
}
