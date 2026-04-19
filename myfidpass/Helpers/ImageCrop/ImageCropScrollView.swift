//
//  ImageCropScrollView.swift
//  myfidpass
//
//  Cadrage type « Photos » : une seule image zoomable sur toute la zone, voile assombrit l’extérieur du cadre.
//  L’export correspond au rectangle de cadrage (converti vers l’image).
//

import SwiftUI
import UIKit

/// Conteneur qui relance le layout quand la taille SwiftUI change.
final class ImageCropLayoutView: UIView {
    var onLayout: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

final class ImageCropScrollCoordinator: NSObject, UIScrollViewDelegate {
    var image: UIImage
    var aspectRatio: CGFloat
    weak var scrollView: UIScrollView?
    /// Contient l’image ; seul ce sous-arbre est zoomé (évite le décalage contentSize / spacers).
    weak var zoomContainerView: UIView?
    weak var imageView: UIImageView?
    weak var layoutHost: ImageCropLayoutView?
    weak var dimOverlayView: UIView?
    var dimFillLayer: CAShapeLayer?
    /// Contour blanc du trou (au-dessus du voile, sous le scroll).
    var holeBorderLayer: CAShapeLayer?

    private var lastScrollFrame: CGRect = .zero
    private var lastImageIdentity: ObjectIdentifier?
    private var needsContentReset = true

    init(image: UIImage, aspectRatio: CGFloat) {
        self.image = image
        self.aspectRatio = aspectRatio
        super.init()
    }

    func viewForZooming(in _: UIScrollView) -> UIView? {
        zoomContainerView
    }

    func scrollViewDidZoom(_: UIScrollView) {
        // Ne pas toucher aux contentInset pendant le pincement (sinon l’offset saute et l’image part en bas).
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with _: UIView?, atScale _: CGFloat) {
        // Pas de contentInset de « centrage » : ils annulent le déplacement et ramènent l’image au milieu.
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        clampScrollOffset(scrollView)
    }

    private func clampScrollOffset(_ scrollView: UIScrollView) {
        let bounds = scrollView.bounds
        let inset = scrollView.adjustedContentInset
        let minX = -inset.left
        let minY = -inset.top
        let rawMaxX = scrollView.contentSize.width - bounds.width + inset.right
        let rawMaxY = scrollView.contentSize.height - bounds.height + inset.bottom
        let maxX = max(minX, rawMaxX)
        let maxY = max(minY, rawMaxY)
        var x = scrollView.contentOffset.x
        var y = scrollView.contentOffset.y
        x = min(max(minX, x), maxX)
        y = min(max(minY, y), maxY)
        scrollView.contentOffset = CGPoint(x: x, y: y)
    }

    /// Fenêtre de cadrage centrée : bandeau large = quasi pleine largeur ; carré = cadre plus petit pour laisser des marges (image visible autour).
    private func computeScrollFrame(in bounds: CGRect) -> CGRect {
        let w = bounds.width
        let h = bounds.height
        guard w > 8, h > 8, aspectRatio > 0.01 else { return .zero }

        // Bandeau Wallet (large) : utilise la largeur utile, hauteur dérivée du ratio.
        if aspectRatio > 1.15 {
            let cropW = w * 0.94
            let cropH = cropW / aspectRatio
            let x = (w - cropW) * 0.5
            let y = max(0, (h - cropH) * 0.5)
            return CGRect(x: x, y: y, width: cropW, height: cropH)
        }

        // Carré / icône : ne pas occuper toute la largeur — marges pour voir l’image hors cadre (assombrie).
        let maxSide = min(w, h) * 0.82
        let cropW = maxSide
        let cropH = cropW / aspectRatio
        let x = (w - cropW) * 0.5
        let y = (h - cropH) * 0.5
        return CGRect(x: x, y: y, width: cropW, height: cropH)
    }

    private func updateDimAndBorderMasks(hostBounds: CGRect, scrollFrame: CGRect) {
        guard let fill = dimFillLayer, let border = holeBorderLayer else { return }
        let path = UIBezierPath(rect: hostBounds)
        path.append(UIBezierPath(roundedRect: scrollFrame, cornerRadius: 10))
        path.usesEvenOddFillRule = true
        fill.path = path.cgPath
        fill.fillColor = UIColor.black.withAlphaComponent(0.34).cgColor
        fill.fillRule = .evenOdd

        let edge = UIBezierPath(roundedRect: scrollFrame, cornerRadius: 10)
        border.path = edge.cgPath
        border.strokeColor = UIColor.white.withAlphaComponent(0.92).cgColor
        border.fillColor = nil
        border.lineWidth = 2
    }

    func layoutScrollViewContents() {
        guard let scrollView = scrollView, let imageView = imageView, let host = layoutHost else { return }
        let containerBounds = host.bounds

        dimOverlayView?.frame = containerBounds

        guard containerBounds.width > 8, containerBounds.height > 8 else { return }

        let scrollFrame = computeScrollFrame(in: containerBounds)
        guard scrollFrame.width > 8, scrollFrame.height > 8 else { return }

        updateDimAndBorderMasks(hostBounds: containerBounds, scrollFrame: scrollFrame)

        let sizeChanged =
            abs(scrollFrame.width - lastScrollFrame.width) > 0.5
            || abs(scrollFrame.height - lastScrollFrame.height) > 0.5
            || abs(scrollFrame.origin.x - lastScrollFrame.origin.x) > 0.5
            || abs(scrollFrame.origin.y - lastScrollFrame.origin.y) > 0.5
        if sizeChanged {
            lastScrollFrame = scrollFrame
            needsContentReset = true
        }

        /// Plein écran : l’image reste visible sous le voile (hors trou). Le cadrage d’export suit `scrollFrame`.
        scrollView.frame = containerBounds

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        guard needsContentReset else { return }
        guard let container = zoomContainerView else { return }

        needsContentReset = false

        let cx = scrollFrame.origin.x
        let cy = scrollFrame.origin.y
        let cw = scrollFrame.width
        let ch = scrollFrame.height
        let fillScale = max(cw / imageSize.width, ch / imageSize.height)
        let iw = imageSize.width * fillScale
        let ih = imageSize.height * fillScale

        scrollView.zoomScale = 1
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero

        let bw = scrollView.bounds.width
        let bh = scrollView.bounds.height
        let padX = max(0, (bw - iw) * 0.5)
        let padY = max(0, (bh - ih) * 0.5)
        // Évite tout contentOffset négatif (UIKit le force à 0) : sans ça, le reclamp casse l’alignement trou / image et le zoom colle en bas.
        let spacerLeft = max(0, cx - padX)
        let spacerTop = max(0, cy - padY)
        let ix = spacerLeft + padX
        let iy = spacerTop + padY

        let innerW = spacerLeft + iw + 2 * padX
        let innerH = spacerTop + ih + 2 * padY
        // Marge vide autour du bloc image (sans centrage forcé).
        let panSlop = max(72, max(bw, bh) * 0.4)
        let baseW = innerW + 2 * panSlop
        let baseH = innerH + 2 * panSlop
        // Au zoom minimum, le contenu zoomé doit rester plus grand que la zone + marge, sinon la plage de scroll s’effondre (offset « aimanté »).
        let minZoom = scrollView.minimumZoomScale
        let panAllowance = max(96, max(bw, bh) * 0.35)
        let minUnscaledW = (bw + panAllowance) / minZoom
        let minUnscaledH = (bh + panAllowance) / minZoom
        let CW = max(baseW, minUnscaledW)
        let CH = max(baseH, minUnscaledH)
        let expandX = (CW - baseW) * 0.5
        let expandY = (CH - baseH) * 0.5

        container.frame = CGRect(origin: .zero, size: CGSize(width: CW, height: CH))
        imageView.frame = CGRect(x: ix + panSlop + expandX, y: iy + panSlop + expandY, width: iw, height: ih)
        scrollView.contentSize = container.bounds.size

        scrollView.contentOffset = CGPoint(x: ix - cx + panSlop + expandX, y: iy - cy + panSlop + expandY)
        clampScrollOffset(scrollView)
    }

    /// Fenêtre de cadrage (espace host) → rectangle dans l’`imageView`, puis vers l’`UIImage` (aspect fill).
    func makeCroppedUIImage() -> UIImage? {
        guard scrollView != nil, let imageView = imageView, let host = layoutHost else { return nil }
        let cropFrame = computeScrollFrame(in: host.bounds)
        let cropInImageView = host.convert(cropFrame, to: imageView)
        let clipped = cropInImageView.intersection(imageView.bounds)
        guard clipped.width > 0.5, clipped.height > 0.5 else { return nil }
        let imageRect = UIImage.myfid_mapAspectFillRect(
            rectInImageView: clipped,
            imageSize: image.size,
            imageViewSize: imageView.bounds.size
        )
        guard imageRect.width > 0.5, imageRect.height > 0.5 else { return nil }
        return image.myfid_crop(to: imageRect)
    }

    func syncImageIfNeeded(_ newImage: UIImage) {
        let oid = ObjectIdentifier(newImage)
        if lastImageIdentity != oid {
            lastImageIdentity = oid
            image = newImage
            imageView?.image = newImage
            scrollView?.zoomScale = 1
            lastScrollFrame = .zero
            needsContentReset = true
        }
    }
}

struct ImageCropScrollView: UIViewRepresentable {
    let image: UIImage
    let aspectRatio: CGFloat
    var exportHandle: ImageCropExportHandle?

    func makeCoordinator() -> ImageCropScrollCoordinator {
        ImageCropScrollCoordinator(image: image, aspectRatio: aspectRatio)
    }

    func makeUIView(context: Context) -> ImageCropLayoutView {
        let host = ImageCropLayoutView()
        host.backgroundColor = UIColor.systemGroupedBackground

        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 0.2
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.isUserInteractionEnabled = false
        imageView.clipsToBounds = true

        let zoomContainer = UIView()
        zoomContainer.backgroundColor = .clear
        zoomContainer.clipsToBounds = false
        zoomContainer.addSubview(imageView)
        scrollView.addSubview(zoomContainer)
        host.addSubview(scrollView)

        let dimView = UIView()
        dimView.isUserInteractionEnabled = false
        dimView.backgroundColor = .clear
        host.addSubview(dimView)
        context.coordinator.dimOverlayView = dimView

        let fill = CAShapeLayer()
        dimView.layer.addSublayer(fill)
        context.coordinator.dimFillLayer = fill

        let border = CAShapeLayer()
        dimView.layer.addSublayer(border)
        context.coordinator.holeBorderLayer = border

        context.coordinator.scrollView = scrollView
        context.coordinator.zoomContainerView = zoomContainer
        context.coordinator.imageView = imageView
        context.coordinator.layoutHost = host
        context.coordinator.aspectRatio = aspectRatio

        host.onLayout = { [weak coord = context.coordinator] in
            coord?.layoutScrollViewContents()
        }
        exportHandle?.coordinator = context.coordinator
        return host
    }

    func updateUIView(_ host: ImageCropLayoutView, context: Context) {
        context.coordinator.syncImageIfNeeded(image)
        context.coordinator.aspectRatio = aspectRatio
        exportHandle?.coordinator = context.coordinator
        context.coordinator.layoutScrollViewContents()
    }
}
