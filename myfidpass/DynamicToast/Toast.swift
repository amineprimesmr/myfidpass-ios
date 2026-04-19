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
    static func scanSuccess(memberName: String, pointsAdded: Int?, pointsCapped: Bool = false, pointsRequested: Int? = nil) -> Toast {
        let pointsText: String
        if let pts = pointsAdded, pts > 0 {
            pointsText = " +\(pts) point\(pts > 1 ? "s" : "")"
        } else {
            pointsText = ""
        }
        var capSuffix = ""
        if pointsCapped, let req = pointsRequested, let got = pointsAdded, req > got {
            capSuffix = "\nPlafond sécurité : \(got) pt crédité(s) (calcul : \(req))."
        }
        return Toast(
            symbol: "checkmark.circle.fill",
            symbolFont: .system(size: 35),
            symbolForegroundStyle: (.white, .green),
            title: "Client détecté",
            message: "\(memberName)\(pointsText)\(capSuffix)"
        )
    }

    /// Toast affiché quand 1 tampon a été ajouté (programme tampons uniquement).
    static func scanStampSuccess(
        memberName: String,
        pointsCapped: Bool = false,
        pointsRequested: Int? = nil,
        pointsAdded: Int? = nil,
        stampCycleCompleted: Bool = false
    ) -> Toast {
        var capSuffix = ""
        if pointsCapped, let req = pointsRequested, let got = pointsAdded, req > got {
            capSuffix = "\nPlafond sécurité : \(got) pt crédité(s) (calcul : \(req))."
        }
        let title = stampCycleCompleted ? "Carte complète — récompense !" : "1 tampon ajouté"
        let rewardLine = stampCycleCompleted
            ? "\nLe compteur repart à zéro pour une nouvelle carte."
            : ""
        return Toast(
            symbol: stampCycleCompleted ? "gift.fill" : "checkmark.circle.fill",
            symbolFont: .system(size: 35),
            symbolForegroundStyle: stampCycleCompleted
                ? (.white, Color(red: 1, green: 0.55, blue: 0.2))
                : (.white, .green),
            title: title,
            message: "\(memberName)\(rewardLine)\(capSuffix)"
        )
    }
}
