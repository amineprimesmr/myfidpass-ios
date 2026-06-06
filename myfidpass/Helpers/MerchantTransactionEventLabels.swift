//
//  MerchantTransactionEventLabels.swift
//  myfidpass
//
//  Encodage / libellés des transactions serveur dans `Stamp.note` (sync Core Data).
//  Aligné sur `fidelity/backend/src/lib/merchant-transaction-export.js`.
//

import Foundation

enum MerchantTransactionEventLabels {
    // MARK: - Encodage note (`txn:<id>|t:<type>|p:<n>|v:1|l:<récompense>`)

    static func encodeStampNote(txnId: String, type: String?, points: Int?, metadata: String?) -> String {
        var segments = ["txn:\(txnId.trimmingCharacters(in: .whitespacesAndNewlines))"]
        let normalizedType = type?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !normalizedType.isEmpty {
            segments.append("t:\(normalizedType)")
        }
        if let p = points {
            segments.append("p:\(p)")
        }
        if metadataIndicatesVisit(metadata) {
            segments.append("v:1")
        }
        if let label = parseRewardLabel(fromMetadata: metadata), !label.isEmpty {
            segments.append("l:\(encodeSegmentValue(label))")
        }
        return segments.joined(separator: "|")
    }

    static func compositeDedupKey(memberId: String, type: String?, createdAt: String?, points: Int?) -> String {
        let t = type?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let d = createdAt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return "orphan:\(memberId)|\(t)|\(d)|\(points ?? 0)"
    }

    // MARK: - Parsing note

    static func normalizedTxnDedupKey(fromStampNote note: String?) -> String? {
        let raw = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard raw.hasPrefix("txn:"), raw.count > 4 else { return nil }
        let payload = raw.dropFirst(4)
        if let pipe = payload.firstIndex(of: "|") {
            let tid = String(payload[..<pipe]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !tid.isEmpty else { return nil }
            return "txn:\(tid)"
        }
        return raw
    }

    static func parseType(fromStampNote note: String?) -> String? {
        segmentValue(in: note, prefix: "t:")
    }

    static func parsePoints(fromStampNote note: String?) -> Int? {
        guard let raw = segmentValue(in: note, prefix: "p:") else { return nil }
        return Int(raw)
    }

    static func parseVisit(fromStampNote note: String?) -> Bool {
        segmentValue(in: note, prefix: "v:") == "1"
    }

    static func parseRewardLabel(fromStampNote note: String?) -> String? {
        if let raw = segmentValue(in: note, prefix: "l:") {
            let label = decodeSegmentValue(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty { return label }
        }
        return parseRewardLabel(fromMetadata: note)
    }

    private static func segmentValue(in note: String?, prefix: String) -> String? {
        let raw = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard raw.hasPrefix("txn:") else { return nil }
        for part in raw.split(separator: "|") {
            let s = String(part)
            if s.hasPrefix(prefix) {
                let value = String(s.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    // MARK: - Libellés UI

    enum DisplayContext {
        case memberHistory
        case dashboardFeed
    }

    static func eventTitle(
        type: String?,
        points: Int?,
        isVisit: Bool,
        rewardLabel: String? = nil,
        context: DisplayContext = .memberHistory
    ) -> String {
        let normalized = type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

        switch normalized {
        case "reward_redeem":
            let label = rewardLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !label.isEmpty { return "Récompense · \(label)" }
            return "Récompense utilisée"
        case "welcome_bonus":
            return "Nouveau membre"
        case "points_correction":
            if let p = points, p < 0 {
                let a = abs(p)
                return a == 1 ? "Correction caisse · −1 pt" : "Correction caisse · −\(a) pts"
            }
            return "Correction caisse"
        case "points_redeem_game_tickets":
            return "Échange jeu / tickets"
        case "points_add", "":
            if isVisit {
                return context == .dashboardFeed ? "Passage enregistré" : "Passage enregistré"
            }
            if let p = points {
                if p > 0 {
                    return p == 1 ? "Ajout de points · +1 pt" : "Ajout de points · +\(p) pts"
                }
                if p < 0 {
                    let a = abs(p)
                    return a == 1 ? "Retrait de points · −1 pt" : "Retrait de points · −\(a) pts"
                }
            }
            return "Ajout de points"
        default:
            if let p = points, p != 0 {
                return p > 0 ? "+\(p) pts" : "−\(abs(p)) pts"
            }
            return "Transaction enregistrée"
        }
    }

    static func dashboardAmountLine(
        type: String?,
        points: Int?,
        isVisit: Bool,
        isPointsProgram: Bool,
        rewardLabel: String? = nil
    ) -> String {
        let normalized = type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if normalized == "reward_redeem" {
            let label = rewardLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !label.isEmpty { return "− \(label)" }
            if let p = points, p < 0 { return "−\(abs(p)) pts" }
            return "Récompense"
        }
        if normalized == "welcome_bonus" {
            return "Nouveau membre"
        }
        if normalized == "points_correction" {
            if let p = points, p < 0 { return "−\(abs(p)) pts" }
            return "Correction"
        }
        if isVisit || (!isPointsProgram && normalized == "points_add") {
            return isPointsProgram ? "+ Visite" : stampCreditAmountLine(points: points)
        }
        if let p = points, isPointsProgram {
            if p > 0 { return "+\(p) pts" }
            if p < 0 { return "−\(abs(p)) pts" }
        }
        return isPointsProgram ? "+ Visite" : stampCreditAmountLine(points: points)
    }

    /// Libellé droit du fil d’activité en mode tampons (remplace « Visite »).
    private static func stampCreditAmountLine(points: Int?) -> String {
        if let p = points, p > 0 {
            return p == 1 ? "+ 1 tampon" : "+ \(p) tampons"
        }
        return "+ tampons"
    }

    // MARK: - Metadata API

    static func parseRewardLabel(fromMetadata metadata: String?) -> String? {
        let raw = metadata?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let label = (obj["reward_label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return label.isEmpty ? nil : label
    }

    private static func encodeSegmentValue(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private static func decodeSegmentValue(_ value: String) -> String {
        value.removingPercentEncoding ?? value
    }

    private static func metadataIndicatesVisit(_ metadata: String?) -> Bool {
        let raw = metadata?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return false }
        if raw.contains("\"visit\":true") || raw.contains("\"visit\": true") { return true }
        if let data = raw.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if obj["visit"] as? Bool == true { return true }
            if let s = obj["visit"] as? String, s.lowercased() == "true" { return true }
        }
        return false
    }

    /// Complète ou remplace une note existante par la forme canonique serveur.
    static func enrichStampNote(_ existing: String?, txnId: String, type: String?, points: Int?, metadata: String?) -> String {
        _ = existing
        return encodeStampNote(txnId: txnId, type: type, points: points, metadata: metadata)
    }
}
