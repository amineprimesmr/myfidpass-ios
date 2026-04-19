//
//  TransactionExportPDFBuilder.swift
//  myfidpass
//
//  Génère un PDF lisible (traçabilité) à partir du JSON d’export serveur.
//

import UIKit

enum TransactionExportPDFBuilder {
    private static let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let margin: CGFloat = 40
    private static let bottomSafe: CGFloat = 48
    private static let isoParser = ISO8601DateFormatter()

    private static let displayFr: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    static func pdfData(from report: TransactionExportJSONResponse) -> Data? {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let titleFont = UIFont.boldSystemFont(ofSize: 17)
        let headFont = UIFont.boldSystemFont(ofSize: 10)
        let bodyFont = UIFont.systemFont(ofSize: 9)
        let smallFont = UIFont.systemFont(ofSize: 8)

        return renderer.pdfData { ctx in
            var y = margin

            func newPage() {
                ctx.beginPage()
                y = margin
            }

            newPage()

            @discardableResult
            func draw(_ text: String, font: UIFont, x: CGFloat, width: CGFloat) -> CGFloat {
                let attrs: [NSAttributedString.Key: Any] = [.font: font]
                let s = NSAttributedString(string: text, attributes: attrs)
                let h = s.boundingRect(
                    with: CGSize(width: width, height: 10_000),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                ).height
                let hClamped = max(ceil(h), font.lineHeight)
                s.draw(in: CGRect(x: x, y: y, width: width, height: hClamped))
                y += hClamped + 4
                return hClamped
            }

            func ensureSpace(_ h: CGFloat) {
                if y + h > pageRect.height - bottomSafe {
                    newPage()
                }
            }

            ensureSpace(60)
            draw("Rapport d’activité fidélité", font: titleFont, x: margin, width: pageRect.width - 2 * margin)
            if let name = report.businessName, !name.isEmpty {
                draw(name, font: headFont, x: margin, width: pageRect.width - 2 * margin)
            }
            if let period = report.periodLabel, !period.isEmpty {
                draw("Période : \(period)", font: bodyFont, x: margin, width: pageRect.width - 2 * margin)
            }
            if let gen = report.generatedAt, let d = isoParser.date(from: gen) {
                draw("Généré le \(displayFr.string(from: d))", font: smallFont, x: margin, width: pageRect.width - 2 * margin)
            } else if let gen = report.generatedAt {
                draw("Généré : \(gen)", font: smallFont, x: margin, width: pageRect.width - 2 * margin)
            }

            if report.truncated == true {
                draw(
                    "Attention : l’export est tronqué à la limite demandée. Le nombre total d’opérations correspondant aux filtres peut être supérieur.",
                    font: smallFont,
                    x: margin,
                    width: pageRect.width - 2 * margin
                )
            }

            if let s = report.summary {
                ensureSpace(80)
                draw("Synthèse", font: headFont, x: margin, width: pageRect.width - 2 * margin)
                if let n = s.rowCount {
                    draw("Lignes exportées : \(n)", font: bodyFont, x: margin, width: pageRect.width - 2 * margin)
                }
                if let c = s.pointsCreditedTotal {
                    draw("Total points crédités : \(c)", font: bodyFont, x: margin, width: pageRect.width - 2 * margin)
                }
                if let d = s.pointsDebitedTotal {
                    draw("Total points débités : \(d)", font: bodyFont, x: margin, width: pageRect.width - 2 * margin)
                }
                if let by = s.byType, !by.isEmpty {
                    let sorted = by.keys.sorted()
                    let lines = sorted.map { "\($0): \(by[$0] ?? 0)" }.joined(separator: " · ")
                    draw("Répartition types : \(lines)", font: smallFont, x: margin, width: pageRect.width - 2 * margin)
                }
            }

            ensureSpace(40)
            draw("Détail des opérations", font: headFont, x: margin, width: pageRect.width - 2 * margin)

            let colDate: CGFloat = 78
            let colClient: CGFloat = 120
            let colType: CGFloat = 92
            let colPts: CGFloat = 36
            let colDetail = pageRect.width - 2 * margin - colDate - colClient - colType - colPts - 12
            let x0 = margin

            ensureSpace(24)
            y += 4
            ("Date" as NSString).draw(
                at: CGPoint(x: x0, y: y),
                withAttributes: [.font: headFont]
            )
            ("Client" as NSString).draw(
                at: CGPoint(x: x0 + colDate, y: y),
                withAttributes: [.font: headFont]
            )
            ("Type" as NSString).draw(
                at: CGPoint(x: x0 + colDate + colClient, y: y),
                withAttributes: [.font: headFont]
            )
            ("Pts" as NSString).draw(
                at: CGPoint(x: x0 + colDate + colClient + colType, y: y),
                withAttributes: [.font: headFont]
            )
            ("Détail" as NSString).draw(
                at: CGPoint(x: x0 + colDate + colClient + colType + colPts, y: y),
                withAttributes: [.font: headFont]
            )
            y += headFont.lineHeight + 8

            for row in report.transactions {
                let dateStr = formattedDate(row.createdAt)
                let client = trunc(row.memberName ?? "—", 22)
                let typeL = trunc(row.typeLabel ?? row.type ?? "—", 18)
                let pts = row.points.map { String($0) } ?? "—"
                let det = row.detail ?? "—"

                let detailAttr = NSAttributedString(string: det, attributes: [.font: smallFont])
                let detailH = ceil(
                    detailAttr.boundingRect(
                        with: CGSize(width: colDetail, height: 10_000),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    ).height
                )
                let rowH = max(detailH, smallFont.lineHeight) + 6

                ensureSpace(rowH + 4)
                (dateStr as NSString).draw(at: CGPoint(x: x0, y: y), withAttributes: [.font: smallFont])
                (client as NSString).draw(at: CGPoint(x: x0 + colDate, y: y), withAttributes: [.font: smallFont])
                (typeL as NSString).draw(at: CGPoint(x: x0 + colDate + colClient, y: y), withAttributes: [.font: smallFont])
                (pts as NSString).draw(at: CGPoint(x: x0 + colDate + colClient + colType, y: y), withAttributes: [.font: smallFont])
                detailAttr.draw(in: CGRect(x: x0 + colDate + colClient + colType + colPts, y: y, width: colDetail, height: rowH + 20))
                y += rowH
            }

            ensureSpace(36)
            draw(
                "Document généré par MyFidpass — données indicatives ; la source de vérité reste votre espace commerçant.",
                font: smallFont,
                x: margin,
                width: pageRect.width - 2 * margin
            )
        }
    }

    private static func formattedDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        if let d = isoParser.date(from: raw) {
            return displayFr.string(from: d)
        }
        return trunc(raw, 14)
    }

    private static func trunc(_ s: String, _ maxLen: Int) -> String {
        if s.count <= maxLen { return s }
        let i = s.index(s.startIndex, offsetBy: max(1, maxLen - 1))
        return String(s[..<i]) + "…"
    }
}
