//
//  MFConcentricShapeFallback.swift
//  myfidpass
//
//  `ConcentricRectangle` n’existe qu’à partir d’iOS 26 : ce type isole l’appel pour une cible de déploiement inférieure.
//

import SwiftUI

@available(iOS 26.0, *)
private enum MFConcentricNativeShapePath {
    static func path(in rect: CGRect, minimumCorner: CGFloat, isUniform: Bool) -> Path {
        ConcentricRectangle(
            corners: .concentric(minimum: .fixed(minimumCorner)),
            isUniform: isUniform
        ).path(in: rect)
    }
}

/// Forme type îlot Dynamic Island / coins concentriques : natif iOS 26, sinon rectangle très arrondi.
struct MFConcentricShapeFallback: Shape {
    var minimumCorner: CGFloat
    var isUniform: Bool = true

    func path(in rect: CGRect) -> Path {
        if #available(iOS 26.0, *) {
            return MFConcentricNativeShapePath.path(in: rect, minimumCorner: minimumCorner, isUniform: isUniform)
        } else {
            let r = min(minimumCorner, min(rect.width, rect.height) / 2)
            return RoundedRectangle(cornerRadius: r, style: .continuous).path(in: rect)
        }
    }
}
