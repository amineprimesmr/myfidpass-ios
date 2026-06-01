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
            "myfidpass.ob.establishments",
            "myfidpass.ob.loyaltyStyle",
            "myfidpass.ob.priorities",
            "myfidpass.ob.teamSize",
            signupCommerceDraftBackupKey,
            signupEmailKey,
        ].forEach { d.removeObject(forKey: $0) }
        MerchantLinkedPlaceCache.clear()
    }

    /// Copie JSON de secours du commerce (survit aux pertes partielles de `myfidpass.ob.*` avant inscription).
    private static let signupCommerceDraftBackupKey = "myfidpass.ob.signupCommerceDraftBackup.v1"

    /// Compte existant : pas de lieu Google requis pour se connecter (OAuth / Apple).
    static func markRelaxPlaceRequirementForExistingAccountFlow() {
        UserDefaults.standard.set(true, forKey: "myfidpass.ob.relaxPlaceRequirement")
    }

    static func persistSignupCommerceDraftBackup(placeId: String, establishmentName: String) {
        let pid = placeId.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = establishmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty, !name.isEmpty else {
            clearSignupCommerceDraftBackup()
            return
        }
        let payload: [String: String] = ["place_id": pid, "establishment_name": name]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let raw = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(raw, forKey: signupCommerceDraftBackupKey)
    }

    static func clearSignupCommerceDraftBackup() {
        UserDefaults.standard.removeObject(forKey: signupCommerceDraftBackupKey)
    }

    private static func readSignupCommerceDraftBackup() -> (placeId: String?, name: String?) {
        guard let raw = UserDefaults.standard.string(forKey: signupCommerceDraftBackupKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return (nil, nil) }
        let pid = (obj["place_id"] as? String ?? obj["placeId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (obj["establishment_name"] as? String ?? obj["establishmentName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = pid.flatMap { $0.isEmpty ? nil : $0 }
        let n = name.flatMap { $0.isEmpty ? nil : $0 }
        return (p, n)
    }

    /// Restaure `myfidpass.ob.placeId` / `placeDescription` depuis le cache lieu ou la sauvegarde JSON si les clés principales sont vides.
    static func rehydratePendingEstablishmentFromAllSourcesIfNeeded() {
        if hasCompletePendingEstablishmentForRegistration() { return }
        let cache = MerchantLinkedPlaceCache.read()
        if let pid = cache.placeId?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
            let desc = cache.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !desc.isEmpty {
                applyRehydratedPlaceToUserDefaults(placeId: pid, establishmentName: desc)
                return
            }
        }
        let backup = readSignupCommerceDraftBackup()
        if let pid = backup.placeId, let name = backup.name, !pid.isEmpty, !name.isEmpty {
            applyRehydratedPlaceToUserDefaults(placeId: pid, establishmentName: name)
        }
    }

    private static func applyRehydratedPlaceToUserDefaults(placeId: String, establishmentName: String) {
        let d = UserDefaults.standard
        d.set(placeId, forKey: "myfidpass.ob.placeId")
        d.set(establishmentName, forKey: "myfidpass.ob.placeDescription")
        MerchantLinkedPlaceCache.save(placeId: placeId, description: establishmentName)
    }

    /// Phase « commerce » terminée mais aucun lieu retenu (ni mode compte existant) : retour à l’étape « nom du commerce ».
    static func shouldRewindToMerchantPremisesSelectionAfterRehydration() -> Bool {
        guard hasCompleted else { return false }
        if hasCompletePendingEstablishmentForRegistration() { return false }
        if readPendingEstablishment().relax { return false }
        return true
    }

    /// Retour à la première étape (sélection commerce) et purge des brouillons incohérents.
    static func rewindToMerchantPremisesSelectionForFreshCommercePick() {
        UserDefaults.standard.set(phaseNeeds, forKey: merchantPremisesPhaseKey)
        clearPendingEstablishmentFromOnboarding()
        MerchantLinkedPlaceCache.clear()
    }

    /// Lieu saisi pendant l’onboarding — à effacer une fois le compte créé (ne pas réappliquer au prochain utilisateur).
    static func clearPendingEstablishmentFromOnboarding() {
        let d = UserDefaults.standard
        [
            "myfidpass.ob.placeId",
            "myfidpass.ob.placeDescription",
            "myfidpass.ob.relaxPlaceRequirement",
            "myfidpass.ob.establishments",
            signupEmailKey,
        ].forEach {
            d.removeObject(forKey: $0)
        }
        clearSignupCommerceDraftBackup()
    }

    /// Source de vérité tant que l’inscription n’a pas réussi (évite les ratés si l’UI onboarding perd son état local).
    static func readPendingEstablishment() -> (placeId: String?, description: String?, relax: Bool) {
        let d = UserDefaults.standard
        let rawId = d.string(forKey: "myfidpass.ob.placeId")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let pid = rawId.isEmpty ? nil : rawId
        let desc = d.string(forKey: "myfidpass.ob.placeDescription")
        let relax = d.bool(forKey: "myfidpass.ob.relaxPlaceRequirement")
        return (pid, desc, relax)
    }

    static func readPendingEstablishments() -> [(placeId: String, description: String)] {
        let d = UserDefaults.standard
        guard let raw = d.string(forKey: "myfidpass.ob.establishments"), !raw.isEmpty,
              let data = raw.data(using: .utf8) else { return [] }
        struct PendingEstablishment: Decodable {
            let placeId: String
            let description: String
        }
        guard let decoded = try? JSONDecoder().decode([PendingEstablishment].self, from: data) else { return [] }
        return decoded.compactMap { item in
            let pid = item.placeId.trimmingCharacters(in: .whitespacesAndNewlines)
            let desc = item.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pid.isEmpty, !desc.isEmpty else { return nil }
            return (pid, desc)
        }
    }

    /// Lieu + nom d’établissement requis pour une **nouvelle** inscription (même règle que l’API).
    static func hasCompletePendingEstablishmentForRegistration() -> Bool {
        let p = readPendingEstablishment()
        let place = p.placeId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = p.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !place.isEmpty && !name.isEmpty
    }

    /// E-mail saisi pendant l’onboarding (étape dédiée avant connexion / inscription).
    private static let signupEmailKey = "myfidpass.ob.signupEmail"

    static func persistSignupEmail(_ email: String) {
        let norm = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !norm.isEmpty else {
            clearSignupEmail()
            return
        }
        UserDefaults.standard.set(norm, forKey: signupEmailKey)
    }

    static func readSignupEmail() -> String? {
        let raw = UserDefaults.standard.string(forKey: signupEmailKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return raw.isEmpty ? nil : raw
    }

    /// Dernier e-mail connu (onboarding, connexion ou session OTP réussie) — préremplissage connexion.
    static func readLastKnownAuthEmail() -> String? {
        readSignupEmail()
    }

    static func clearSignupEmail() {
        UserDefaults.standard.removeObject(forKey: signupEmailKey)
    }
}

struct FirstLaunchOnboardingView: View {
    @EnvironmentObject private var authService: AuthService

    var onComplete: () -> Void
    var onSignIn: (() -> Void)? = nil
    var onAlreadyHaveAccount: (() -> Void)? = nil
    /// Compte déjà existant détecté à l’étape e-mail → basculer vers la connexion avec l’e-mail prérempli.
    var onExistingAccountEmail: ((String) -> Void)? = nil

    var body: some View {
        MyfidpassMerchantOnboardingRootView(
            onComplete: {
                FirstLaunchOnboarding.hasCompleted = true
                onComplete()
            },
            onSignIn: onSignIn,
            onAlreadyHaveAccount: {
                FirstLaunchOnboarding.markRelaxPlaceRequirementForExistingAccountFlow()
                FirstLaunchOnboarding.hasCompleted = true
                if let onAlreadyHaveAccount {
                    onAlreadyHaveAccount()
                } else {
                    onComplete()
                }
            },
            onExistingAccountEmail: { email in
                FirstLaunchOnboarding.persistSignupEmail(email)
                FirstLaunchOnboarding.hasCompleted = true
                onExistingAccountEmail?(email)
            }
        )
        .environmentObject(authService)
        .ignoresSafeArea()
    }
}

#Preview {
    FirstLaunchOnboardingView(onComplete: {})
        .environmentObject(AuthService())
}
