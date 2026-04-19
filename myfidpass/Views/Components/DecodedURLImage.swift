//
//  DecodedURLImage.swift
//  myfidpass
//
//  Remplace `AsyncImage` pour les URLs publiques : même décodage robuste que les fichiers locaux (`ImageIODownsampling`).
//

import SwiftUI
import UIKit

/// Image chargée via `URLSession` puis décodée avec ImageIO (évite les bitmaps à mauvais ratio avec `.aspectRatio(.fit)`).
struct DecodedURLImage: View {
    let url: URL
    var contentMode: ContentMode = .fit
    var maxPixelDimension: CGFloat = 1200

    @State private var image: UIImage?

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
        .task(id: url.absoluteString) {
            image = nil
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  !data.isEmpty else { return }
            let cap = maxPixelDimension
            let loaded = await Task.detached(priority: .userInitiated) {
                ImageIODownsampling.imageFromData(data, maxPixelDimension: cap)
            }.value
            await MainActor.run { image = loaded }
        }
    }
}
