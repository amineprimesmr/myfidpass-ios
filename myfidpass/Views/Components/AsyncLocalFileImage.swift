//
//  AsyncLocalFileImage.swift
//  myfidpass
//
//  Lecture disque hors thread principal pour aperçus carte / logos (évite les saccades au scroll).
//  Décodage ImageIO avec plafond de pixels (évite les PNG 8K px pour une vignette).
//

import SwiftUI
import UIKit

/// Image depuis un chemin fichier absolu, chargée en arrière-plan.
/// - Important : le même chemin (ex. `CardLogos/cardLogo.png`) est réutilisé quand l’utilisateur change d’image — sans rechargement explicite,
///   SwiftUI ne relance pas la tâche et l’ancienne bitmap restait affichée. `reloadToken` et la notification `myfidpassCardLocalAssetFileWritten`
///   (émise par `CardLogoStorage` après écriture) forcent un nouveau chargement depuis le disque.
struct AsyncLocalFileImage: View {
    let filePath: String
    var contentMode: ContentMode = .fill
    /// Incrémenter côté parent si besoin (ex. écriture hors `CardLogoStorage`).
    var reloadToken: Int = 0
    /// Côté long max après décodage (logos / aperçus carte — pas besoin du fichier pleine résolution).
    var maxPixelDimension: CGFloat = 1200

    @State private var image: UIImage?
    /// Incrémenté à chaque notification globale de fichier carte réécrit (même chemin).
    @State private var diskEpoch: Int = 0

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color.gray.opacity(0.12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassCardLocalAssetFileWritten)) { _ in
            diskEpoch &+= 1
        }
        .task(id: "\(filePath)|\(reloadToken)|\(diskEpoch)|\(maxPixelDimension)") {
            let p = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !p.isEmpty else {
                await MainActor.run { image = nil }
                return
            }
            let cap = maxPixelDimension
            let loaded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                ImageIODownsampling.imageFromFile(at: p, maxPixelDimension: cap)
            }.value
            await MainActor.run { image = loaded }
        }
    }
}
