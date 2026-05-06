//
//  FlyerLogoRemoveBackgroundAPI.swift
//  myfidpass
//
//  Détourage via le backend (rembg CLI ; secours remove.bg) — repli sur heuristiques locales si indisponible.
//

import ImageIO
import UIKit

enum FlyerLogoRemoveBackgroundAPI {
    /// Image PNG avec transparence, ou `nil` si erreur / `ok: false` / hors ligne.
    static func stripped(image: UIImage, slug: String) async -> UIImage? {
        guard let dataUrl = jpegDataURLForRequest(image) else { return nil }
        do {
            let res: FlyerRemoveLogoBgResponse = try await APIClient.shared.request(
                APIEndpoint.dashboardFlyerRemoveLogoBackground(slug: slug, imageDataUrl: dataUrl)
            )
            guard res.ok else { return nil }
            let url = res.pngDataUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !url.isEmpty else { return nil }
            return uiImage(fromDataURL: url)
        } catch {
            return nil
        }
    }

    /// JPEG redimensionné (côté serveur : sharp + rembg) — évite les PNG énormes.
    private static func jpegDataURLForRequest(_ image: UIImage) -> String? {
        let maxSide: CGFloat = 1600
        let m = max(image.size.width, image.size.height)
        let scale = m > maxSide ? maxSide / m : 1
        let sz = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        fmt.opaque = true
        let r = UIGraphicsImageRenderer(size: sz, format: fmt)
        let out = r.image { ctx in
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: sz))
            image.draw(in: CGRect(origin: .zero, size: sz))
        }
        guard let d = out.jpegData(compressionQuality: 0.88) else { return nil }
        return "data:image/jpeg;base64,\(d.base64EncodedString())"
    }

    private static func uiImage(fromDataURL s: String) -> UIImage? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.hasPrefix("data:image/"), let comma = t.firstIndex(of: ",") else { return nil }
        let b64 = String(t[t.index(after: comma)...])
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        guard let data = Data(base64Encoded: b64), !data.isEmpty else { return nil }
        if let u = UIImage(data: data) { return u }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return UIImage(cgImage: cg, scale: 1.0, orientation: .up)
    }
}
