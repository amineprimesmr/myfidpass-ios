//
//  FirstLaunchOnboardingView.swift
//  myfidpass
//
//  Premier lancement : connexion / inscription (RootView) après recherche d’établissement.
//

import SwiftUI

/// Premier lancement : recherche d’établissement puis connexion / inscription.
/// Déconnexion : retour direct sur l’écran d’auth (comme Shopify) — la phase « commerce » ne se rejoue pas.
/// Suppression de compte : phase « commerce » à refaire.
enum FirstLaunchOnboarding {
    /// Ancienne clé bool (compat lecture migration uniquement).
    static let key = "myfidpass.hasCompletedFirstLaunchOnboarding"
    /// `needs` = afficher la recherche établissement ; `done` = aller sur connexion / inscription.
    private static let merchantPremisesPhaseKey = "myfidpass.merchantPremises.phase"
    private static let phaseNeeds = "needs"
    private static let phaseDone = "done"
    private static let lastLaunchedShortVersionKey = "myfidpass.lastLaunchedShortVersion"

    /// À appeler tôt au démarrage (ex. `AuthService.loadFromStorage`) avant toute décision d’UI welcome.
    static func bootstrapInstallAndMigrateMerchantPhaseIfNeeded() {
        let d = UserDefaults.standard
        if d.object(forKey: merchantPremisesPhaseKey) != nil {
            recordLastLaunchedAppVersion()
            return
        }
        let previousVersion = d.string(forKey: lastLaunchedShortVersionKey)
        if d.bool(forKey: key) {
            d.set(phaseDone, forKey: merchantPremisesPhaseKey)
        } else if previousVersion != nil {
            d.set(phaseDone, forKey: merchantPremisesPhaseKey)
        } else if hasLegacyAppActivityIndicators() {
            d.set(phaseDone, forKey: merchantPremisesPhaseKey)
        } else {
            // Premier lancement (nouvel install) : commencer par la page « renseignez votre établissement ».
            d.set(phaseNeeds, forKey: merchantPremisesPhaseKey)
        }
        recordLastLaunchedAppVersion()
    }

    private static func recordLastLaunchedAppVersion() {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        UserDefaults.standard.set(v, forKey: lastLaunchedShortVersionKey)
    }

    /// Heuristique : appareil déjà utilisé avec une version antérieure (sans `merchantPremisesPhaseKey`).
    private static func hasLegacyAppActivityIndicators() -> Bool {
        let d = UserDefaults.standard
        if d.bool(forKey: AuthStorage.Key.isLoggedIn) { return true }
        if let em = d.string(forKey: AuthStorage.Key.userEmail)?.trimmingCharacters(in: .whitespacesAndNewlines), !em.isEmpty {
            return true
        }
        if let dash = d.dictionary(forKey: AuthStorage.Key.dashboardTokensBySlug) as? [String: String], !dash.isEmpty {
            return true
        }
        if d.object(forKey: "myfidpass.sync.lastSyncDate") != nil { return true }
        if let pid = d.string(forKey: "myfidpass.ob.placeId")?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
            return true
        }
        if d.object(forKey: "myfidpass.templateLastSavedAt") != nil { return true }
        return false
    }

    /// `true` une fois l’étape « renseignez votre commerce » terminée (ou migrée).
    static var hasCompleted: Bool {
        get { UserDefaults.standard.string(forKey: merchantPremisesPhaseKey) == phaseDone }
        set {
            UserDefaults.standard.set(newValue ? phaseDone : phaseNeeds, forKey: merchantPremisesPhaseKey)
        }
    }

    static func markMerchantPremisesOnboardingFinished() {
        UserDefaults.standard.set(phaseDone, forKey: merchantPremisesPhaseKey)
    }

    /// Après suppression de compte : tout revoir depuis le début (onboarding + clés lieu éventuelles).
    static func resetAfterAccountDeletion() {
        UserDefaults.standard.set(phaseNeeds, forKey: merchantPremisesPhaseKey)
        UserDefaults.standard.removeObject(forKey: key)
        let d = UserDefaults.standard
        [
            "myfidpass.ob.placeId",
            "myfidpass.ob.placeDescription",
            "myfidpass.ob.relaxPlaceRequirement",
            "myfidpass.ob.establishment",
            "myfidpass.ob.loyaltyStyle",
            "myfidpass.ob.priorities",
            "myfidpass.ob.teamSize",
        ].forEach { d.removeObject(forKey: $0) }
        MerchantLinkedPlaceCache.clear()
    }

    /// Lieu saisi pendant l’onboarding — à effacer une fois le compte créé (ne pas réappliquer au prochain utilisateur).
    static func clearPendingEstablishmentFromOnboarding() {
        let d = UserDefaults.standard
        ["myfidpass.ob.placeId", "myfidpass.ob.placeDescription", "myfidpass.ob.relaxPlaceRequirement"].forEach {
            d.removeObject(forKey: $0)
        }
    }

    /// Source de vérité tant que l’inscription n’a pas réussi (évite les ratés si @State LoginView n’a pas fusionné).
    static func readPendingEstablishment() -> (placeId: String?, description: String?, relax: Bool) {
        let d = UserDefaults.standard
        let rawId = d.string(forKey: "myfidpass.ob.placeId")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let pid = rawId.isEmpty ? nil : rawId
        let desc = d.string(forKey: "myfidpass.ob.placeDescription")
        let relax = d.bool(forKey: "myfidpass.ob.relaxPlaceRequirement")
        return (pid, desc, relax)
    }

    /// Lieu + nom d’établissement requis pour une **nouvelle** inscription (même règle que l’API).
    static func hasCompletePendingEstablishmentForRegistration() -> Bool {
        let p = readPendingEstablishment()
        let place = p.placeId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = p.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !place.isEmpty && !name.isEmpty
    }
}

struct FirstLaunchOnboardingView: View {
    var onComplete: () -> Void

    var body: some View {
        MyfidpassMerchantOnboardingRootView(
            onComplete: {
                FirstLaunchOnboarding.hasCompleted = true
                onComplete()
            },
            onAlreadyHaveAccount: {
                FirstLaunchOnboarding.hasCompleted = true
                onComplete()
            }
        )
        .ignoresSafeArea()
    }
}

#Preview {
    FirstLaunchOnboardingView(onComplete: {})
}
