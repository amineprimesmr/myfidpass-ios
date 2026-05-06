//
//  UIImage+CropResize.swift
//  myfidpass
//

import UIKit

extension UIImage {
    /// Découpe dans l’espace **points** de l’image (`UIImage.size`).
    /// Utilise `UIGraphicsImageRenderer` + `draw(in:)` pour respecter `imageOrientation` — contrairement à
    /// `cgImage.cropping`, qui travaille dans l’espace pixel brut et produit une bande verticale pour les
    /// photos `.right` / `.left` (EXIF rotation iPhone paysage).
    func myfid_crop(to rectInPoints: CGRect) -> UIImage? {
        guard size.width > 0, size.height > 0,
              rectInPoints.width > 0.5, rectInPoints.height > 0.5 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: rectInPoints.size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(
                x: -rectInPoints.origin.x,
                y: -rectInPoints.origin.y,
                width: size.width,
                height: size.height
            ))
        }
    }

    /// Redimensionne vers une **taille de canevas** fixe **sans déformer** l’image (échelle uniforme + centrage).
    /// Important : ne pas utiliser `draw(in: entireTargetRect)` seul — cela étire comme `scaleToFill` et écrase le logo
    /// (ex. bandeau 16:5) alors que le recadrage a déjà placé le visuel dans le trou.
    func myfid_resized(to targetSize: CGSize) -> UIImage? {
        guard targetSize.width > 0, targetSize.height > 0 else { return nil }
        let iw = size.width
        let ih = size.height
        guard iw > 0, ih > 0 else { return nil }
        let scale = min(targetSize.width / iw, targetSize.height / ih)
        let newW = iw * scale
        let newH = ih * scale
        let x = (targetSize.width - newW) * 0.5
        let y = (targetSize.height - newH) * 0.5
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(x: x, y: y, width: newW, height: newH))
        }
    }

    /// Cartographie un rectangle dans les coordonnées de l’`UIImageView` (aspect fill) vers l’espace image.
    static func myfid_mapAspectFillRect(
        rectInImageView: CGRect,
        imageSize: CGSize,
        imageViewSize: CGSize
    ) -> CGRect {
        let iw = imageSize.width
        let ih = imageSize.height
        guard iw > 0, ih > 0 else { return .zero }
        let scale = max(imageViewSize.width / iw, imageViewSize.height / ih)
        let scaledW = iw * scale
        let scaledH = ih * scale
        let ox = (imageViewSize.width - scaledW) / 2
        let oy = (imageViewSize.height - scaledH) / 2
        let imageDrawn = CGRect(x: ox, y: oy, width: scaledW, height: scaledH)
        let inter = rectInImageView.intersection(imageDrawn)
        guard !inter.isNull, inter.width > 0.5, inter.height > 0.5 else { return .zero }
        return CGRect(
            x: (inter.origin.x - ox) / scale,
            y: (inter.origin.y - oy) / scale,
            width: inter.width / scale,
            height: inter.height / scale
        )
    }
}
