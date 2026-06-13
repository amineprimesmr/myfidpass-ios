//
//  APIDTOs+04_GET.swift
//  myfidpass — extrait de APIDTOs.swift
//

import Foundation

// MARK: - GET .../dashboard/settings

struct BusinessSettingsResponse: Decodable {
    let organizationName: String?
    let backgroundColor: String?
    let foregroundColor: String?
    let labelColor: String?
    let backTerms: String?
    let backContact: String?
    let locationLat: Double?
    let locationLng: Double?
    /// Rayon en mètres pour la pertinence à proximité (Apple Wallet ~100 m max pour carte magasin / fidélité).
    let locationRadiusMeters: Int?
    /// Message affiché / envoyé aux clients qui entrent dans le périmètre.
    let locationRelevantText: String?
    let locationAddress: String?
    /// 1 si le périmètre est embarqué dans le pass Wallet (géofence) ; 0 sinon (recommandé pour les campagnes visibles partout).
    let walletPassIncludeLocations: Int?
    let requiredStamps: Int?
    let stampEmoji: String?
    let stampRewardLabel: String?
    let stampMidRewardLabel: String?
    let startGameRewardLabel: String?
    let programType: String?
    let loyaltyMode: String?
    let pointsPerTicket: Int?
    let pointsPerEuro: Int?
    let pointsPerVisit: Int?
    let pointsMinAmountEur: Double?
    /// Panier moyen « repère » (comparaison stats / compta).
    let baselineAvgBasketEur: Double?
    let pointsRewardTiers: [PointsRewardTierDTO]?
    let expiryMonths: Int?
    let sector: String?
    let stripColor: String?
    let stripDisplayMode: String?
    let stripText: String?
    let labelRestants: String?
    let labelMember: String?
    let headerRightText: String?
    let notificationTitleOverride: String?
    let notificationChangeMessage: String?
    let logoUrl: String?
    /// Logo carré fiche / bandeau (URL `.../logo-icon`) — **pas** l’icône campagne.
    let logoIconUrl: String?
    /// Icône **campagnes / push** uniquement (`.../notification-icon`) lorsqu’un média dédié existe.
    let notificationIconUrl: String?
    let notificationIconUpdatedAt: String?
    let hasCardBackground: Bool?
    /// `true` si `flyer_prefs_json` existe côté serveur (fallback sync avant GET flyer complet).
    let hasFlyerPrefs: Bool?
    let flyerPrefsUpdatedAt: String?
    /// Invalide le cache HTTP / URLCache quand le fond change (query `?v=` côté app).
    let cardBackgroundUpdatedAt: String?
    let hasStampIcon: Bool?
    let stampIconUrl: String?
    let engagementRewards: EngagementRewardsDTO?
    /// Règles campagnes Wallet (automatisation + messages).
    let campaignAutomation: CampaignAutomationConfigDTO?
    /// Date ISO8601 de la dernière mise à jour du logo côté serveur (pour last-write-wins avec l’app).
    let logoUpdatedAt: String?
    let logoIconUpdatedAt: String?
    /// 0 ou absent côté app = illimité — crédits max par client / jour (UTC, serveur).
    let scanMaxPassesPerMemberPerDay: Int?
    /// Plafond de points par opération de crédit (scan ou fiche membre). 0 ou absent = illimité.
    let scanMaxPointsPerTransaction: Int?
    /// 1 = exiger un QR ticket (JWT) pour les crédits basés sur un montant €.
    let requireReceiptQrValidation: Int?
    /// Tolérance en centimes entre montant saisi et JWT (défaut 5).
    let receiptQrToleranceCents: Int?
    /// Hypothèses pour exports bilan (valorisation, montants nominatifs indicatifs).
    let accountingPrefs: MerchantAccountingPrefsDTO?
    /// 1 = bonus d'inscription activé (points ou tampon accordé au 1er ajout Wallet).
    let welcomeBonusEnabled: Int?
    /// Nombre de points (ou tampons) offerts à l'inscription. Défaut 10.
    let welcomeBonusAmount: Int?
}

/// Préférences comptables persistées (`PATCH …/dashboard/settings` → `accounting_prefs_json`).
struct MerchantAccountingPrefsDTO: Codable, Equatable, Sendable {
    var valuationMethod: String?
    var stampRewardNominalEur: Double?
    var engagementPointNominalEur: Double?
    var gameGiftNominalEur: Double?
    var impliedEurPerPointOutstanding: Double?
    /// Clés = nombre de points du palier (ex. `"100"`) → valeur faciale remise en €.
    var tierNominalDiscountEurByPoints: [String: Double]?
    var noteComptable: String?
    /// `auto` lorsque le pack a tout calculé côté serveur.
    var source: String?

    enum CodingKeys: String, CodingKey {
        case valuationMethod = "valuation_method"
        case stampRewardNominalEur = "stamp_reward_nominal_eur"
        case engagementPointNominalEur = "engagement_point_nominal_eur"
        case gameGiftNominalEur = "game_gift_nominal_eur"
        case impliedEurPerPointOutstanding = "implied_eur_per_point_outstanding"
        case tierNominalDiscountEurByPoints = "tier_nominal_discount_eur_by_points"
        case noteComptable = "note_comptable"
        case source
    }
}

