//
//  UIImage+CropResize.swift
//  myfidpass
//

import UIKit

extension UIImage {
    /// Découpe dans l’espace **points** de l’image (`UIImage.size`).
    func myfid_crop(to rectInPoints: CGRect) -> UIImage? {
        guard let cg = cgImage else { return nil }
        let s = scale
        let px = CGRect(
            x: rectInPoints.origin.x * s,
            y: rectInPoints.origin.y * s,
            width: rectInPoints.size.width * s,
            height: rectInPoints.size.height * s
        ).integral
        guard let cropped = cg.cropping(to: px) else { return nil }
        return UIImage(cgImage: cropped, scale: s, orientation: imageOrientation)
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
