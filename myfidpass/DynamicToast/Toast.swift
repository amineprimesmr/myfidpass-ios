//
//  Toast.swift
//  myfidpass
//
//  Modèle du toast style Dynamic Island (réutilisé depuis DynamicIslandToast).
//

import SwiftUI

struct Toast {
    private(set) var id: String = UUID().uuidString
    var symbol: String
    var symbolFont: Font
    var symbolForegroundStyle: (Color, Color)

    var title: String
    var message: String

    static var example1: Toast {
        Toast(
            symbol: "checkmark.seal.fill",
            symbolFont: .system(size: 35),
            symbolForegroundStyle: (.white, .green),
            title: "Transaction Success!",
            message: "Your transaction with iJustine is complete"
        )
    }

    static var example2: Toast {
        Toast(
            symbol: "xmark.seal.fill",
            symbolFont: .system(size: 35),
            symbolForegroundStyle: (.white, .red),
            title: "Transaction Failed!",
            message: "Your transaction with iJustine is failed"
        )
    }

    /// Toast affiché quand le scan QR a réussi et que l'utilisateur a été détecté.
    static func scanSuccess(memberName: String, pointsAdded: Int?) -> Toast {
        let pointsText: String
        if let pts = pointsAdded, pts > 0 {
            pointsText = " +\(pts) point\(pts > 1 ? "s" : "")"
        } else {
            pointsText = ""
        }
        return Toast(
            symbol: "checkmark.circle.fill",
            symbolFont: .system(size: 35),
            symbolForegroundStyle: (.white, .green),
            title: "Client détecté",
            message: "\(memberName)\(pointsText)"
        )
    }
}
