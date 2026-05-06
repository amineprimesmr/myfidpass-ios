//
//  CardPreviewDisplaySnapshot.swift
//  myfidpass
//
//  Dernier état d’aperçu « Ma Carte » par commerce (UserDefaults) pour éviter d’afficher
//  un design obsolète (Core Data partiel) le temps du GET settings.
//

import Foundation

struct CardPreviewDisplaySnapshot: Codable, Equatable {
    var programType: String
    var displayName: String
    var primaryHex: String
    var accentHex: String
    var labelHex: String
    var stripHex: String
    var stripDisplayMode: String
    var stripText: String
    var logoURL: String
    var stampEmoji: String
    var requiredStamps: Int
    var headerRightText: String
    var labelMember: String
    var hasRemoteCardBackground: Bool
    var cardBackgroundRemoteURL: String?
    /// `true` seulement si l’utilisateur a un fichier local d’aperçu pour ce commerce (évite d’afficher un `cardBackground.png` orphelin d’un autre compte / session).
    var hasLocalCardBackground: Bool?
    var stampRewardLabel: String
    /// Récompense intermédiaire (ex. 5ᵉ passage) — pour l’aperçu « Prochaine récompense ».
    var stampMidRewardLabel: String?
    /// Récompense « Début du jeu » (palier 0 non modifiable, affiché au-dessus des paliers points et tampons).
    var startGameRewardLabel: String?
    /// Libellé « Restants » (carte tampons) — optionnel pour rétrocompatibilité des snapshots.
    var labelRestants: String?
    /// Paliers points (alignés sur `MyCardView.tierPoints` / `tierLabels`) — sync / SaaS (plus affichés sur l’aperçu carte face avant).
    var tierPoints: [String]?
    var tierLabels: [String]?
    /// Tampon / icône importé en attente d’envoi API (persiste hors session Ma carte).
    var stampIconPendingBase64: String?
    /// `true` si l’utilisateur a choisi « retirer » l’icône avant enregistrement serveur.
    var stampIconWasRemoved: Bool?
    /// Tampons : icône personnalisée déjà enregistrée côté API (`has_stamp_icon`) — pour l’accueil / exigences sans rouvrir « Ma carte ».
    var hasServerStampIcon: Bool?
}

enum CardPreviewDisplaySnapshotStore {
    private static func key(for slug: String) -> String {
        "myfidpass.cardDisplaySnapshot.v1.\(slug)"
    }

    static func load(slug: String) -> CardPreviewDisplaySnapshot? {
        let k = key(for: slug)
        guard let data = UserDefaults.standard.data(forKey: k) else { return nil }
        return try? JSONDecoder().decode(CardPreviewDisplaySnapshot.self, from: data)
    }

    static func save(_ snapshot: CardPreviewDisplaySnapshot, slug: String) {
        let k = key(for: slug)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: k)
            NotificationCenter.default.post(name: .myfidpassCardPreviewDisplayDidChange, object: nil)
        }
    }

    static func clear(slug: String) {
        UserDefaults.standard.removeObject(forKey: key(for: slug))
    }

    /// Déconnexion / reset : supprime tous les snapshots d’aperçu (clés `myfidpass.cardDisplaySnapshot.v1.*`).
    static func clearAllSnapshots() {
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
        for k in keys where k.hasPrefix("myfidpass.cardDisplaySnapshot.v1.") {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }
}
