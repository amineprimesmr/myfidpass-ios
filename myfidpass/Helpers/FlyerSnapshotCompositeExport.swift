//
//  FlyerSnapshotCompositeExport.swift
// myfidpass
//
//  Export PNG flyer — rendu 100 % natif (underlay + canvas CoreGraphics).
//

import SwiftUI
import UIKit

enum FlyerSnapshotCompositeExport {
    /// Export 4K pour partage / cache Commerce.
    @MainActor
    static func exportImage(
        state: FlyerStateDTO,
        shareURL: String,
        logoImage: UIImage?,
        underlayBase: UIImage?
    ) -> UIImage? {
        FlyerNativeExport.renderShareImage(
            state: state,
            shareURL: shareURL,
            logoImage: logoImage,
            underlayImage: underlayBase
        )
    }

    /// Compatibilité : si un ancien appel passe encore un snapshot WebKit, on ignore la WebView.
    @MainActor
    static func exportImage(
        webSnapshot: UIImage,
        underlayBase: UIImage?,
        state: FlyerStateDTO
    ) -> UIImage {
        _ = webSnapshot
        if let native = exportImage(
            state: state,
            shareURL: "",
            logoImage: nil,
            underlayBase: underlayBase
        ) {
            return native
        }
        return webSnapshot
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
