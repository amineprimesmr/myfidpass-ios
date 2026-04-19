//
//  LogoCarouselPhotoThumbnails.swift
//  myfidpass
//
//  Cache PHPhotoLibrary + options « instantanées » pour les miniatures du carrousel.
//

import Photos
import SwiftUI
import UIKit

enum LogoCarouselPhotoThumbnails {
    static let sharedManager = PHCachingImageManager()

    /// Cible la taille d’affichage en pixels (`resizeMode` exact) ; `opportunistic` évite le flou de `fastFormat`.
    static func requestOptionsCarouselThumbnail() -> PHImageRequestOptions {
        let o = PHImageRequestOptions()
        o.deliveryMode = .opportunistic
        o.resizeMode = .exact
        o.isNetworkAccessAllowed = true
        o.isSynchronous = false
        return o
    }

    static func thumbnailPointSize(side: CGFloat) -> CGSize {
        let scale = displayScale()
        return CGSize(width: side * scale, height: side * scale)
    }

    static func displayScale() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let s = scenes.first(where: { $0.activationState == .foregroundActive })?.screen.scale {
            return s
        }
        return scenes.first?.screen.scale ?? 3
    }

    /// Précharge les premières vignettes pour qu’elles s’affichent sans délai au scroll.
    static func startCachingFirstPage(assets: [PHAsset], side: CGFloat, limit: Int = 32) {
        guard !assets.isEmpty else { return }
        let slice = Array(assets.prefix(limit))
        let target = thumbnailPointSize(side: side)
        let opts = requestOptionsCarouselThumbnail()
        sharedManager.startCachingImages(
            for: slice,
            targetSize: target,
            contentMode: .aspectFill,
            options: opts
        )
    }

    static func stopCachingAll() {
        sharedManager.stopCachingImagesForAllAssets()
    }
}
