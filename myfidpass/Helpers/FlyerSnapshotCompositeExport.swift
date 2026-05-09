//
//  FlyerSnapshotCompositeExport.swift
// myfidpass
//
//  L’aperçu flyer superpose une WebView **transparente** (canvas roue/QR/texte) sur
//  `FlyerNativeUnderlayStack` (photo IA / fond + dégradés SwiftUI). `WKWebView.takeSnapshot`
//  ne voit que la WebView → fond manquant / noir à l’export. On recompose donc le bitmap
//  comme à l’écran avant partage ou mise en cache.
//

import SwiftUI
import UIKit

enum FlyerSnapshotCompositeExport {
    /// Aplatit le flyer pour partage / Photos : fond blanc de secours + underlay natif + snapshot WebKit.
    @MainActor
    static func exportImage(
        webSnapshot: UIImage,
        underlayBase: UIImage?,
        state: FlyerStateDTO
    ) -> UIImage {
        let size = webSnapshot.size
        guard size.width > 1, size.height > 1 else { return webSnapshot }
        let scale = webSnapshot.scale

        let underlayRendered: UIImage? = {
            guard let base = underlayBase else { return nil }
            return renderNativeUnderlay(state: state, baseImage: base, size: size, scale: scale)
        }()

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            UIColor.white.setFill()
            UIRectFill(rect)

            if let u = underlayRendered {
                u.draw(in: rect)
            } else if let fallback = underlayBase {
                // Repli si ImageRenderer échoue : photo seule (mieux que transparence).
                fallback.draw(in: rect)
            }

            webSnapshot.draw(in: rect)
        }
    }

    @MainActor
    private static func renderNativeUnderlay(
        state: FlyerStateDTO,
        baseImage: UIImage,
        size: CGSize,
        scale: CGFloat
    ) -> UIImage? {
        let content = FlyerNativeUnderlayStack(state: state, image: baseImage)
            .frame(width: size.width, height: size.height)
        let ir = ImageRenderer(content: content)
        ir.scale = scale
        ir.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        return ir.uiImage
    }
}
