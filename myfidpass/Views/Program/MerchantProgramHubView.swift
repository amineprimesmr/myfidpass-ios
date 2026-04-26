//
//  MerchantProgramHubView.swift
//  myfidpass
//
//  Onglet « Flyer » : création / édition manuelle (aperçu embarqué), partage, éditeur visuel.
//  Règles du programme → « Ma carte » / Avis & réseaux → Réglages.
//

import SwiftUI
import CoreData
import UIKit
import WebKit
import Combine
import PhotosUI
import ImageIO

struct MerchantProgramHubView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var authService: AuthService

    /// Depuis Commerce : ouvrir directement « Ma carte » (ex. checklist étape carte fidélité).
    private let seedOpenMyCard: Bool
    /// Depuis Commerce « Régénérer » : ouvrir l’assistant sur un formulaire vierge (nouveau prompt), pas sur l’aperçu compact.
    private let seedRecreateFlyer: Bool
    /// Depuis l’aperçu Commerce « Modifier » : forcer l’écran d’**édition** (héros + « Modifier le flyer »), pas « Créer un flyer ».
    private let seedOpenFlyerForEdit: Bool
    /// Après enregistrement du flyer IA : revenir sur la checklist Commerce au lieu de l’écran noir du hub (animation « rangement » uniquement là-bas).
    private let onFlyerSaveSuccessReturnToCommerce: (() -> Void)?
    /// Retour depuis l’onglet **Modifier** (Commerce) : remplacer la route par l’écran **Créer le flyer** (ne pas seulement `dismiss`).
    private let onBackFromModifyToCreateFlyer: (() -> Void)?
    /// Remplacement de navigation `flyerFromEditBack` : afficher l’assistant création sans rouvrir tout de suite l’éditeur complet.
    private let startInCreateFromEditBack: Bool
    /// Aligné sur l’aperçu Commerce (même base64 + fond) — **Modifier** : affichage instantané, sync serveur en arrière-plan.
    private let liveCommerceSnapshot: CommerceFlyerLiveSnapshot?
    @State private var didApplyOpenMyCardSeed = false
    @State private var navigateToMyCard = false

    init(
        context _: NSManagedObjectContext,
        seedOpenMyCard: Bool = false,
        seedRecreateFlyer: Bool = false,
        seedOpenFlyerForEdit: Bool = false,
        startInCreateFromEditBack: Bool = false,
        liveCommerceSnapshot: CommerceFlyerLiveSnapshot? = nil,
        onFlyerSaveSuccessReturnToCommerce: (() -> Void)? = nil,
        onBackFromModifyToCreateFlyer: (() -> Void)? = nil
    ) {
        self.seedOpenMyCard = seedOpenMyCard
        self.seedRecreateFlyer = seedRecreateFlyer
        self.seedOpenFlyerForEdit = seedOpenFlyerForEdit
        self.startInCreateFromEditBack = startInCreateFromEditBack
        self.liveCommerceSnapshot = seedOpenFlyerForEdit ? liveCommerceSnapshot : nil
        self.onFlyerSaveSuccessReturnToCommerce = onFlyerSaveSuccessReturnToCommerce
        self.onBackFromModifyToCreateFlyer = onBackFromModifyToCreateFlyer
    }

    private var palette: DashboardRevolutPalette { DashboardRevolutPalette(colorScheme: colorScheme) }

    /// Slug stocké ou premier commerce `/me` (le slug API est toujours une `String` non optionnelle).
    private var resolvedMerchantFlyerSlug: String {
        let fromStorage = AuthStorage.currentBusinessSlug?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromStorage.isEmpty { return fromStorage }
        guard let first = authService.businesses.first else { return "" }
        return first.slug.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            palette.canvas.ignoresSafeArea()

            Group {
                if !resolvedMerchantFlyerSlug.isEmpty {
                    ProgramFlyerTabRoot(
                        slug: resolvedMerchantFlyerSlug,
                        palette: palette,
                        seedRecreateFlyer: seedRecreateFlyer,
                        seedOpenFlyerForEdit: seedOpenFlyerForEdit,
                        startInCreateFromEditBack: startInCreateFromEditBack,
                        liveCommerceSnapshot: liveCommerceSnapshot,
                        onFlyerSaveSuccessReturnToCommerce: onFlyerSaveSuccessReturnToCommerce,
                        onBackFromModifyToCreateFlyer: onBackFromModifyToCreateFlyer
                    )
                    .environmentObject(syncService)
                } else {
                    flyerNoSlugPlaceholder
                }
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToMyCard) {
            MyCardView(context: viewContext)
                .environmentObject(syncService)
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenProgramMyCard)) { _ in
            navigateToMyCard = true
        }
        .onAppear {
            FlyerEmbedWarmup.startIfNeeded()
            if seedOpenMyCard, !didApplyOpenMyCardSeed {
                didApplyOpenMyCardSeed = true
                navigateToMyCard = true
            }
        }
    }

    private var flyerNoSlugPlaceholder: some View {
        VStack(spacing: 14) {
            Image(systemName: "qrcode")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(palette.accentBlue.opacity(0.85))
            Text("Connectez un commerce pour créer votre flyer.")
                .font(.body)
                .foregroundStyle(palette.onCanvasSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Racine onglet Flyer (IA + éditeur)

@MainActor
private struct ProgramFlyerTabRoot: View {
    let slug: String
    let palette: DashboardRevolutPalette
    let seedRecreateFlyer: Bool
    let seedOpenFlyerForEdit: Bool
    let startInCreateFromEditBack: Bool
    let liveCommerceSnapshot: CommerceFlyerLiveSnapshot?
    let onFlyerSaveSuccessReturnToCommerce: (() -> Void)?
    let onBackFromModifyToCreateFlyer: (() -> Void)?
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model: ProgramFlyerEditorModel

    init(
        slug: String,
        palette: DashboardRevolutPalette,
        seedRecreateFlyer: Bool = false,
        seedOpenFlyerForEdit: Bool = false,
        startInCreateFromEditBack: Bool = false,
        liveCommerceSnapshot: CommerceFlyerLiveSnapshot? = nil,
        onFlyerSaveSuccessReturnToCommerce: (() -> Void)? = nil,
        onBackFromModifyToCreateFlyer: (() -> Void)? = nil
    ) {
        self.slug = slug
        self.palette = palette
        self.seedRecreateFlyer = seedRecreateFlyer
        self.seedOpenFlyerForEdit = seedOpenFlyerForEdit
        self.startInCreateFromEditBack = startInCreateFromEditBack
        self.liveCommerceSnapshot = liveCommerceSnapshot
        self.onFlyerSaveSuccessReturnToCommerce = onFlyerSaveSuccessReturnToCommerce
        self.onBackFromModifyToCreateFlyer = onBackFromModifyToCreateFlyer
        let tryDraft = !seedRecreateFlyer && seedOpenFlyerForEdit
        let sessionOpenForEdit = !seedRecreateFlyer && seedOpenFlyerForEdit
        _model = StateObject(
            wrappedValue: ProgramFlyerEditorModel(
                slug: slug,
                liveCommerceSnapshot: seedOpenFlyerForEdit ? liveCommerceSnapshot : nil,
                allowRestoringSessionDraft: tryDraft,
                sessionStartedWithOpenForEdit: sessionOpenForEdit
            )
        )
    }

    var body: some View {
        FlyerAIGeneratorSheet(
            slug: slug,
            palette: palette,
            initialPrimaryHex: model.state.colorPrimary,
            flyerModel: model,
            isTabRoot: true,
            seedRecreateFlyerSession: seedRecreateFlyer,
            seedOpenFlyerForEdit: seedOpenFlyerForEdit,
            startInCreateFromEditBack: startInCreateFromEditBack,
            onFlyerSaveSuccessReturnToCommerce: onFlyerSaveSuccessReturnToCommerce,
            onBackFromModifyToCreateFlyer: onBackFromModifyToCreateFlyer
        )
        .onChange(of: scenePhase) { _, new in
            if new == .background { model.persistUnsavedFlyerSessionDraftIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            model.persistUnsavedFlyerSessionDraftIfNeeded()
        }
        .task(id: slug) {
            if seedRecreateFlyer {
                CommerceFlyerEditorDraftStore.clear(slug: slug)
                await model.load(showProgress: true, forceFullFlyerPrefsMerge: true)
            } else if model.usesInstantCommerceAlignedBootstrap {
                /// Même contenu que la carte Commerce (snapshot passé par `ProfileView`) : pas besoin d’**attendre** le GET
                /// pour l’aperçu — on synchronise le serveur en arrière-plan (PUT / quotas), comme sur Commerce après `loadProfileFromServer`.
                Task { @MainActor in
                    await model.load(showProgress: false)
                }
            } else {
                await model.load(showProgress: !model.hasCompletedSuccessfulFlyerLoad)
            }
        }
        .refreshable {
            await syncService.syncAfterServerMutation()
            await model.load(showProgress: true, forceFullFlyerPrefsMerge: true)
        }
    }
}

// MARK: - Navigation

private enum ProgramHubRoute: Hashable {
    case myCard
}

// MARK: - Flyer QR (édition in-app + aperçu)

/// Plafonds `fidelity/backend/src/lib/flyer-prefs.js` : logo &lt; 5 Mo, fond &lt; 6 Mo (longueur chaîne), JSON `flyer_prefs` total plafonné (`MAX_JSON_CHARS`).
/// Le logo et le fond doivent tenir **ensemble** dans le JSON : on cible des data URLs nettement sous les plafonds par champ.
private enum FlyerDashboardFlyerPrefsLimits {
    /// Marge sous `MAX_JSON_CHARS` côté API (évite 400 « Flyer trop volumineux » après stringify serveur).
    static let serverFlyerPrefsJSONMaxBytes = 10 * 1024 * 1024 - 384_000
    static let maxBgDataURLUtf8Bytes = 6 * 1024 * 1024 - 1
    static let maxLogoDataURLUtf8Bytes = 5 * 1024 * 1024 - 1
    /// JPEG décodé pour le fond IA : marge avec logo (~2,4 Mo de chaîne max) + `state` dans le même JSON.
    static let aiBackgroundJPEGMaxDecodedBytes = 2_800_000
    /// Chaîne `custom_logo_data_url` (souvent JPEG) — cible sous le plafond JSON avec `flyerLogoExportDataURLReliable`.
    static let logoPngMaxEncodedUtf8Bytes = 2_400_000
}

private enum FlyerGeneratedImageDecode {
    /// `UIImage(data:)` échoue parfois (profils ICC, PNG exotiques) — même stratégème que le sélecteur photo.
    static func uiImage(fromBase64PNG raw: String) -> UIImage? {
        guard let data = Data(base64Encoded: raw), !data.isEmpty else { return nil }
        if let u = UIImage(data: data) { return u }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        // Pas d’accès à `UIScreen.main` ici (Swift 6 : hors MainActor) — repli décodage uniquement.
        return UIImage(cgImage: cg, scale: 1.0, orientation: .up)
    }
}

/// Sauvegarde du fond IA généré sur disque entre les sessions — survit à un force-quit.
/// Effacé après enregistrement serveur réussi ; restauré au prochain lancement si le serveur n’a pas encore le fond.
private final class FlyerPendingBgStorage {
    static let shared = FlyerPendingBgStorage()
    private init() {}

    private func fileURL(slug: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let safe = slug.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "flyer"
        return caches.appendingPathComponent("flyerPendingBg_\(safe).dat")
    }

    /// Enregistre le PNG brut (issu du base64) sur disque.
    func save(pngBase64: String, slug: String) {
        guard !pngBase64.isEmpty, let data = Data(base64Encoded: pngBase64) else { return }
        try? data.write(to: fileURL(slug: slug), options: .atomic)
    }

    /// Charge le PNG depuis le disque → base64 String prêt pour `generatedBase64`.
    func loadBase64(slug: String) -> String? {
        let url = fileURL(slug: slug)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return data.base64EncodedString()
    }

    func clear(slug: String) {
        try? FileManager.default.removeItem(at: fileURL(slug: slug))
    }

    func hasPending(slug: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(slug: slug).path)
    }
}

/// Copie de l’illustration **avant** un « Recréer » (permet de revenir à la 1ʳᵉ version si le 2ᵉ rendu déçoit) — indépendant de `flyerPendingBg`.
private final class FlyerRecreatePreviousBackupStorage {
    static let shared = FlyerRecreatePreviousBackupStorage()
    private init() {}

    private func fileURL(slug: String) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let safe = slug.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "flyer"
        return caches.appendingPathComponent("flyerRecreatePrevious_\(safe).dat")
    }

    func save(rawBase64: String, slug: String) {
        guard !rawBase64.isEmpty, let data = Data(base64Encoded: rawBase64) else { return }
        try? data.write(to: fileURL(slug: slug), options: .atomic)
    }

    func loadBase64(slug: String) -> String? {
        let url = fileURL(slug: slug)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return data.base64EncodedString()
    }

    func clear(slug: String) {
        try? FileManager.default.removeItem(at: fileURL(slug: slug))
    }
}

/// Décode `data:image/…;base64,…` (PNG, JPEG, WebP) — même fond qu’après GET dashboard.
private enum FlyerDataURLImageDecode {
    static func uiImage(fromDataURLString s: String?) -> UIImage? {
        let t = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard t.hasPrefix("data:image/"), let comma = t.firstIndex(of: ",") else { return nil }
        let b64 = String(t[t.index(after: comma)...])
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        return FlyerGeneratedImageDecode.uiImage(fromBase64PNG: b64)
    }
}

private struct FlyerEditSnapshot: Equatable {
    var state: FlyerStateDTO
    var logo: FlyerRemoteImagePayload
    var bg: FlyerRemoteImagePayload
}

@MainActor
private final class ProgramFlyerEditorModel: ObservableObject {
    let slug: String

    @Published var state: FlyerStateDTO
    @Published var shareUrl: String = ""
    @Published private(set) var serverUpdatedAt: String?
    @Published var logoPayload: FlyerRemoteImagePayload = .leaveUnchanged
    @Published var bgPayload: FlyerRemoteImagePayload = .leaveUnchanged
    @Published private(set) var serverLogoDataUrl: String?
    /// Préchargement du logo public commerce (WKWebView + CORS) pour l’aperçu quand aucun logo custom n’est en base64.
    @Published private(set) var cachedPublicLogoDataUrl: String?
    @Published private(set) var serverBgDataUrl: String?
    /// Même chose que l’ancien `custom_bg` du JSON, sans le repasser dans l’injection WK (évite troncature + charge le calque natif).
    var flyerCustomBgDataURLForNativeUnderlay: String? { effectiveBgPreview() }
    @Published var loadError: String?
    @Published var saveError: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published private(set) var bootstrapPreviewBase64: String?
    /// Aperçu : image sous la WebView (fond photo/IA) — `nil` si seul le dégradé (dans le JSON) suffit.
    @Published var flyerWebUnderlayUIImage: UIImage? = nil
    /// Aperçu : le fond est en `UIImage` natif, pas de remplissage blanc / dégradé plein côté canvas.
    @Published var flyerWebSkipCanvasSolidBackground: Bool = false
    /// Quota mensuel (3 / mois UTC) ; ignoré si `flyerAiUnlimited`.
    @Published var flyerAiGenerationsRemaining: Int = 3
    /// Créations flyer illimitées si renvoyé ainsi par l’API (offre / compte).
    @Published var flyerAiUnlimited: Bool = false

    private var isUndoRedoOrLoad = false
    private var undoStack: [FlyerEditSnapshot] = []
    private var redoStack: [FlyerEditSnapshot] = []
    /// Dernier chargement réussi depuis l’API — évite un GET à chaque retour sur l’onglet Flyer (fluide, état local conservé).
    /// Accès fichier uniquement (`ProgramFlyerEditorModel` est `private`).
    var lastSuccessfulServerLoadAt: Date?
    /// Au moins un `load()` réussi (l’assistant ne doit pas lire la date brute, réservée au modèle).
    var hasCompletedSuccessfulFlyerLoad: Bool { lastSuccessfulServerLoadAt != nil }
    /// Dernier état connu comme issu d’un **GET / save / cache** : si le texte & couleurs enregistrés côté serveur
    /// diffont du gabarit par défaut. Ne **pas** se recalculer sur chaque `applyState` local (ex. teinte extraite
    /// du logo avant la 1ʳᵉ génération), sinon l’écran bascule indûment de « Créer » → « Modifier ».
    @Published private(set) var serverSnapshotStateWasNonDefault: Bool = false
    /// Après « Recréer » / régénérer : n’injecte pas l’ancien `custom_logo_data_url` du dashboard dans le bootstrap (sinon WKWebView garde l’ancien logo jusqu’au prochain enregistrement).
    var suppressDashboardCustomLogoForPreview = false

    /// `true` : le modèle a été initialisé avec le **même** JSON + fond + lien que l’onglet Commerce — le GET
    /// d’`load()` peut tourner en arrière-plan (pas d’`await` bloquant le 1ʳᵉ frame de l’éditeur).
    private(set) var usesInstantCommerceAlignedBootstrap = false
    /// Entrée hub via « Modifier le flyer » (détermine l’auto-reprise écran d’édition au prochain lancement).
    private let sessionStartedWithOpenForEdit: Bool

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init(
        slug: String,
        liveCommerceSnapshot: CommerceFlyerLiveSnapshot? = nil,
        allowRestoringSessionDraft: Bool = false,
        sessionStartedWithOpenForEdit: Bool = false
    ) {
        self.slug = slug
        self.state = FlyerStateDTO.default
        self.sessionStartedWithOpenForEdit = sessionStartedWithOpenForEdit
        if allowRestoringSessionDraft,
           let d = CommerceFlyerEditorDraftStore.load(slug: slug),
           applyFromEditorSessionDraft(meta: d.meta, bootstrapB64: d.bootstrapB64)
        {
            usesInstantCommerceAlignedBootstrap = true
        } else if let snap = liveCommerceSnapshot, applyFromLiveCommerceSnapshot(snap) {
            usesInstantCommerceAlignedBootstrap = true
        } else if !hydrateFromCommerceDiskCacheIfAvailable() {
            refreshPreviewBootstrap()
        }
    }

    /// Brouillon local (session « Modifier le flyer ») : logo/bg payload + miroir serveur pour relancer après kill.
    private func applyFromEditorSessionDraft(meta: FlyerEditorSessionDraftMeta, bootstrapB64: String) -> Bool {
        let b64Raw = bootstrapB64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !b64Raw.isEmpty else { return false }
        let b64 = FlyerBootstrapPreviewPayloadBuilder.normalizeWheelModeInBootstrapBase64(b64Raw, businessSlug: slug) ?? b64Raw
        guard let stateFromPayload = FlyerBootstrapPreviewPayloadBuilder.flyerStateFromBootstrapBase64(b64) else { return false }
        guard let data = Data(base64Encoded: b64),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        let shareFromJson = (root["share_url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let metaShare = meta.shareURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let share = !metaShare.isEmpty ? metaShare : shareFromJson
        var jsonLogo: String?
        var jsonBg: String?
        if let fp = root["flyer_prefs"] as? [String: Any] {
            if let s = fp["custom_logo_data_url"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { jsonLogo = s }
            if let s = fp["custom_bg_data_url"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { jsonBg = s }
        }
        var st = stateFromPayload
        st.normalizeClamps()
        st = FlyerWheelWebEmbedPreviewMigration.normalizedStateForPreview(st, businessSlug: slug)
        isUndoRedoOrLoad = true
        state = st
        shareUrl = share
        let sLogoT = meta.serverLogoDataUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sBgT = meta.serverBgDataUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !sLogoT.isEmpty {
            serverLogoDataUrl = meta.serverLogoDataUrl
        } else if let j = jsonLogo, !j.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            serverLogoDataUrl = j
        } else {
            serverLogoDataUrl = nil
        }
        if !sBgT.isEmpty {
            serverBgDataUrl = meta.serverBgDataUrl
        } else if let j = jsonBg, !j.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            serverBgDataUrl = j
        } else {
            serverBgDataUrl = nil
        }
        logoPayload = meta.logoPayload.toPayload()
        bgPayload = meta.bgPayload.toPayload()
        loadError = nil
        lastSuccessfulServerLoadAt = Date()
        recomputeServerSnapshotStateFlag(using: st)
        isUndoRedoOrLoad = false
        suppressDashboardCustomLogoForPreview = meta.suppressDashboardCustomLogoForPreview
        cachedPublicLogoDataUrl = meta.cachedPublicLogoDataUrl
        if let u = meta.serverUpdatedAt?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
            serverUpdatedAt = u
        } else {
            serverUpdatedAt = (root["updated_at"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? nil
        }
        refreshPreviewBootstrap()
        undoStack.removeAll()
        redoStack.removeAll()
        return true
    }

    /// Écrit l’aperçu courant + payloads sur disque — appelé en arrière-plan d’app / resign active.
    func persistUnsavedFlyerSessionDraftIfNeeded() {
        let b = bootstrapPreviewBase64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !b.isEmpty else { return }
        let meta = FlyerEditorSessionDraftMeta(
            shareURL: shareUrl,
            customBgDataURL: effectiveBgPreview(),
            serverLogoDataUrl: serverLogoDataUrl,
            serverBgDataUrl: serverBgDataUrl,
            logoPayload: .from(logoPayload),
            bgPayload: .from(bgPayload),
            suppressDashboardCustomLogoForPreview: suppressDashboardCustomLogoForPreview,
            cachedPublicLogoDataUrl: cachedPublicLogoDataUrl,
            serverUpdatedAt: serverUpdatedAt,
            savedAt: Date(),
            openedAsFlyerForEdit: sessionStartedWithOpenForEdit
        )
        CommerceFlyerEditorDraftStore.save(slug: slug, bootstrapB64: b, meta: meta)
    }

    /// Même logique que `hydrateFromCommerceDiskCacheIfAvailable`, mais à partir de l’état **déjà en mémoire**
    /// sur l’onglet Commerce (au lieu du seul disque, potentiellement un peu moins à jour).
    private func applyFromLiveCommerceSnapshot(_ snap: CommerceFlyerLiveSnapshot) -> Bool {
        let b64Raw = (snap.bootstrapPreviewB64 ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !b64Raw.isEmpty else { return false }
        let b64 = FlyerBootstrapPreviewPayloadBuilder.normalizeWheelModeInBootstrapBase64(b64Raw, businessSlug: slug) ?? b64Raw
        guard let stateFromPayload = FlyerBootstrapPreviewPayloadBuilder.flyerStateFromBootstrapBase64(b64) else { return false }
        guard let data = Data(base64Encoded: b64),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        let shareFromJson = (root["share_url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let shareFromSnap = (snap.shareURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let share = !shareFromSnap.isEmpty ? shareFromSnap : shareFromJson
        var logo: String?
        var bg: String?
        if let fp = root["flyer_prefs"] as? [String: Any] {
            if let s = fp["custom_logo_data_url"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { logo = s }
            if let s = fp["custom_bg_data_url"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { bg = s }
        }
        let snapBg = (snap.customBgDataURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !snapBg.isEmpty { bg = snapBg } else if (bg == nil || (bg?.isEmpty == true)) {
            if let loaded = CommerceFlyerStateCache.load(slug: slug) {
                let c = loaded.customBgDataURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !c.isEmpty { bg = c }
            }
        }
        var st = stateFromPayload
        st.normalizeClamps()
        st = FlyerWheelWebEmbedPreviewMigration.normalizedStateForPreview(st, businessSlug: slug)
        isUndoRedoOrLoad = true
        state = st
        shareUrl = share
        serverLogoDataUrl = logo
        serverBgDataUrl = bg
        logoPayload = .leaveUnchanged
        bgPayload = .leaveUnchanged
        loadError = nil
        lastSuccessfulServerLoadAt = Date()
        recomputeServerSnapshotStateFlag(using: st)
        isUndoRedoOrLoad = false
        suppressDashboardCustomLogoForPreview = false
        refreshPreviewBootstrap()
        return true
    }

    /// Même `bootstrap.b64` + `custom_bg` que la checklist Commerce : permet d’afficher l’éditeur sans attendre le GET réseau.
    private func hydrateFromCommerceDiskCacheIfAvailable() -> Bool {
        guard let loaded = CommerceFlyerStateCache.load(slug: slug) else { return false }
        let b64 = loaded.bootstrapPreviewB64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !b64.isEmpty, let stateFromDisk = FlyerBootstrapPreviewPayloadBuilder.flyerStateFromBootstrapBase64(b64) else { return false }
        guard let data = Data(base64Encoded: b64),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return false }
        let share = (root["share_url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? loaded.shareURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var logo: String?
        var bg: String?
        if let fp = root["flyer_prefs"] as? [String: Any] {
            if let s = fp["custom_logo_data_url"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { logo = s }
            if let s = fp["custom_bg_data_url"] as? String, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { bg = s }
        }
        if (bg == nil || bg?.isEmpty == true) {
            let c = loaded.customBgDataURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !c.isEmpty { bg = c }
        }
        var st = stateFromDisk
        st.normalizeClamps()
        st = FlyerWheelWebEmbedPreviewMigration.normalizedStateForPreview(st, businessSlug: slug)
        isUndoRedoOrLoad = true
        state = st
        shareUrl = share
        serverLogoDataUrl = logo
        serverBgDataUrl = bg
        logoPayload = .leaveUnchanged
        bgPayload = .leaveUnchanged
        loadError = nil
        lastSuccessfulServerLoadAt = Date()
        recomputeServerSnapshotStateFlag(using: st)
        isUndoRedoOrLoad = false
        suppressDashboardCustomLogoForPreview = false
        refreshPreviewBootstrap()
        return true
    }

    func applyState(_ newState: FlyerStateDTO, recordUndo: Bool = true) {
        var n = newState
        n.normalizeClamps()
        guard n != state else { return }
        if recordUndo && !isUndoRedoOrLoad {
            undoStack.append(FlyerEditSnapshot(state: state, logo: logoPayload, bg: bgPayload))
            if undoStack.count > 35 { undoStack.removeFirst() }
            redoStack.removeAll()
        }
        state = n
        refreshPreviewBootstrap()
    }

    func applyLogoPayload(_ p: FlyerRemoteImagePayload) {
        guard p != logoPayload else { return }
        if !isUndoRedoOrLoad {
            undoStack.append(FlyerEditSnapshot(state: state, logo: logoPayload, bg: bgPayload))
            if undoStack.count > 35 { undoStack.removeFirst() }
            redoStack.removeAll()
        }
        logoPayload = p
        switch p {
        case .dataURL:
            suppressDashboardCustomLogoForPreview = false
            cachedPublicLogoDataUrl = nil
            refreshPreviewBootstrap()
        case .clear:
            cachedPublicLogoDataUrl = nil
            refreshPreviewBootstrap()
        case .leaveUnchanged:
            Task { @MainActor in
                await prefetchPublicLogoCacheIfNeeded()
                refreshPreviewBootstrap()
            }
            refreshPreviewBootstrap()
        }
    }

    func applyBgPayload(_ p: FlyerRemoteImagePayload) {
        guard p != bgPayload else { return }
        if !isUndoRedoOrLoad {
            undoStack.append(FlyerEditSnapshot(state: state, logo: logoPayload, bg: bgPayload))
            if undoStack.count > 35 { undoStack.removeFirst() }
            redoStack.removeAll()
        }
        bgPayload = p
        refreshPreviewBootstrap()
    }

    func undo() {
        guard let snap = undoStack.popLast() else { return }
        redoStack.append(FlyerEditSnapshot(state: state, logo: logoPayload, bg: bgPayload))
        isUndoRedoOrLoad = true
        state = snap.state
        logoPayload = snap.logo
        bgPayload = snap.bg
        isUndoRedoOrLoad = false
        refreshPreviewBootstrap()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func redo() {
        guard let snap = redoStack.popLast() else { return }
        undoStack.append(FlyerEditSnapshot(state: state, logo: logoPayload, bg: bgPayload))
        isUndoRedoOrLoad = true
        state = snap.state
        logoPayload = snap.logo
        bgPayload = snap.bg
        isUndoRedoOrLoad = false
        refreshPreviewBootstrap()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func binding(_ keyPath: WritableKeyPath<FlyerStateDTO, String>) -> Binding<String> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { newVal in
                var s = self.state
                s[keyPath: keyPath] = newVal
                self.applyState(s)
            }
        )
    }

    func binding(_ keyPath: WritableKeyPath<FlyerStateDTO, Double>) -> Binding<Double> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { newVal in
                var s = self.state
                s[keyPath: keyPath] = newVal
                self.applyState(s)
            }
        )
    }

    func binding(_ keyPath: WritableKeyPath<FlyerStateDTO, Bool>) -> Binding<Bool> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { newVal in
                var s = self.state
                s[keyPath: keyPath] = newVal
                self.applyState(s)
            }
        )
    }

    private func effectiveLogoPreview() -> String? {
        switch logoPayload {
        case .leaveUnchanged:
            if let s = serverLogoDataUrl, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return s
            }
            return cachedPublicLogoDataUrl
        case .clear: return nil
        case .dataURL(let s): return s
        }
    }

    /// Même source que l’aperçu — pour recalculer le PNG (détourage / conserver l’arrière-plan) quand il n’y a plus d’`UIImage` local (`logoPreview` vide).
    func logoSourceDataURLStringForReexport() -> String? {
        effectiveLogoPreview()
    }

    /// Bootstrap WK : `""` = pas de logo sur le canvas **et** pas de repli `/public/logo` (évite le logo « Ma Carte » après effacement).
    /// `nil` = omettre la clé → `flyer-embed` charge le logo public `/public/flyer-qr-logo` (comportement attendu après « Recréer » tant qu’aucun nouveau logo n’est choisi).
    private func customLogoDataUrlForBootstrap() -> String? {
        if suppressDashboardCustomLogoForPreview {
            switch logoPayload {
            case .clear: return ""
            case .dataURL(let s): return s
            case .leaveUnchanged: return nil
            }
        }
        switch logoPayload {
        case .clear: return ""
        case .dataURL(let s): return s
        case .leaveUnchanged: return effectiveLogoPreview()
        }
    }

    /// Appelé au début d’une session « recréer / régénérer » : l’aperçu ne doit plus refléter l’ancien logo enregistré.
    func beginFlyerRecreateSessionForPreview() {
        suppressDashboardCustomLogoForPreview = true
        cachedPublicLogoDataUrl = nil
        refreshPreviewBootstrap()
    }

    /// Réouverture « Modifier le flyer » (hors assitant recréer) : ne pas laisser le drapeau « recréer » bloquer
    /// l’injection du logo enregistré (sinon clé absente + fetch `/public/…` lent → aperçu nu puis logo en retard).
    func clearRecreateSessionSuppressionForEditEntry() {
        guard suppressDashboardCustomLogoForPreview else { return }
        suppressDashboardCustomLogoForPreview = false
        refreshPreviewBootstrap()
    }

    /// Même source que la page jeu QR et `/public/flyer-qr-logo` — pas le logo « bandeau Wallet » (évite le carré vert texte).
    private func publicLogoURL() -> URL {
        APIConfig.baseURL.appendingPathComponent("api/businesses/\(slug)/public/flyer-qr-logo", isDirectory: false)
    }

    /// Télécharge le logo commerce pour l’injecter en data URL dans le bootstrap (évite fetch cross-origin fragile dans la WebView).
    func prefetchPublicLogoCacheIfNeeded() async {
        let skipFetch = await MainActor.run { () -> Bool in
            if case .dataURL = logoPayload {
                cachedPublicLogoDataUrl = nil
                return true
            }
            if case .clear = logoPayload {
                cachedPublicLogoDataUrl = nil
                return true
            }
            if let s = serverLogoDataUrl, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cachedPublicLogoDataUrl = nil
                return true
            }
            return false
        }
        if skipFetch { return }
        let url = publicLogoURL()
        var req = URLRequest(url: url)
        req.timeoutInterval = 18
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode), !data.isEmpty else {
                await MainActor.run { cachedPublicLogoDataUrl = nil }
                return
            }
            let mimeHeader = http.value(forHTTPHeaderField: "Content-Type") ?? "image/png"
            let mime = String(mimeHeader.split(separator: ";").first ?? "image/png")
            let b64 = data.base64EncodedString()
            let dataUrl = "data:\(mime);base64,\(b64)"
            await MainActor.run {
                cachedPublicLogoDataUrl = dataUrl
                refreshPreviewBootstrap()
            }
        } catch {
            await MainActor.run { cachedPublicLogoDataUrl = nil }
        }
    }

    private func effectiveBgPreview() -> String? {
        switch bgPayload {
        case .leaveUnchanged: return serverBgDataUrl
        case .clear: return nil
        case .dataURL(let s): return s
        }
    }

    /// Aperçu héros « authentique » côté serveur : visuels persistés ou `state` déjà personnalisé **au dernier sync**
    /// (GET / cache / PUT). N’inclut pas le `state` modifié uniquement en local avant 1ʳᵉ génération.
    var hasPersistedServerContextForFlyerHero: Bool {
        if let s = serverBgDataUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
           s.hasPrefix("data:image/")
        {
            return true
        }
        if let s = serverLogoDataUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return true
        }
        return serverSnapshotStateWasNonDefault
    }

    private func recomputeServerSnapshotStateFlag(using st: FlyerStateDTO) {
        var a = st
        a.normalizeClamps()
        var b = FlyerStateDTO.default
        b.normalizeClamps()
        let v = a != b
        if serverSnapshotStateWasNonDefault != v {
            serverSnapshotStateWasNonDefault = v
        }
    }

    func refreshPreviewBootstrap() {
        let st = FlyerWheelWebEmbedPreviewMigration.normalizedStateForPreview(state, businessSlug: slug)
        let logoB64 = customLogoDataUrlForBootstrap()
        /// Ne **jamais** embarquer le `data:` du fond dans le JSON injecté dans la WebView : même à 200 k caractères,
        /// le base64 final + `evaluateJavaScript` (limite ~100k par « shot ») faisait tomber l’injection → canvas vide
        /// (plus de logo / roue / texte). L’illustration est affichée en `UIImage` (`FlyerNativeUnderlayStack`) via
        /// `flyerCustomBgDataURLForNativeUnderlay` — aligné sur l’aperçu héros `embedCustomBackgroundInJson: false`.
        let enc = JSONEncoder()
        /// **camelCase** dans l’objet `state` : le bundle en ligne `app-flyer-qr-draw*.js` lit `r.wheelRenderMode` (pas
        /// `r.wheel_render_mode`). S’il est `undefined`, le merge fixe le mode à `"png"` → masque 3D + moyeu central.
        enc.keyEncodingStrategy = .useDefaultKeys
        let payload = FlyerBootstrapPreviewPayload(
            flyerPrefs: .init(
                state: st,
                customLogoDataUrl: logoB64,
                customBgDataUrl: nil,
                businessSlug: slug
            ),
            updatedAt: serverUpdatedAt,
            shareUrl: shareUrl
        )
        /// Aucun repli partiel (état tronqué) : l’ancien repli omettait `colorBgTop` / `colorBgBottom` et d’autres champs
        /// → l’embed ne redessinait plus roue / QR / textes (aperçu « nu » ou instable après réglage du dégradé).
        guard let data = try? enc.encode(payload) else { return }
        bootstrapPreviewBase64 = data.base64EncodedString()
        recomputeFlyerWebCanvasDisplayLayers()
    }

    /// Même `bootstrap` pour WK (pas d’JSON « strip » vs plein) : on évite 2 `APPLY` successifs (flash) quand le underlay se décode.
    private func recomputeFlyerWebCanvasDisplayLayers() {
        if let s = effectiveBgPreview()?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty,
           let u = FlyerDataURLImageDecode.uiImage(fromDataURLString: s) {
            flyerWebUnderlayUIImage = u
            flyerWebSkipCanvasSolidBackground = true
        } else {
            flyerWebUnderlayUIImage = nil
            flyerWebSkipCanvasSolidBackground = false
        }
    }

    /// Avant d’ouvrir le héros d’aperçu : logo public, fond manquant côté GET, puis 1ʳᵉ `refresh` cohérente (teintes + visuels).
    func prepareWebPreviewBeforeReveal() async {
        await prefetchPublicLogoCacheIfNeeded()
        await hydrateCustomBgFromPublicEndpointIfNeeded()
        refreshPreviewBootstrap()
    }

    /// Même JSON que l’aperçu studio (`flyer-embed`), avec fond optionnellement forcé (ex. PNG IA avant enregistrement).
    /// `provisionalCustomLogoDataURL` : logo choisi dans la sheet IA (`logoPreview`) avant `applyLogoPayload` au moment du glissement.
    /// - `embedCustomBackgroundInJson` : si `false`, n’inclut **pas** le data URL du fond (souvent > 1–5 Mo) dans le JSON.
    ///   L’illustration est alors affichée en **UIImage** sous la WebView (`skipCanvasSolidBackground` + `FlyerNativeUnderlayStack`).
    ///   Évite un JSON énorme → `JSONEncoder` / injection WK qui faisaient tomber l’encodage à `nil` : l’aperçu
    ///   passait sur un repli « vide » côté embed et on **perdait** roue / QR + sensation de « fond seul » sans l’IA.
    func encodedPreviewBootstrapBase64(
        provisionalCustomBgDataURL: String?,
        provisionalCustomLogoDataURL: String? = nil,
        embedCustomBackgroundInJson: Bool = true
    ) -> String? {
        let st = FlyerWheelWebEmbedPreviewMigration.normalizedStateForPreview(state, businessSlug: slug)
        let bg: String? = {
            if !embedCustomBackgroundInJson { return nil }
            /// Ne pas reprendre `effectiveBgPreview()` ici : même cause que `refreshPreviewBootstrap` (injection tronquée).
            return provisionalCustomBgDataURL
        }()
        let logoForBootstrap = provisionalCustomLogoDataURL ?? customLogoDataUrlForBootstrap()
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .useDefaultKeys
        let payload = FlyerBootstrapPreviewPayload(
            flyerPrefs: .init(
                state: st,
                customLogoDataUrl: logoForBootstrap,
                customBgDataUrl: bg,
                businessSlug: slug
            ),
            updatedAt: serverUpdatedAt,
            shareUrl: shareUrl
        )
        guard let data = try? enc.encode(payload) else { return nil }
        return data.base64EncodedString()
    }

    private static func humanizedLoadError(_ error: Error) -> String {
        if let api = error as? APIError, case .decoding = api {
            return "La réponse du serveur pour le Flyer n’a pas pu être lue (format inattendu). Réessaie, ou mets l’app à jour. Cela n’est pas dû à un choix de couleurs côté écran d’édition."
        }
        if let api = error as? APIError, let m = api.errorDescription { return m }
        return error.localizedDescription
    }

    /// - Parameter showProgress: si `false`, pas de `ProgressView` plein écran (sync en arrière-plan après hydratation cache).
    /// - Parameter forceFullFlyerPrefsMerge: si `true`, remplace toujours état + visuels par le GET (rechargement explicite).
    ///   Si `false` et que l’écran vient du **snapshot Commerce** déjà hydraté, on ne fusionne que quotas / `share_url` :
    ///   un GET en arrière-plan ne doit pas écraser `state` ni effacer logo/fond absents du JSON partiel — sinon l’aperçu
    ///   « repart à zéro » au moindre changement de couleur de roue (course avec `load()`).
    func load(showProgress: Bool = true, forceFullFlyerPrefsMerge: Bool = false) async {
        if showProgress { isLoading = true }
        loadError = nil
        defer { if showProgress { isLoading = false } }
        do {
            let res: DashboardFlyerGetResponse = try await APIClient.shared.request(APIEndpoint.dashboardFlyerGet(slug: slug))
            shareUrl = res.shareUrl ?? ""
            flyerAiUnlimited = res.flyerAiUnlimited == true
            if flyerAiUnlimited {
                flyerAiGenerationsRemaining = 999
            } else if let rem = res.flyerAiGenerationsRemaining {
                flyerAiGenerationsRemaining = max(0, rem)
            } else if let u = res.flyerAiGenerationsUsed {
                flyerAiGenerationsRemaining = max(0, 3 - u)
            } else {
                flyerAiGenerationsRemaining = 3
            }
            serverUpdatedAt = res.updatedAt

            let skipHeavyPrefsMerge =
                !forceFullFlyerPrefsMerge
                && usesInstantCommerceAlignedBootstrap
                && lastSuccessfulServerLoadAt != nil

            if skipHeavyPrefsMerge {
                loadError = nil
                suppressDashboardCustomLogoForPreview = false
                Task { @MainActor in
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask { await self.prefetchPublicLogoCacheIfNeeded() }
                        group.addTask { await self.hydrateCustomBgFromPublicEndpointIfNeeded() }
                    }
                    self.refreshPreviewBootstrap()
                }
                return
            }

            isUndoRedoOrLoad = true
            var shouldPersistFlyerWheelPngMigration = false
            if let fp = res.flyerPrefs {
                Self.assignServerVisualsFromFlyerPrefs(
                    fp: fp,
                    forceReplaceWithEmpty: forceFullFlyerPrefsMerge,
                    logoDestination: &serverLogoDataUrl,
                    bgDestination: &serverBgDataUrl
                )
                if let s = fp.state {
                    var merged = s
                    merged.normalizeClamps()
                    let beforeMode = merged.wheelRenderMode
                    merged = FlyerWheelWebEmbedPreviewMigration.normalizedStateForPreview(merged, businessSlug: self.slug)
                    if beforeMode == "segments", merged.wheelRenderMode == "png" {
                        shouldPersistFlyerWheelPngMigration = true
                    }
                    state = merged
                } else {
                    state = FlyerStateDTO.default
                }
            } else {
                state = FlyerStateDTO.default
                serverLogoDataUrl = nil
                serverBgDataUrl = nil
            }
            logoPayload = .leaveUnchanged
            bgPayload = .leaveUnchanged
            undoStack.removeAll()
            redoStack.removeAll()
            isUndoRedoOrLoad = false
            recomputeServerSnapshotStateFlag(using: state)
            refreshPreviewBootstrap()
            /// Après un GET réussi, l’aperçu doit à nouveau utiliser le logo du profil (`serverLogoDataUrl` / logo public) —
            /// ne pas laisser `beginFlyerRecreateSessionForPreview()` bloquer l’injection (sinon `custom_logo` restait « omis »
            /// et le WK / sheet affichaient le mauvais logo — ou pas de logo).
            suppressDashboardCustomLogoForPreview = false
            /// Marquer le chargement **dès** le GET + 1ʳᵉ injection — ne **pas** attendre les GET publics (logo / fond) :
            /// sinon l’écran « Modifier le flyer » reste figé (aperçu vide, formulaire absent) le temps d’un réseau lent
            /// ou d’un timeout long (ordre de la minute), alors que `state` + `serverLogoDataUrl` sont déjà là.
            lastSuccessfulServerLoadAt = Date()
            /// Logo & fond publics en arrière-plan : rafraîchissent le bootstrap quand prêts (sans bloquer `load()`).
            Task { @MainActor in
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await self.prefetchPublicLogoCacheIfNeeded() }
                    group.addTask { await self.hydrateCustomBgFromPublicEndpointIfNeeded() }
                }
                self.refreshPreviewBootstrap()
            }
            if shouldPersistFlyerWheelPngMigration {
                Task { _ = await self.save(logoPickerUIImage: nil) }
            }
        } catch {
            isUndoRedoOrLoad = false
            loadError = Self.humanizedLoadError(error)
        }
    }

    /// GET dashboard : n’écrase pas logo/fond locaux par des champs vides si la réponse omet les data URLs lourdes.
    private static func assignServerVisualsFromFlyerPrefs(
        fp: FlyerPrefsStored,
        forceReplaceWithEmpty: Bool,
        logoDestination: inout String?,
        bgDestination: inout String?
    ) {
        let incomingLogo = fp.customLogoDataUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let incomingBg = fp.customBgDataUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if forceReplaceWithEmpty {
            logoDestination = fp.customLogoDataUrl
            bgDestination = fp.customBgDataUrl
            return
        }
        if !incomingLogo.isEmpty {
            logoDestination = fp.customLogoDataUrl
        } else if let cur = logoDestination?.trimmingCharacters(in: .whitespacesAndNewlines), !cur.isEmpty {
            // conserve
        } else {
            logoDestination = fp.customLogoDataUrl
        }
        if !incomingBg.isEmpty {
            bgDestination = fp.customBgDataUrl
        } else if let cur = bgDestination?.trimmingCharacters(in: .whitespacesAndNewlines), !cur.isEmpty {
            // conserve
        } else {
            bgDestination = fp.customBgDataUrl
        }
    }

    /// Remplit `serverBgDataUrl` depuis `GET …/public/flyer-custom-bg` lorsque le dashboard ne renvoie pas le data URL (évite l’écran « créer le flyer » alors qu’un fond est en ligne).
    private func hydrateCustomBgFromPublicEndpointIfNeeded() async {
        if let s = serverBgDataUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return }
        let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        let baseRoot = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseRoot)/api/businesses/\(enc)/public/flyer-custom-bg") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 22
        let data: Data
        let status: Int
        do {
            let (d, r) = try await URLSession.shared.data(for: req)
            guard let http = r as? HTTPURLResponse else { return }
            data = d
            status = http.statusCode
        } catch {
            return
        }
        guard (200 ... 299).contains(status), !data.isEmpty else { return }
        let dataURLString = await Task.detached(priority: .userInitiated) {
            Self.jpegDataURLFromFlyerBackgroundBytes(data)
        }.value
        guard !dataURLString.isEmpty else { return }
        serverBgDataUrl = dataURLString
    }

    /// Compresse en JPEG pour rester cohérent avec les plafonds `FlyerDashboardFlyerPrefsLimits` si l’utilisateur enregistre à nouveau.
    private nonisolated static func jpegDataURLFromFlyerBackgroundBytes(_ data: Data) -> String {
        let maxUtf8Approx = 5_200_000
        if let ui = UIImage(data: data) {
            var q: CGFloat = 0.86
            for _ in 0 ..< 14 {
                if let j = ui.jpegData(compressionQuality: q) {
                    let candidate = "data:image/jpeg;base64,\(j.base64EncodedString())"
                    if candidate.utf8.count <= maxUtf8Approx { return candidate }
                }
                q -= 0.055
                if q < 0.34 { break }
            }
        }
        if let thumb = ImageIODownsampling.imageFromData(data, maxPixelDimension: 2200),
           let j = thumb.jpegData(compressionQuality: 0.68) {
            let candidate = "data:image/jpeg;base64,\(j.base64EncodedString())"
            if candidate.utf8.count <= maxUtf8Approx { return candidate }
        }
        return "data:image/png;base64,\(data.base64EncodedString())"
    }

    /// Recalcule le data URL du logo **avant** le PUT (PNG transparence si `flyerLogoKeepSourceBackground` = false) pour que
    /// `custom_logo_data_url` parte aligné sur la préférence de détourage.
    func reexportLogoForCurrentKeepPreference(logoPickerUIImage: UIImage?) async {
        let maxLen = FlyerDashboardFlyerPrefsLimits.logoPngMaxEncodedUtf8Bytes
        let baseImage: UIImage?
        if let lp = logoPickerUIImage {
            baseImage = lp
        } else if let url = logoSourceDataURLStringForReexport() {
            baseImage = await Task.detached(priority: .userInitiated) {
                FlyerDataURLImageDecode.uiImage(fromDataURLString: url)
            }.value
        } else {
            baseImage = nil
        }
        guard let raw = baseImage else { return }
        let keep = state.flyerLogoKeepSourceBackground
        let dataUrl = await Task.detached(priority: .userInitiated) {
            raw.flyerLogoExportDataURLReliable(maxUtf8: maxLen, keepSourceBackground: keep)
        }.value
        isUndoRedoOrLoad = true
        applyLogoPayload(.dataURL(dataUrl))
        isUndoRedoOrLoad = false
    }

    /// Même recette que `reexportLogoForCurrentKeepPreference` **sans** muter
    /// `logoPayload` — pour le `POST …/ai-generate` : le logo enregistré sur le profil est aussi transmissible.
    func exportLogoDataURLForAIGenerate(logoPickerUIImage: UIImage?) async -> String? {
        if logoPickerUIImage == nil {
            await prefetchPublicLogoCacheIfNeeded()
        }
        let maxLen = FlyerDashboardFlyerPrefsLimits.logoPngMaxEncodedUtf8Bytes
        let keep = state.flyerLogoKeepSourceBackground
        let baseImage: UIImage?
        if let lp = logoPickerUIImage {
            baseImage = lp
        } else if let url = logoSourceDataURLStringForReexport() {
            baseImage = await Task.detached(priority: .userInitiated) {
                FlyerDataURLImageDecode.uiImage(fromDataURLString: url)
            }.value
        } else {
            baseImage = nil
        }
        guard let raw = baseImage else { return nil }
        return await Task.detached(priority: .userInitiated) {
            raw.flyerLogoExportDataURLReliable(maxUtf8: maxLen, keepSourceBackground: keep)
        }.value
    }

    func save(logoPickerUIImage: UIImage? = nil) async -> Bool {
        await reexportLogoForCurrentKeepPreference(logoPickerUIImage: logoPickerUIImage)
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            isUndoRedoOrLoad = true
            var st = state
            st.normalizeClamps()
            state = st
            isUndoRedoOrLoad = false
            let snapshotLogo = logoPayload
            let snapshotBg = bgPayload
            let payload = FlyerPutPayload(state: st, logo: logoPayload, background: bgPayload)
            let body: Data
            do {
                body = try payload.encodedJSON()
            } catch {
                saveError = "Données flyer invalides. Rouvrez l’éditeur ou réessayez."
                return false
            }
            if body.count > FlyerDashboardFlyerPrefsLimits.serverFlyerPrefsJSONMaxBytes {
                saveError =
                    "Le flyer est trop volumineux pour l’enregistrement (logo + fond). Réduisez le logo ou régénérez le fond IA."
                return false
            }
            let putRes = try await APIClient.shared.request(APIEndpoint.dashboardFlyerPut(slug: slug, payload: payload)) as FlyerPutAPIResponse
            if let u = putRes.updatedAt?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
                serverUpdatedAt = u
            }
            suppressDashboardCustomLogoForPreview = false
            logoPayload = .leaveUnchanged
            bgPayload = .leaveUnchanged
            /// Miroir optimiste : si le GET suivant échoue (réseau), l’UI reflète quand même ce qui vient d’être accepté par le PUT.
            switch snapshotLogo {
            case .dataURL(let s): serverLogoDataUrl = s
            case .clear: serverLogoDataUrl = nil
            case .leaveUnchanged: break
            }
            switch snapshotBg {
            case .dataURL(let s): serverBgDataUrl = s
            case .clear: serverBgDataUrl = nil
            case .leaveUnchanged: break
            }
            recomputeServerSnapshotStateFlag(using: state)
            refreshPreviewBootstrap()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            /// Ne **pas** appeler `load()` ici : le GET immédiat écrasait souvent l’état local (dégradé, teintes)
            /// par une copie serveur légèrement en retard — donnait l’impression que rien ne s’enregistrait.
            lastSuccessfulServerLoadAt = Date()
            undoStack.removeAll()
            redoStack.removeAll()
            objectWillChange.send()
            CommerceFlyerEditorDraftStore.clear(slug: slug)
            return true
        } catch {
            isUndoRedoOrLoad = false
            let detail = (error as? APIError)?.errorDescription ?? error.localizedDescription
            saveError = detail
            return false
        }
    }

    /// Applique le fond généré par l’IA et enregistre sur le serveur.
    func applyAIBackgroundAndSave(dataURL: String) async -> Bool {
        applyBgPayload(.dataURL(dataURL))
        return await save(logoPickerUIImage: nil)
    }
}

// MARK: - Studio « Canva » (plein écran)

private enum FlyerStudioTheme {
    /// Accent type Canva (violet).
    static let accent = Color(red: 0.45, green: 0.32, blue: 0.96)

}

/// Chargement depuis `PhotosPickerItem` : `Data` + **ImageIO** (HEIC multi-plans, grosses photos, EXIF),
/// puis UIKit — évite les échecs silencieux où `UIImage(data:)` seul ne suffit pas.
private enum FlyerPickerUIImageLoader {
    /// Côté long max à la lecture (évite pics mémoire ; l’export logo redimensionne encore).
    private static let decodeMaxPixel: CGFloat = 8192

    static func load(from item: PhotosPickerItem) async -> UIImage? {
        let data: Data?
        do {
            data = try await item.loadTransferable(type: Data.self)
        } catch {
            data = nil
        }
        guard let data, !data.isEmpty else { return nil }
        let ioDecoded = await Task.detached(priority: .userInitiated) {
            ImageIODownsampling.imageFromData(data, maxPixelDimension: Self.decodeMaxPixel)
        }.value
        if let ioDecoded { return ioDecoded }
        if let ui = UIImage(data: data) {
            return await MainActor.run { Self.flattenUIImageOrientation(ui) }
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let thumbOpts: [CFString: Any] = [
            kCGImageSourceShouldAllowFloat: true,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(Self.decodeMaxPixel),
        ]
        if let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOpts as CFDictionary) {
            let scale = await MainActor.run { UIScreen.main.scale }
            return UIImage(cgImage: cg, scale: scale, orientation: .up)
        }
        let fullOpts: [CFString: Any] = [kCGImageSourceShouldAllowFloat: true]
        if let cg = CGImageSourceCreateImageAtIndex(source, 0, fullOpts as CFDictionary) {
            let scale = await MainActor.run { UIScreen.main.scale }
            return UIImage(cgImage: cg, scale: scale, orientation: .up)
        }
        return nil
    }

    /// Même idée que `ImageIODownsampling.displayFlattenIfNeeded` (orientation UIImage → dessin `.up`).
    private static func flattenUIImageOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

// MARK: - Assistant IA — fond de flyer (OpenAI via backend)

/// Palette éditeur IA (réf. type « Create Image ») — fond, surfaces et halo de profondeur.
private enum FlyerAIEditorTheme {
    static let canvas = Color(red: 14 / 255, green: 17 / 255, blue: 19 / 255) // #0e1113
    static let promptSurface = Color(red: 38 / 255, green: 39 / 255, blue: 41 / 255) // #262729
    static let sourceCard = Color(red: 19 / 255, green: 24 / 255, blue: 29 / 255) // #13181d
    /// Halo bleu-gris progressif derrière les blocs (profondeur).
    static let glowDepth = Color(red: 36 / 255, green: 45 / 255, blue: 59 / 255) // #242d3b
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.58)
    static let textTertiary = Color.white.opacity(0.38)
    static let hairline = Color.white.opacity(0.1)
}

/// Teinte « paire » pour la roue et l’API : l’utilisateur ne choisit qu’une couleur d’accent.
private enum FlyerAIWheelPairColor {
    static func evenHex(fromAccentHex raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withHash = t.hasPrefix("#") ? t : "#\(t)"
        let hex6 = String(withHash.dropFirst())
        guard hex6.count == 6,
              let rv = UInt8(hex6.prefix(2), radix: 16),
              let gv = UInt8(hex6.dropFirst(2).prefix(2), radix: 16),
              let bv = UInt8(hex6.suffix(2), radix: 16)
        else {
            return "#FEF3C7"
        }
        func lighten(_ x: UInt8) -> UInt8 {
            UInt8(min(255, Int(x) + Int(Double(255 - Int(x)) * 0.55)))
        }
        return String(format: "#%02X%02X%02X", lighten(rv), lighten(gv), lighten(bv))
    }

    /// Texte pastille CTA / contour « CADEAU » lisible sur fond accent (même logique que le backend `pickContrastingTextOnHexBg`).
    static func contrastingOnAccentHex(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withHash = t.hasPrefix("#") ? t : "#\(t)"
        let hex6 = String(withHash.dropFirst())
        guard hex6.count == 6,
              let rv = UInt8(hex6.prefix(2), radix: 16),
              let gv = UInt8(hex6.dropFirst(2).prefix(2), radix: 16),
              let bv = UInt8(hex6.suffix(2), radix: 16)
        else {
            return "#ffffff"
        }
        let r = Double(rv) / 255.0
        let g = Double(gv) / 255.0
        let b = Double(bv) / 255.0
        func lin(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        return luminance > 0.55 ? "#0f172a" : "#ffffff"
    }
}

// MARK: - Logo (PhotosPicker)

private enum FlyerAISourcePickerJPEG {
    static let quality: CGFloat = 0.92
}

private struct FlyerAISourceThumbImage: View {
    let ui: UIImage
    var extraCountBadge: Int = 0

    private static let thumbHeight: CGFloat = 92

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: Self.thumbHeight)
            .overlay {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if extraCountBadge > 0 {
                    Text("+\(extraCountBadge)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(FlyerAIEditorTheme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(FlyerAIEditorTheme.promptSurface.opacity(0.92), in: Capsule())
                        .overlay(Capsule().strokeBorder(FlyerAIEditorTheme.hairline, lineWidth: 1))
                        .padding(6)
                }
            }
    }
}

private struct FlyerAISourceThumbEmpty: View {
    let systemImage: String
    let label: String

    private static let thumbHeight: CGFloat = 92

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(FlyerAIEditorTheme.canvas)
            .frame(maxWidth: .infinity)
            .frame(height: Self.thumbHeight)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(FlyerAIEditorTheme.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
            .overlay {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                    Text(label)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(FlyerAIEditorTheme.textSecondary)
            }
    }
}

private struct FlyerAISourcePickerCard<Content: View>: View {
    let title: String
    let symbol: String
    let isActive: Bool
    @ViewBuilder var preview: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isActive ? FlyerStudioTheme.accent : FlyerAIEditorTheme.textSecondary)
                Text(title)
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(FlyerAIEditorTheme.textPrimary)
                Spacer(minLength: 0)
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(FlyerStudioTheme.accent.opacity(0.95))
                }
            }
            preview()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(FlyerAIEditorTheme.sourceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isActive ? FlyerStudioTheme.accent.opacity(0.45) : FlyerAIEditorTheme.hairline,
                    lineWidth: isActive ? 1.25 : 1
                )
        )
        .overlay(
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.white.opacity(0.06), Color.white.opacity(0.02), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 5)
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .allowsHitTesting(false)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 16, y: 8)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isActive)
    }
}

private struct FlyerAILogoPhotosPickerSlot: View {
    @Binding var selection: PhotosPickerItem?
    var logoJPEG: Data?

    var body: some View {
        let isActive = logoJPEG != nil
        PhotosPicker(selection: $selection, matching: .images) {
            FlyerAISourcePickerCard(
                title: "Logo",
                symbol: "building.2.crop.circle",
                isActive: isActive,
                preview: {
                    if let logoJPEG, let ui = UIImage(data: logoJPEG) {
                        FlyerAISourceThumbImage(ui: ui, extraCountBadge: 0)
                    } else {
                        FlyerAISourceThumbEmpty(
                            systemImage: "photo.badge.plus",
                            label: "Importer le logo"
                        )
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

/// Masque la tab bar sur l’écran de création / édition flyer (navigation par le chevron retour).
private struct MerchantFlyerTabBarForCreationVisibility: ViewModifier {
    let isTabRoot: Bool

    func body(content: Content) -> some View {
        if isTabRoot {
            content.toolbar(.hidden, for: .tabBar)
        } else {
            content
        }
    }
}

/// Panneaux de l’éditeur inline « Modifier le flyer » (accordéon : un seul ouvert).
private enum FlyerMerchantEditPanel: Equatable {
    case titre, roue, fond
}

/// Section dépliable pour l’édition flyer (Commerce) — en-tête tap + chevron, contenu animé.
private struct FlyerMerchantEditDisclosureSection<Content: View>: View {
    let title: String
    let systemImage: String
    @Binding var isExpanded: Bool
    private let inner: Content

    init(title: String, systemImage: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        _isExpanded = isExpanded
        inner = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FlyerStudioTheme.accent)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(FlyerStudioTheme.accent.opacity(0.14))
                        )
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FlyerAIEditorTheme.textPrimary)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(FlyerAIEditorTheme.textSecondary.opacity(0.9))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: isExpanded)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(title), \(isExpanded ? "développé" : "replié")")

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    inner
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FlyerAIEditorTheme.sourceCard.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(FlyerAIEditorTheme.hairline.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

@MainActor
private struct FlyerAIGeneratorSheet: View {
    let slug: String
    let palette: DashboardRevolutPalette
    let initialPrimaryHex: String
    @ObservedObject var flyerModel: ProgramFlyerEditorModel
    /// Onglet Flyer : pas de bouton fermer, validation ne dismiss pas — lien partage.
    var isTabRoot: Bool = false
    /// Ouverture depuis Commerce « Régénérer » : après chargement, basculer sur formulaire vierge (sans alerte ici, déjà confirmé côté Commerce).
    var seedRecreateFlyerSession: Bool = false
    /// Depuis l’aperçu « Votre flyer » → **Modifier** : afficher tout de suite l’éditeur (héros + titre « Modifier le flyer »).
    var seedOpenFlyerForEdit: Bool = false
    /// Route `flyerFromEditBack` (retour « Modifier » → UI **Créer**).
    var startInCreateFromEditBack: Bool = false
    /// Si non nil : après sauvegarde réussie du flyer IA, fermer le hub et afficher la checklist Commerce (évite le mode compact sur fond noir).
    var onFlyerSaveSuccessReturnToCommerce: (() -> Void)? = nil
    /// Commerce (pas onglet) : retour depuis **Modifier** → remplacer la route par l’écran **Créer le flyer**.
    var onBackFromModifyToCreateFlyer: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var syncService: SyncService

    @State private var brandName = ""
    /// Couleurs d’accent (roue, CTA) — création manuelle, sans génération IA.
    @State private var flyerPalettePriorityHexes: [String] = ["#FF6B9D"]
    /// Mise à jour programmée (init, prefill, extraction logo) — ne pas marquer la couleur comme personnalisée.
    @State private var isUpdatingAccentFromEngine = false
    /// Dès que l’utilisateur touche la teinte (pastille ou fiche précision), on ne re-suggère plus depuis les images.
    @State private var flyerAccentUserCustomized = false
    @State private var logoPickerItem: PhotosPickerItem?
    @State private var flyerLogoCropPayload: ImageCropPayload?
    @State private var flyerBgCropPayload: ImageCropPayload?
    @State private var flyerBgPickerItem: PhotosPickerItem?
    @State private var logoPreview: UIImage?
    /// Data URL légère (synchrone) juste après recadrage : l’aperçu héros a le logo pendant l’export « full » asynchrone.
    @State private var flyerLogoQuickExportDataUrl: String?
    @State private var errorMessage: String?
    @State private var generatedBase64: String?
    @State private var didApplyInitialColors = false
    @State private var isSavingKeep = false
    @State private var didPrefillCommerce = false
    /// Grand aperçu : visible après « Voir l’aperçu » (ou dès qu’un rendu / bootstrap est disponible).
    @State private var flyerHeroRevealed = false
    @State private var heroCompositePreviewLoading = false
    @State private var flyerInteractiveWebLoading = false
    /// Échec de chargement de `flyer-embed` (WKWebView) — message d’aide sous l’aperçu.
    @State private var flyerEmbedNavigationFailed = false
    @State private var flyerValidatedOnTab = false
    /// L'utilisateur a ouvert « Modifier » / « Continuer avec l'IA » depuis le mode compact : afficher l'éditeur complet même si un fond est déjà en base.
    @State private var flyerExpandedEditorFromValidated = false
    /// Après « Régénérer » : ne pas rouvrir automatiquement l’aperçu héros tant que l’utilisateur n’a pas relancé une génération.
    @State private var flyerCreationFreshStart = false
    @State private var didApplyRecreateSeed = false
    /// Accordéon édition « Modifier le flyer » : une section à la fois (ordre Titre → Roue → Fond) — replié par défaut.
    @State private var flyerMerchantEditExpanded: FlyerMerchantEditPanel? = nil
    @State private var commerceRecreateBlockedMessage: String?
    @State private var showRegenerateFlyerConfirm = false
    @Namespace private var flyerValidateMorph
    @State private var isSavingFlyerEdits = false
    /// Si vrai, `syncFlyerHeroRevealedForPersistedServerFlyer` ne force pas l’aperçu complet (titre **Créer** visible).
    @State private var suppressAutoHeroRevealedForCreateFlow = false
    /// Illustration montrée avant le reset « Recréer » (1ʳᵉ génération) — comparer avec le nouveau rendu.
    @State private var recreateStashAIBgBase64: String?
    /// `false` = dernière image générée ; `true` = version conservée d’avant le « Recréer ».
    @State private var showRecreateStashedVersion = false

    /// Calque IA affiché (aperçu, enregistrement) : soit la dernière génération, soit la version conservée.
    private var displayedAIBgBase64: String? {
        if showRecreateStashedVersion, let s = recreateStashAIBgBase64, !s.isEmpty { return s }
        return generatedBase64
    }

    private var canCompareRecreateIllustrationVersions: Bool {
        (recreateStashAIBgBase64?.isEmpty == false) && (generatedBase64?.isEmpty == false)
    }

    private func base64ForStashingBeforeRecreate() -> String? {
        if let d = displayedAIBgBase64, !d.isEmpty { return d }
        let s = flyerModel.serverBgDataUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard s.hasPrefix("data:image/"), let comma = s.firstIndex(of: ",") else { return nil }
        let b64 = String(s[s.index(after: comma)...])
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        return b64.isEmpty ? nil : b64
    }

    /// Créations illimitées selon la réponse API (`flyer_ai_unlimited`).
    private var flyerUnlimitedEffective: Bool {
        flyerModel.flyerAiUnlimited
    }

    /// Fond personnalisé déjà persisté côté API (GET dashboard flyer) — survit au redémarrage de l’app.
    private var hasPersistedFlyerBackgroundOnServer: Bool {
        guard let s = flyerModel.serverBgDataUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return false
        }
        return true
    }

    /// Formulaire + barre d’action : après un premier `GET …/dashboard/flyer` réussi (évite un formulaire vide sans explication).
    private var flyerShowMainComposer: Bool {
        flyerModel.hasCompletedSuccessfulFlyerLoad
    }

    @ViewBuilder
    private func flyerLoadErrorPanel(message: String, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: compact ? 20 : 26, weight: .semibold))
                    .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.12))
                Text(message)
                    .font(compact ? .caption.weight(.medium) : .subheadline.weight(.medium))
                    .foregroundStyle(FlyerAIEditorTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !compact {
                Text("Vérifiez la connexion ou réessayez après la synchronisation du tableau de bord.")
                    .font(.caption)
                    .foregroundStyle(FlyerAIEditorTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button {
                    Task { await flyerModel.load(showProgress: true, forceFullFlyerPrefsMerge: true) }
                } label: {
                    Text("Réessayer")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 10 : 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(FlyerStudioTheme.accent)
                .disabled(flyerModel.isLoading)

                Button {
                    Task {
                        await syncService.syncAfterServerMutation()
                        await flyerModel.load(showProgress: true, forceFullFlyerPrefsMerge: true)
                    }
                } label: {
                    Text("Synchroniser")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 10 : 14)
                }
                .buttonStyle(.bordered)
                .tint(FlyerAIEditorTheme.textSecondary)
                .disabled(flyerModel.isLoading)
            }
        }
        .padding(compact ? 12 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                .fill(FlyerAIEditorTheme.promptSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                .strokeBorder(FlyerAIEditorTheme.hairline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var flyerDashboardFetchChrome: some View {
        if !flyerModel.hasCompletedSuccessfulFlyerLoad {
            if let err = flyerModel.loadError?.trimmingCharacters(in: .whitespacesAndNewlines), !err.isEmpty {
                flyerLoadErrorPanel(message: err, compact: false)
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                        .tint(FlyerStudioTheme.accent)
                        .scaleEffect(1.05)
                    Text(flyerModel.isLoading ? "Chargement des données flyer…" : "Préparation…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(FlyerAIEditorTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        } else if let err = flyerModel.loadError?.trimmingCharacters(in: .whitespacesAndNewlines), !err.isEmpty {
            flyerLoadErrorPanel(message: err, compact: true)
        }
    }

    /// Aperçu héros post-IA : même canvas que l’éditeur (`flyer-embed`) avec le PNG IA en calque **natif** (pas dans le JSON).
    /// Aussi sans fond : dès qu’un **logo** est importé, le composite s’affiche (avant, seul un fond/IA activait l’aperçu — le logo
    /// et le dégradé ne passaient pas en carte héros).
    private var flyerHeroCompositeBootstrap: String? {
        let hasSessionAI = (displayedAIBgBase64.map { !$0.isEmpty } ?? false)
        let hasUnderlayInPrefs: Bool = {
            let s = flyerModel.flyerCustomBgDataURLForNativeUnderlay?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return !s.isEmpty
        }()
        let hasUserLogoOrExplicitPayload: Bool = {
            if logoPreview != nil { return true }
            switch flyerModel.logoPayload {
            case .dataURL, .clear: return true
            case .leaveUnchanged: return false
            }
        }()
        let needsHeroWebComposite = hasSessionAI || hasUnderlayInPrefs || hasUserLogoOrExplicitPayload
        guard needsHeroWebComposite else { return nil }

        let maxL = FlyerDashboardFlyerPrefsLimits.logoPngMaxEncodedUtf8Bytes
        let provisionalLogo: String? = {
            if let q = flyerLogoQuickExportDataUrl, !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return q }
            switch flyerModel.logoPayload {
            case .dataURL(let s):
                if !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return s }
                return nil
            case .clear:
                return ""
            case .leaveUnchanged:
                return nil
            }
        }()
        return flyerModel.encodedPreviewBootstrapBase64(
            provisionalCustomBgDataURL: nil,
            provisionalCustomLogoDataURL: provisionalLogo,
            embedCustomBackgroundInJson: false
        ) ?? flyerModel.bootstrapPreviewBase64
    }

    /// Aperçu interactif : fond IA non validé si présent, sinon prefs serveur.
    /// Priorité au `bootstrap` du modèle (mis à jour par `refreshPreviewBootstrap` uniquement quand l’état change) :
    /// le composite héros recodait le JSON à chaque re-render (clic / focus) — chaîne perçue comme nouvelle par la WK → réinjection
    /// permanente et flash noir.
    private var effectiveFlyerPreviewBootstrap: String? {
        if let s = flyerModel.bootstrapPreviewBase64, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return s }
        return flyerHeroCompositeBootstrap
    }

    /// Après cold start / GET flyer : montrer le bloc aperçu (roue + QR) même sans `generatedBase64` en mémoire.
    private func syncFlyerHeroRevealedForPersistedServerFlyer() {
        if suppressAutoHeroRevealedForCreateFlow { return }
        if flyerCreationFreshStart { return }
        if displayedAIBgBase64 != nil {
            flyerHeroRevealed = true
            return
        }
        let hasBootstrap = !(flyerModel.bootstrapPreviewBase64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
        guard hasBootstrap, flyerModel.hasCompletedSuccessfulFlyerLoad else { return }
        /// Fond / logo / texte **synchronisés** avec l’API ou le cache (pas seulement des retouches locales avant 1ʳᵉ génération).
        if flyerModel.hasPersistedServerContextForFlyerHero {
            flyerHeroRevealed = true
        }
    }

    private var bottomScrollPadding: CGFloat {
        /// Barre d’action basse absente en mode édition texte/couleurs (Sauvegarder en haut à droite).
        if showBottomFlyerActionBar { return flyerHeroRevealed ? 120 : 140 }
        return 40
    }

    /// « Sauvegarder » texte/couleurs : uniquement le bouton haut (pas de double barre de progression en bas).
    private var showBottomFlyerActionBar: Bool {
        if isSavingFlyerEdits { return false }
        if isSavingKeep { return true }
        if let b = displayedAIBgBase64, !b.isEmpty, !flyerValidatedOnTab { return true }
        if !flyerHeroRevealed { return true }
        return false
    }

    /// Éditeur texte & couleurs (aperçu déjà validé) : bouton en haut à droite, pas d’enregistrement d’illustration IA en attente.
    private var showTopBarFlyerSave: Bool {
        guard flyerHeroRevealed else { return false }
        if isSavingKeep { return false }
        if let b = displayedAIBgBase64, !b.isEmpty, !flyerValidatedOnTab { return false }
        return true
    }

    private func performSaveFlyerEdits() {
        Task { @MainActor in
            isSavingFlyerEdits = true
            flyerModel.saveError = nil
            let ok = await flyerModel.save(logoPickerUIImage: logoPreview)
            isSavingFlyerEdits = false
            guard ok else { return }
            /// Retour Commerce (depuis l’onglet) : `onFlyerSaveSuccessReturnToCommerce` + animation dans `ProfileView`.
            if isTabRoot, let pop = onFlyerSaveSuccessReturnToCommerce {
                Task(priority: .utility) { await syncService.syncAfterServerMutation() }
                pop()
            }
        }
    }

    /// Retour : quitter l’écran, ou quitter l’écran d’**édition** vers l’assistant **Créer le flyer** (onglet / Commerce).
    private func performFlyerBackNavigation() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if flyerHeroRevealed {
            if isTabRoot {
                suppressAutoHeroRevealedForCreateFlow = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    flyerHeroRevealed = false
                }
            } else if let goToCreate = onBackFromModifyToCreateFlyer {
                goToCreate()
            } else {
                dismiss()
            }
        } else {
            dismiss()
        }
    }

    /// Découpé du `body` pour accélérer l’inférence de types du compilateur.
    private var flyerAIGeneratorScrollAndChrome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                /// Titre + retour + Sauvegarder (mode édition aperçu).
                ZStack {
                    Text(flyerHeroRevealed ? "Modifier le flyer" : "Créer un flyer")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FlyerAIEditorTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack(spacing: 0) {
                        Button {
                            performFlyerBackNavigation()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(FlyerAIEditorTheme.textPrimary)
                                .frame(width: 34, height: 34)
                        }
                        .modifier(TopBarLiquidGlassButtonModifier())
                        .accessibilityLabel("Retour")

                        Spacer(minLength: 0)

                        if showTopBarFlyerSave {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                performSaveFlyerEdits()
                            } label: {
                                Group {
                                    if isSavingFlyerEdits, flyerModel.isSaving {
                                        ProgressView()
                                            .tint(FlyerAIEditorTheme.textPrimary)
                                            .frame(width: 40, height: 40)
                                    } else {
                                        Text("Sauvegarder")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(FlyerAIEditorTheme.textPrimary)
                                            .padding(.horizontal, 12)
                                            .frame(minWidth: 40, minHeight: 40)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Sauvegarder le flyer")
                            .glassStyleDark(cornerRadius: 20)
                            .disabled(!flyerModel.canUndo || flyerModel.isLoading || (isSavingFlyerEdits && flyerModel.isSaving))
                            .opacity(
                                flyerModel.canUndo && !flyerModel.isLoading ? 1 : (isSavingFlyerEdits ? 0.55 : 0.4)
                            )
                        } else {
                            Color.clear
                                .frame(width: 40, height: 40)
                        }
                    }
                }
                .padding(.top, 4)

                flyerDashboardFetchChrome

                if let m = commerceRecreateBlockedMessage, !m.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color(red: 0.4, green: 0.75, blue: 1))
                        Text(m)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(FlyerAIEditorTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(FlyerAIEditorTheme.sourceCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(FlyerAIEditorTheme.hairline.opacity(0.6), lineWidth: 1)
                    )
                }

                if flyerShowMainComposer {
                    fieldsBlock
                        .transition(
                            .asymmetric(
                                insertion: .opacity,
                                removal: .move(edge: .bottom)
                                    .combined(with: .opacity)
                                    .combined(with: .scale(scale: 0.97, anchor: .bottom))
                            )
                        )
                }
                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if flyerEmbedNavigationFailed, flyerShowMainComposer {
                    Text(
                        "L’aperçu du flyer n’a pas pu se charger. Vérifiez la connexion, puis tirez vers le bas pour actualiser."
                    )
                    .font(.caption)
                    .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.22))
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .padding(.top, 8)
            .padding(.bottom, bottomScrollPadding)
        }
        .scrollIndicators(.hidden)
        .background {
            FlyerAIEditorTheme.canvas
                .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            if flyerShowMainComposer, showBottomFlyerActionBar {
                stickyGenerateBar
            }
        }
    }

    var body: some View {
        flyerAIGeneratorScrollAndChrome
        .alert("Repartir sur une nouvelle base ?", isPresented: $showRegenerateFlyerConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Continuer") {
                Task { await performFlyerRegenerationFromValidated() }
            }
        } message: {
            Text(
                "Le flyer enregistré côté clients ne change qu’après vos sauvegardes. Vous pourrez ajuster logo, couleurs et textes avant d’enregistrer un nouveau visuel."
            )
        }
        .onAppear {
            if !seedRecreateFlyerSession {
                flyerModel.clearRecreateSessionSuppressionForEditEntry()
                Task { await flyerModel.prefetchPublicLogoCacheIfNeeded() }
            }
            // Restore pending AI background from disk (survives force-quit before server save).
            if generatedBase64 == nil, let saved = FlyerPendingBgStorage.shared.loadBase64(slug: slug) {
                generatedBase64 = saved
            }
            if recreateStashAIBgBase64 == nil, let b = FlyerRecreatePreviousBackupStorage.shared.loadBase64(slug: slug) {
                recreateStashAIBgBase64 = b
            }
            guard !didApplyInitialColors else { return }
            didApplyInitialColors = true
            /// `setFlyerPaletteProgrammatically` applique le **thème complet** ; les pastilles « Roue » en édition n’appliquent que les secteurs.
            /// d’après **une** teinte. À l’ouverture « Modifier le flyer » (ou dès qu’un chargement a réussi), l’état
            /// `flyerModel.state` vient du serveur / cache : ne pas l’écraser — sinon l’aperçu WebView « perd » les couleurs
            /// et le rendu (logo, bandeau, roue) semble « vidé » ou uniforme.
            let skipStompFromParentAccent = flyerModel.hasCompletedSuccessfulFlyerLoad
                || (seedOpenFlyerForEdit && !seedRecreateFlyerSession)
            if skipStompFromParentAccent {
                isUpdatingAccentFromEngine = true
                let odd = Self.normalizeHex(flyerModel.state.wheelColorOdd)
                    ?? Self.normalizeHex(flyerModel.state.colorPrimary)
                    ?? "#f97316"
                let even = Self.normalizeHex(flyerModel.state.wheelColorEven)
                    ?? Self.normalizeHex(FlyerAIWheelPairColor.evenHex(fromAccentHex: odd))
                    ?? "#FEF3C7"
                flyerPalettePriorityHexes = [odd, even]
                DispatchQueue.main.async { isUpdatingAccentFromEngine = false }
            } else {
                setFlyerPaletteProgrammatically([Self.normalizeHex(initialPrimaryHex) ?? "#f97316"])
            }
            if generatedBase64 != nil {
                flyerHeroRevealed = true
            }
            if seedOpenFlyerForEdit, !seedRecreateFlyerSession {
                /// Intent explicite « Modifier » (aperçu Commerce) : ne jamais retomber sur l’écran « Créer un flyer »
                /// à cause d’un `custom_bg` absent du 1er GET ou d’une course avec le fetch public.
                flyerCreationFreshStart = false
                flyerHeroRevealed = true
            }
            syncFlyerHeroRevealedForPersistedServerFlyer()
            if startInCreateFromEditBack {
                /// Route `flyerFromEditBack` : titre **Créer le flyer** et assistant, sans rouvrir tout de suite l’éditeur.
                suppressAutoHeroRevealedForCreateFlow = true
                flyerCreationFreshStart = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                    flyerHeroRevealed = false
                }
            }
        }
        .onReceive(flyerModel.objectWillChange.receive(on: RunLoop.main)) { _ in
            syncFlyerHeroRevealedForPersistedServerFlyer()
        }
        .onChange(of: flyerPalettePriorityHexes) { _, new in
            guard !isUpdatingAccentFromEngine else { return }
            flyerAccentUserCustomized = true
            let n = new.compactMap { Self.normalizeHex($0) }
            applyWheelSectorColorsToFlyerModel(ordered: Array(n.prefix(2)))
        }
        .onChange(of: logoPickerItem) { _, new in
            Task { @MainActor in
                await handleFlyerLogoPick(new)
            }
        }
        .onChange(of: flyerBgPickerItem) { _, new in
            Task { @MainActor in
                await handleFlyerCustomBgImagePick(new)
            }
        }
        .task {
            await prefillCommerceFieldsIfNeeded()
            if !seedRecreateFlyerSession {
                await retryPendingValidateIfNeeded()
            }
            if seedRecreateFlyerSession {
                /// Le parent lance `load()` en parallèle : attendre la fin du GET avant d’ignorer l’ancien logo persistant (sinon course).
                var spins = 0
                while flyerModel.isLoading, spins < 400 {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    spins += 1
                }
                if !flyerModel.hasCompletedSuccessfulFlyerLoad {
                    await flyerModel.load(showProgress: true, forceFullFlyerPrefsMerge: true)
                }
            }
            if seedRecreateFlyerSession, !didApplyRecreateSeed {
                didApplyRecreateSeed = true
                if FlyerCommerceRecreateOnceGuard.hasConsumedRegenerateSession(slug: slug) {
                    await MainActor.run {
                        commerceRecreateBlockedMessage =
                            "Tu as déjà utilisé la recréation depuis l’aperçu. Utilise l’onglet Flyer pour continuer à personnaliser ton flyer."
                        syncFlyerHeroRevealedForPersistedServerFlyer()
                    }
                } else {
                    await performFlyerRegenerationFromValidated()
                }
            }
        }
        .modifier(MerchantFlyerTabBarForCreationVisibility(isTabRoot: isTabRoot))
        .onChange(of: flyerModel.bootstrapPreviewBase64) { _, _ in
            flyerEmbedNavigationFailed = false
        }
        .onChange(of: generatedBase64) { _, _ in
            flyerEmbedNavigationFailed = false
        }
        .onChange(of: logoPreview) { _, new in
            if new == nil { flyerLogoQuickExportDataUrl = nil }
        }
        .onChange(of: flyerModel.state.flyerLogoKeepSourceBackground) { _, _ in
            Task {
                await flyerModel.reexportLogoForCurrentKeepPreference(logoPickerUIImage: logoPreview)
                await MainActor.run {
                    if !flyerAccentUserCustomized { applyFlyerAccentFromImportedImagesIfAllowed() }
                }
            }
        }
        .onChange(of: showRecreateStashedVersion) { _, _ in
            if let d = displayedAIBgBase64 {
                FlyerPendingBgStorage.shared.save(pngBase64: d, slug: slug)
            }
            flyerEmbedNavigationFailed = false
        }
        .fullScreenCover(item: $flyerLogoCropPayload) { payload in
            ImageCropEditorView(
                spec: payload.spec,
                sourceImage: payload.image,
                onCancel: { flyerLogoCropPayload = nil },
                onComplete: { cropped in
                    flyerLogoCropPayload = nil
                    applyFlyerLogoAfterCrop(cropped)
                }
            )
        }
        .fullScreenCover(item: $flyerBgCropPayload) { payload in
            ImageCropEditorView(
                spec: payload.spec,
                sourceImage: payload.image,
                onCancel: { flyerBgCropPayload = nil },
                onComplete: { cropped in
                    flyerBgCropPayload = nil
                    applyFlyerBgAfterCrop(cropped)
                }
            )
        }
    }

    /// Ne pas vider `logoPreview` quand `logoPickerItem` repasse à `nil` : après un import réussi on remettait
    /// `logoPickerItem = nil`, ce qui relançait `onChange` et effaçait l’aperçu immédiatement.
    @MainActor
    private func handleFlyerLogoPick(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        let ui = await FlyerPickerUIImageLoader.load(from: item)
        guard let ui else {
            errorMessage =
                "Impossible de lire cette photo (format ou iCloud). Ouvrez l’image dans Réglages → Photos, ou exportez-la en JPEG puis réessayez."
            logoPreview = nil
            logoPickerItem = nil
            return
        }
        flyerLogoCropPayload = ImageCropPayload(image: ui, spec: .flyerPromoLogo)
        logoPickerItem = nil
    }

    /// Après validation de la page de cadrage (même flux que carte / notifications).
    private func applyFlyerLogoAfterCrop(_ cropped: UIImage) {
        logoPreview = cropped
        let maxLen = FlyerDashboardFlyerPrefsLimits.logoPngMaxEncodedUtf8Bytes
        let quickCap = min(maxLen, 200_000)
        let keep = flyerModel.state.flyerLogoKeepSourceBackground
        flyerLogoQuickExportDataUrl = cropped.flyerLogoExportDataURLReliable(maxUtf8: quickCap, keepSourceBackground: keep)
        Task { @MainActor in
            let dataUrl = await Task.detached(priority: .userInitiated) {
                cropped.flyerLogoExportDataURLReliable(maxUtf8: maxLen, keepSourceBackground: keep)
            }.value
            /// D’abord le logo : `applyState` (couleurs) doit fusionner le bootstrap **avec** le nouveau data URL, pas l’ancien.
            flyerModel.applyLogoPayload(.dataURL(dataUrl))
            applyFlyerAccentFromImportedImagesIfAllowed()
            flyerLogoQuickExportDataUrl = nil
            errorMessage = nil
        }
    }

    @MainActor
    private func handleFlyerCustomBgImagePick(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        let ui = await FlyerPickerUIImageLoader.load(from: item)
        guard let ui else {
            errorMessage =
                "Impossible de lire cette image de fond. Réessayez ou choisissez un autre fichier (JPEG/PNG)."
            flyerBgPickerItem = nil
            return
        }
        flyerBgCropPayload = ImageCropPayload(image: ui, spec: .flyerCustomBackground)
        flyerBgPickerItem = nil
    }

    /// Après cadrage plein format (ratio canevas flyer 2:3), compression sous plafond `custom_bg_data_url`.
    private func applyFlyerBgAfterCrop(_ cropped: UIImage) {
        let maxB = FlyerDashboardFlyerPrefsLimits.maxBgDataURLUtf8Bytes
        Task { @MainActor in
            let dataUrl = await Task.detached(priority: .userInitiated) {
                cropped.flyerCustomBgExportDataURLReliable(maxUtf8: maxB)
            }.value
            flyerModel.applyBgPayload(.dataURL(dataUrl))
            errorMessage = nil
        }
    }

    private func collectFlyerImageDistinctHex6List() -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        func appendFrom(_ image: UIImage) {
            for raw in LogoColorExtractor.dominantColors(from: image, maxColors: 4) {
                let n = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "#", with: "")
                    .uppercased()
                guard n.count == 6, n.allSatisfy(\.isHexDigit) else { continue }
                if seen.contains(n) { continue }
                seen.insert(n)
                ordered.append(n)
            }
        }
        if let forExtract = imageForFlyerLogoColorExtraction() { appendFrom(forExtract) }
        return ordered
    }

    /// Logo **détouré** (si possible) pour ne pas proposer le blanc du fond comme « teinte de marque ».
    private func imageForFlyerLogoColorExtraction() -> UIImage? {
        guard let logo = logoPreview else { return nil }
        if flyerModel.state.flyerLogoKeepSourceBackground { return logo }
        return FlyerLogoBackgroundPrepared.imageForFlyerLogoExport(logo, keepSourceBackground: false)
    }

    private func setFlyerPaletteProgrammatically(_ hexes: [String]) {
        let normalized = hexes.compactMap { Self.normalizeHex($0) }
        guard !normalized.isEmpty else { return }
        let capped = Array(normalized.prefix(2))
        isUpdatingAccentFromEngine = true
        defer {
            DispatchQueue.main.async {
                isUpdatingAccentFromEngine = false
            }
        }
        flyerPalettePriorityHexes = capped
        applyFullFlyerAccentFromWheelPalette(ordered: capped)
    }

    /// Pastilles « Roue » : **uniquement** les couleurs des secteurs + `colorPrimary` / `colorSecondary` (pas de réécriture
    /// du dégradé, bandeau ou titres — évite conflits avec les sections Fond / Bandeau et l’impression de flyer « vidé »).
    private func applyWheelSectorColorsToFlyerModel(ordered: [String]) {
        guard let accent = ordered.first.flatMap({ Self.normalizeHex($0) }) else { return }
        let sec: String
        if ordered.count >= 2, let s = Self.normalizeHex(ordered[1]) {
            sec = s
        } else {
            sec = Self.normalizeHex(FlyerAIWheelPairColor.evenHex(fromAccentHex: accent)) ?? "#FEF3C7"
        }
        var st = flyerModel.state
        st.wheelColorOdd = accent
        st.wheelColorEven = sec
        st.colorPrimary = accent
        st.colorSecondary = sec
        flyerModel.applyState(st, recordUndo: false)
    }

    /// Thème complet dérivé des teintes roue (CTA, dégradé, etc.) — init automatique, logo, ou « Voir l’aperçu ».
    private func applyFullFlyerAccentFromWheelPalette(ordered: [String]) {
        guard let accent = ordered.first.flatMap({ Self.normalizeHex($0) }) else { return }
        let sec: String
        if ordered.count >= 2, let s = Self.normalizeHex(ordered[1]) {
            sec = s
        } else {
            sec = Self.normalizeHex(FlyerAIWheelPairColor.evenHex(fromAccentHex: accent)) ?? "#FEF3C7"
        }
        var st = flyerModel.state
        st.wheelColorOdd = accent
        st.wheelColorEven = sec
        st.colorPrimary = accent
        st.colorSecondary = sec
        st.ctaBannerBgColor = accent
        st.ctaTextColor = FlyerAIWheelPairColor.contrastingOnAccentHex(accent)
        st.headlineGiftStrokeColor = FlyerAIWheelPairColor.contrastingOnAccentHex(accent)
        if let top = Self.flyerGradientBgTopHex(fromAccentHex: accent) {
            st.colorBgTop = top
        }
        if let bottom = Self.flyerGradientBgBottomHex(fromSecondaryHex: sec) {
            st.colorBgBottom = bottom
        }
        flyerModel.applyState(st, recordUndo: false)
    }

    private func applyFlyerAccentFromImportedImagesIfAllowed() {
        guard displayedAIBgBase64 == nil else { return }
        guard !flyerAccentUserCustomized else { return }
        guard logoPreview != nil else { return }
        let list = collectFlyerImageDistinctHex6List()
        guard !list.isEmpty else { return }
        let withHash = list.prefix(2).map { "#\($0)" }
        setFlyerPaletteProgrammatically(withHash)
    }

    private var fieldsBlock: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            FlyerAIEditorTheme.glowDepth.opacity(0.65),
                            FlyerAIEditorTheme.glowDepth.opacity(0.28),
                            FlyerAIEditorTheme.canvas.opacity(0)
                        ],
                        center: UnitPoint(x: 0.5, y: 0.08),
                        startRadius: 0,
                        endRadius: 340
                    )
                )
                .blur(radius: 24)
                .padding(.horizontal, -20)
                .padding(.bottom, -20)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 14) {
                if flyerHeroRevealed {
                    flyerPostGenerationPreviewBlock
                    if canCompareRecreateIllustrationVersions {
                        recreateVersionChoiceRow
                    }
                    if flyerModel.hasCompletedSuccessfulFlyerLoad {
                        flyerInlineModificationForm
                    }
                }
                if !flyerHeroRevealed {
                    aiSourceRow
                        .transition(
                            .asymmetric(
                                insertion: .opacity,
                                removal: .move(edge: .top)
                                    .combined(with: .opacity)
                                    .combined(with: .scale(scale: 0.96, anchor: .top))
                            )
                        )
                }
                aiPromptComposerCard
            }
            .animation(.spring(response: 0.52, dampingFraction: 0.86), value: flyerHeroRevealed)
        }
    }

    private var recreateVersionChoiceRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Version", selection: $showRecreateStashedVersion) {
                Text("Nouveau rendu").tag(false)
                Text("Avant de recréer").tag(true)
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FlyerAIEditorTheme.sourceCard.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(FlyerAIEditorTheme.hairline.opacity(0.45), lineWidth: 1)
        )
    }

    // MARK: - Édition inline (même page que l’aperçu — pas de sheet)

    private func flyerMerchantEditExpandedBinding(_ panel: FlyerMerchantEditPanel) -> Binding<Bool> {
        Binding(
            get: { flyerMerchantEditExpanded == panel },
            set: { isOn in
                if isOn {
                    flyerMerchantEditExpanded = panel
                } else if flyerMerchantEditExpanded == panel {
                    flyerMerchantEditExpanded = nil
                }
            }
        )
    }

    private var hasFlyerLogoForBackgroundToggle: Bool {
        if logoPreview != nil { return true }
        if case .dataURL(let s) = flyerModel.logoPayload, !s.isEmpty { return true }
        let s = flyerModel.serverLogoDataUrl?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !s.isEmpty
    }

    private func flyerCadeauPillAndGiftStrokeColorBinding() -> Binding<String> {
        Binding(
            get: { flyerModel.state.ctaBannerBgColor },
            set: { new in
                var s = flyerModel.state
                s.ctaBannerBgColor = new
                let contrast = FlyerAIWheelPairColor.contrastingOnAccentHex(new)
                s.headlineGiftStrokeColor = contrast
                s.ctaTextColor = contrast
                flyerModel.applyState(s)
            }
        )
    }

    private var flyerInlineModificationForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlyerMerchantEditDisclosureSection(
                title: "Titre",
                systemImage: "textformat",
                isExpanded: flyerMerchantEditExpandedBinding(.titre)
            ) {
                if hasFlyerLogoForBackgroundToggle {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(
                            "Garder le fond d’origine du logo",
                            isOn: flyerModel.binding(\.flyerLogoKeepSourceBackground)
                        )
                        .tint(FlyerStudioTheme.accent)
                        Text(
                            "Désactivé (recommandé) : on retire le fond quand il est assez uniforme. Activé : on garde le fichier tel quel (fonds complexes ou logo déjà propre sur fond clair)."
                        )
                        .font(.caption2)
                        .foregroundStyle(FlyerAIEditorTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                colorCarouselField(
                    title: "Couleur du titre",
                    caption: nil,
                    hex: flyerModel.binding(\.headlineTextColor)
                )
                colorCarouselField(
                    title: "Couleur « CADEAU ! » & pastille",
                    caption: "Bandeau et piste du mot cadeau : même teinte, texte en contraste auto.",
                    hex: flyerCadeauPillAndGiftStrokeColorBinding()
                )
            }

            FlyerMerchantEditDisclosureSection(
                title: "Roue",
                systemImage: "circle.circle",
                isExpanded: flyerMerchantEditExpandedBinding(.roue)
            ) {
                FlyerAIPriorityPaletteRow(
                    orderedHexes: $flyerPalettePriorityHexes,
                    suggestedFromImages: collectFlyerImageDistinctHex6List(),
                    compactEmbedded: true,
                    selectionRingColor: FlyerStudioTheme.accent,
                    maxSlots: 2
                )
            }

            FlyerMerchantEditDisclosureSection(
                title: "Fond",
                systemImage: "rectangle.split.2x1",
                isExpanded: flyerMerchantEditExpandedBinding(.fond)
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Image par-dessus le dégradé (optionnel)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(FlyerAIEditorTheme.textSecondary)
                    PhotosPicker(selection: $flyerBgPickerItem, matching: .images) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text("Choisir une image de fond")
                                .font(.subheadline.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(FlyerAIEditorTheme.textPrimary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(FlyerAIEditorTheme.promptSurface)
                        )
                    }
                    .buttonStyle(.plain)
                    if case .dataURL = flyerModel.bgPayload {
                        Button {
                            flyerModel.applyBgPayload(.clear)
                        } label: {
                            Text("Retirer l’image (dégradé seul)")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                colorCarouselField(
                    title: "Dégradé — haut",
                    caption: "Ajusté aussi par la palette « Roue »",
                    hex: flyerModel.binding(\.colorBgTop)
                )
                colorCarouselField(
                    title: "Dégradé — bas",
                    caption: nil,
                    hex: flyerModel.binding(\.colorBgBottom)
                )
            }

            if let se = flyerModel.saveError, !se.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(se)
                    .font(.caption)
                    .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.4))
                    .padding(.top, 4)
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func colorCarouselField(title: String, caption: String?, hex: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(FlyerAIEditorTheme.textSecondary)
            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(FlyerAIEditorTheme.textTertiary)
            }
            FlyerAIColorFieldCarousel(
                hex: hex,
                selectionRingColor: FlyerStudioTheme.accent,
                compactEmbedded: true
            )
        }
    }

    private var flyerPostGenerationPreviewBlock: some View {
        HStack {
            Spacer(minLength: 0)
            Group {
                if let rawBootstrap = effectiveFlyerPreviewBootstrap, !rawBootstrap.isEmpty {
                    /// Un seul `bootstrap` que le JSON (pas de bascule strip/plein) + underlay recalculé dans le modèle → un seul `APPLY` stable.
                    let under = flyerModel.flyerWebUnderlayUIImage
                    let skip = flyerModel.flyerWebSkipCanvasSolidBackground
                    ZStack {
                        ZStack {
                            if let u = under {
                                FlyerNativeUnderlayStack(state: flyerModel.state, image: u)
                            }
                            FlyerPreviewWebView(
                                bootstrapBase64: rawBootstrap,
                                isLoading: $flyerInteractiveWebLoading,
                                skipCanvasSolidBackground: skip,
                                onNavigationFailure: { _ in flyerEmbedNavigationFailed = true }
                            )
                        }
                        .allowsHitTesting(true)
                        .shadow(color: .black.opacity(0.4), radius: 22, y: 12)
                    }
                    .background(Color(white: 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .aspectRatio(Self.flyerCanvasAspect, contentMode: .fit)
                    .frame(maxWidth: Self.flyerHeroMaxWidth)
                    .matchedGeometryEffect(id: "flyerValidateHero", in: flyerValidateMorph)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.9, anchor: .top)),
                            removal: .opacity
                        )
                    )
                } else {
                    flyerGenerationHeroCard
                        .matchedGeometryEffect(id: "flyerValidateHero", in: flyerValidateMorph)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top)
                                    .combined(with: .opacity)
                                    .combined(with: .scale(scale: 0.9, anchor: .top)),
                                removal: .opacity
                            )
                        )
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var generatedUIImage: UIImage? {
        guard let b64 = displayedAIBgBase64, !b64.isEmpty else { return nil }
        if let data = Data(base64Encoded: b64), let u = UIImage(data: data) { return u }
        return FlyerGeneratedImageDecode.uiImage(fromBase64PNG: b64)
    }

    /// PNG de session ou fond courant (serveur, choix local, etc.) — pour underlay + JSON allégé (même source que l’ex-`custom_bg`).
    private var flyerAiBackgroundUnderlayUIImage: UIImage? {
        if let ui = generatedUIImage { return ui }
        if let s = flyerModel.flyerCustomBgDataURLForNativeUnderlay,
           !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let u = FlyerDataURLImageDecode.uiImage(fromDataURLString: s) {
            return u
        }
        return nil
    }

    /// JSON sans `custom_bg_data_url` + image native : charge beaucoup plus vite que le bootstrap complet dans WKWebView.
    private func strippedBootstrapAndUnderlayPair(rawBootstrap: String) -> (bootstrap: String, underlay: UIImage)? {
        guard let u = flyerAiBackgroundUnderlayUIImage,
              let stripped = FlyerPreviewWebView.stripCustomBgFromBootstrapBase64(rawBootstrap) else {
            return nil
        }
        return (stripped, u)
    }

    private static let flyerCanvasAspect: CGFloat = 2400.0 / 3600.0
    private static let flyerHeroMaxWidth: CGFloat = 300

    private var flyerGenerationHeroCard: some View {
        let corner: CGFloat = 20
        return ZStack {
            Group {
                if let b64 = flyerHeroCompositeBootstrap {
                    let heroPair = strippedBootstrapAndUnderlayPair(rawBootstrap: b64)
                    let webB64 = heroPair?.bootstrap ?? b64
                    let heroUnder = heroPair?.underlay
                    ZStack(alignment: .topTrailing) {
                        ZStack {
                            if let u = heroUnder {
                                FlyerNativeUnderlayStack(state: flyerModel.state, image: u)
                            }
                            FlyerPreviewWebView(
                                bootstrapBase64: webB64,
                                isLoading: $heroCompositePreviewLoading,
                                skipCanvasSolidBackground: heroUnder != nil,
                                onNavigationFailure: { _ in flyerEmbedNavigationFailed = true }
                            )
                        }
                        .allowsHitTesting(false)
                        if heroCompositePreviewLoading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(10)
                        }
                    }
                } else if let image = generatedUIImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 44, weight: .semibold))
                        Text("Votre flyer apparaîtra ici")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .background(Color(white: 0.12))
                }
            }
            .aspectRatio(Self.flyerCanvasAspect, contentMode: .fit)
            .frame(maxWidth: Self.flyerHeroMaxWidth)
            .background(Color(white: 0.1))
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.38), radius: 22, y: 11)
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: displayedAIBgBase64)
    }

    private var aiSourceRow: some View {
        FlyerAILogoPhotosPickerSlot(
            selection: $logoPickerItem,
            logoJPEG: logoPreview.flatMap { $0.jpegData(compressionQuality: FlyerAISourcePickerJPEG.quality) }
        )
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var aiPromptComposerCard: some View {
        Group {
            if !flyerHeroRevealed {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Couleurs d’accent")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(FlyerAIEditorTheme.textSecondary)
                    Text("Une ou deux teintes pour la roue et les accroches. Le dégradé de fond se règle sous l’aperçu.")
                        .font(.caption2)
                        .foregroundStyle(FlyerAIEditorTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    FlyerAIPriorityPaletteRow(
                        orderedHexes: $flyerPalettePriorityHexes,
                        suggestedFromImages: collectFlyerImageDistinctHex6List(),
                        compactEmbedded: true,
                        selectionRingColor: FlyerStudioTheme.accent,
                        maxSlots: 2
                    )
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(FlyerAIEditorTheme.promptSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(FlyerAIEditorTheme.hairline, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    /// Barre fixe : **Voir l’aperçu** | image non enregistrée = enregistrer le fond | **Modifier** = sauvegarder textes & couleurs.
    private var flyerStickyPrimaryButton: some View {
        Group {
            if isSavingKeep {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Enregistrement du flyer…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FlyerAIEditorTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
            } else if isSavingFlyerEdits {
                /// Progrès affiché dans le bouton « Sauvegarder » (barre du haut) — cette branche n’est plus présentée
                /// quand `showBottomFlyerActionBar` est vrai ailleurs ; conservée pour repli.
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Sauvegarde…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FlyerAIEditorTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
            } else if displayedAIBgBase64 != nil, !flyerValidatedOnTab {
                Button {
                    Task { @MainActor in
                        await validateGeneratedFlyer()
                    }
                } label: {
                    Text("Enregistrer l’illustration")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.borderedProminent)
                .tint(FlyerStudioTheme.accent)
            } else if !flyerHeroRevealed {
                Button {
                    Task { @MainActor in
                        let ordered = flyerPalettePriorityHexes.compactMap { Self.normalizeHex($0) }
                        if let first = ordered.first {
                            applyFullFlyerAccentFromWheelPalette(ordered: Array(ordered.prefix(2)))
                        } else {
                            let h = Self.normalizeHex(initialPrimaryHex) ?? "f97316"
                            let withHash = h.hasPrefix("#") ? h : "#\(h)"
                            applyFullFlyerAccentFromWheelPalette(ordered: [withHash])
                        }
                        await flyerModel.prepareWebPreviewBeforeReveal()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        flyerCreationFreshStart = false
                        suppressAutoHeroRevealedForCreateFlow = false
                        withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                            flyerHeroRevealed = true
                        }
                    }
                } label: {
                    Text("Voir l’aperçu")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.borderedProminent)
                .tint(FlyerStudioTheme.accent)
            } else {
                /// Aperçu validé, réglages : `Sauvegarder` uniquement en tête (Liquid Glass).
                Color.clear
                    .frame(height: 0)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 14, y: 6)
    }

    private var stickyGenerateBar: some View {
        VStack(spacing: 8) {
            flyerStickyPrimaryButton
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [
                    FlyerAIEditorTheme.canvas.opacity(0),
                    FlyerAIEditorTheme.canvas.opacity(0.92),
                    FlyerAIEditorTheme.canvas
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func labeledField(_ title: String, text: Binding<String>, prompt: String, axis: Axis = .horizontal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.onCanvasSecondary)
            Group {
                if axis == .vertical {
                    TextField(prompt, text: text, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    TextField(prompt, text: text)
                }
            }
            .textFieldStyle(.plain)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
        }
    }

    private struct PublicBusinessSnapshotForAI: Decodable {
        let name: String?
        let organizationName: String?
        let sector: String?
        let backgroundColor: String?
        let foregroundColor: String?
        let labelColor: String?
    }

    @MainActor
    private func prefillCommerceFieldsIfNeeded() async {
        guard !didPrefillCommerce else { return }
        didPrefillCommerce = true
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/businesses/\(slug)") else { return }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
            let dec = JSONDecoder()
            dec.keyDecodingStrategy = .convertFromSnakeCase
            let info = try dec.decode(PublicBusinessSnapshotForAI.self, from: data)
            if brandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                brandName = (info.organizationName ?? info.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let h = Self.normalizeHex(info.labelColor ?? "") {
                setFlyerPaletteProgrammatically([h])
            } else if let h = Self.normalizeHex(info.foregroundColor ?? "") {
                setFlyerPaletteProgrammatically([h])
            }
        } catch {
            /* réseau ou parse : champs laissés manuels */
        }
    }

    /// Compresse le fond pour respecter le plafond serveur (`custom_bg_data_url` &lt; 6 Mo) et laisser de la marge au logo dans le JSON (&lt; 7 Mo au total).
    private static func dataURLForFlyerBackgroundPersisting(generatedPNGBase64: String) -> String? {
        let maxB = FlyerDashboardFlyerPrefsLimits.maxBgDataURLUtf8Bytes
        let rawFull = "data:image/png;base64,\(generatedPNGBase64)"
        if rawFull.utf8.count <= maxB {
            return rawFull
        }
        if let ui = FlyerGeneratedImageDecode.uiImage(fromBase64PNG: generatedPNGBase64) {
            for side: CGFloat in [1024, 896, 768, 640, 560, 480, 420, 360, 300] {
                if let p = ui.normalizedFlyerPNGDataURL(maxSide: side), p.utf8.count <= maxB {
                    return p
                }
            }
            let targets = [
                FlyerDashboardFlyerPrefsLimits.aiBackgroundJPEGMaxDecodedBytes,
                2_000_000, 1_400_000, 900_000, 550_000, 350_000, 220_000
            ]
            for maxDec in targets {
                if let jpeg = ui.normalizedFlyerDataURLForFlyerAI(maxDecodedBytes: maxDec), jpeg.utf8.count <= maxB {
                    return jpeg
                }
            }
            var side: CGFloat = 360
            while side >= 100 {
                if let j = ui.normalizedFlyerDataURL(maxSide: side, jpegQuality: 0.32), j.utf8.count <= maxB {
                    return j
                }
                side -= 40
            }
            return nil
        }
        return rawFull.utf8.count <= maxB ? rawFull : nil
    }

    /// Relance la validation automatique si un fond IA a été restauré depuis le disque (app quittée avant la sauvegarde serveur).
    private func retryPendingValidateIfNeeded() async {
        guard FlyerPendingBgStorage.shared.hasPending(slug: slug) else { return }
        guard displayedAIBgBase64 != nil else { return }
        guard !flyerValidatedOnTab, !isSavingKeep else { return }
        // Attendre que le modèle serveur soit chargé avant de tenter la sauvegarde
        var attempts = 0
        while flyerModel.isLoading, attempts < 30 {
            try? await Task.sleep(nanoseconds: 300_000_000)
            attempts += 1
        }
        guard !flyerValidatedOnTab, !isSavingKeep else { return }
        await validateGeneratedFlyer()
    }

    /// Quitte le mode « flyer enregistré » compact : formulaire vierge (nouveau prompt / visuels), sans relancer une génération automatiquement.
    private func performFlyerRegenerationFromValidated() async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if !flyerModel.hasCompletedSuccessfulFlyerLoad {
            await flyerModel.load(showProgress: true, forceFullFlyerPrefsMerge: true)
        }
        if let snap = base64ForStashingBeforeRecreate() {
            recreateStashAIBgBase64 = snap
            FlyerRecreatePreviousBackupStorage.shared.save(rawBase64: snap, slug: slug)
        }
        showRecreateStashedVersion = false
        /// L’aperçu WK ne doit plus réinjecter l’ancien `custom_logo_data_url` du dashboard (clé omise → logo public commerce ou vide selon embed).
        flyerModel.beginFlyerRecreateSessionForPreview()
        logoPickerItem = nil
        flyerBgCropPayload = nil
        flyerLogoQuickExportDataUrl = nil
        flyerLogoCropPayload = nil
        logoPreview = nil
        errorMessage = nil
        flyerCreationFreshStart = true
        withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
            flyerValidatedOnTab = false
            flyerExpandedEditorFromValidated = true
        }
        generatedBase64 = nil
        FlyerPendingBgStorage.shared.clear(slug: slug)
        flyerHeroRevealed = false
    }

    private func validateGeneratedFlyer() async {
        guard let rawBase64 = displayedAIBgBase64 else { return }
        isSavingKeep = true
        defer { isSavingKeep = false }
        guard let url = Self.dataURLForFlyerBackgroundPersisting(generatedPNGBase64: rawBase64) else {
            await MainActor.run {
                errorMessage = "L’image de fond est trop lourde pour être enregistrée. Réessayez ou choisissez un visuel plus léger."
            }
            return
        }
        if let logoDataUrl = await flyerModel.exportLogoDataURLForAIGenerate(logoPickerUIImage: logoPreview) {
            guard logoDataUrl.utf8.count <= FlyerDashboardFlyerPrefsLimits.maxLogoDataURLUtf8Bytes else {
                await MainActor.run {
                    errorMessage = "Le logo est trop lourd pour être enregistré avec le flyer. Choisissez une image plus légère."
                }
                return
            }
            flyerModel.applyLogoPayload(.dataURL(logoDataUrl))
        }
        if await flyerModel.applyAIBackgroundAndSave(dataURL: url) {
            await MainActor.run {
                if isTabRoot {
                    // Sous-couche : image persistée (sessions avec fond déjà généré côté API).
                    generatedBase64 = rawBase64
                    recreateStashAIBgBase64 = nil
                    showRecreateStashedVersion = false
                    FlyerRecreatePreviousBackupStorage.shared.clear(slug: slug)
                    FlyerPendingBgStorage.shared.clear(slug: slug)
                    logoPreview = nil
                    flyerLogoQuickExportDataUrl = nil
                    logoPickerItem = nil
                    flyerLogoCropPayload = nil
                    flyerBgCropPayload = nil
                    flyerExpandedEditorFromValidated = false
                    flyerCreationFreshStart = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    Task { await syncService.syncAfterServerMutation() }
                    if let popToCommerce = onFlyerSaveSuccessReturnToCommerce {
                        popToCommerce()
                        return
                    }
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                        flyerValidatedOnTab = true
                    }
                } else {
                    dismiss()
                }
            }
        } else {
            await MainActor.run {
                errorMessage = flyerModel.saveError ?? "Enregistrement impossible."
            }
        }
    }

    private static func normalizeHex(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        let withHash = t.hasPrefix("#") ? t : "#\(t)"
        guard withHash.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil else { return nil }
        return withHash
    }

    private static func tintBackgroundTop(fromAccentHex raw: String) -> String? {
        guard let a = normalizeHex(raw),
              let (r, g, b) = rgbComponents(fromHex: a) else { return nil }
        let mix = 0.82
        return rgbHex(
            r: r + (1 - r) * mix,
            g: g + (1 - g) * mix,
            b: b + (1 - b) * mix
        )
    }

    /// Haut du dégradé : **clair, vif** (mélange accent + blanc — plus de base bleu nuit imposé).
    private static func flyerGradientBgTopHex(fromAccentHex raw: String) -> String? {
        guard let (ar, ag, ab) = rgbComponents(fromHex: raw) else { return nil }
        let t = 0.2
        return rgbHex(
            r: ar * t + (1.0 - t) * 1.0,
            g: ag * t + (1.0 - t) * 1.0,
            b: ab * t + (1.0 - t) * 1.0
        )
    }

    /// Bas : un peu **plus** de la 2ᵉ teinte pour un joli dégradé pastel / bonbon.
    private static func flyerGradientBgBottomHex(fromSecondaryHex raw: String) -> String? {
        guard let (sr, sg, sb) = rgbComponents(fromHex: raw) else { return nil }
        let t = 0.34
        let near = 0.96
        return rgbHex(
            r: sr * t + (1.0 - t) * near,
            g: sg * t + (1.0 - t) * near,
            b: sb * t + (1.0 - t) * 1.0
        )
    }

    private static func darkenHex(_ raw: String, by amount: Double) -> String? {
        guard let (r, g, b) = rgbComponents(fromHex: raw) else { return nil }
        let a = max(0, min(0.5, amount))
        return rgbHex(r: r * (1 - a), g: g * (1 - a), b: b * (1 - a))
    }

    private static func rgbComponents(fromHex raw: String) -> (Double, Double, Double)? {
        guard let h = normalizeHex(raw) else { return nil }
        let t = String(h.dropFirst())
        guard t.count == 6,
              let rv = UInt8(t.prefix(2), radix: 16),
              let gv = UInt8(t.dropFirst(2).prefix(2), radix: 16),
              let bv = UInt8(t.suffix(2), radix: 16) else { return nil }
        return (Double(rv) / 255.0, Double(gv) / 255.0, Double(bv) / 255.0)
    }

    private static func rgbHex(r: Double, g: Double, b: Double) -> String {
        let rr = UInt8(max(0, min(255, Int(round(r * 255)))))
        let gg = UInt8(max(0, min(255, Int(round(g * 255)))))
        let bb = UInt8(max(0, min(255, Int(round(b * 255)))))
        return String(format: "#%02X%02X%02X", rr, gg, bb)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

private extension UIImage {
    func normalizedFlyerPNGDataURL(maxSide: CGFloat) -> String? {
        let maxPx = max(size.width, size.height)
        let scale = min(1, maxSide / maxPx)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let r = UIGraphicsImageRenderer(size: newSize)
        let img = r.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
        guard let data = img.pngData() else { return nil }
        return "data:image/png;base64,\(data.base64EncodedString())"
    }

    func normalizedFlyerDataURL(maxSide: CGFloat, jpegQuality: CGFloat = 0.82) -> String? {
        let maxPx = max(size.width, size.height)
        let scale = min(1, maxSide / maxPx)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let r = UIGraphicsImageRenderer(size: newSize)
        let img = r.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
        guard let data = img.jpegData(compressionQuality: jpegQuality) else { return nil }
        return "data:image/jpeg;base64,\(data.base64EncodedString())"
    }

    /// Réduit progressivement taille + qualité JPEG jusqu’à tenir sous la limite API (évite erreur « image trop lourde »).
    func normalizedFlyerDataURLForFlyerAI(maxDecodedBytes: Int = 7_000_000) -> String? {
        let sides: [CGFloat] = [2048, 1792, 1536, 1280, 1152, 1024, 896, 768, 640, 512]
        let qualities: [CGFloat] = [0.88, 0.82, 0.76, 0.72, 0.66, 0.6, 0.54, 0.48, 0.42, 0.36]
        let maxPxIn = max(size.width, size.height)
        for maxSide in sides {
            let scale = min(1, maxSide / maxPxIn)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let r = UIGraphicsImageRenderer(size: newSize)
            let img = r.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
            for q in qualities {
                if let data = img.jpegData(compressionQuality: q), data.count <= maxDecodedBytes {
                    return "data:image/jpeg;base64,\(data.base64EncodedString())"
                }
            }
        }
        return normalizedFlyerDataURL(maxSide: 400, jpegQuality: 0.28)
    }

    func flyerFlattenUpIfNeeded() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// Data URL pour le logo : d’abord **PNG (transparence)** via détourage si `keepSourceBackground` est `false` ; repli **JPEG** seulement si l’image reste 100 % opaque (sinon le JPEG réintroduisait un fond plomb).
    func flyerLogoExportDataURLReliable(maxUtf8: Int, keepSourceBackground: Bool = false) -> String {
        if let s = self.flyerLogoPNGDataURLForAI(
            maxEncodedLength: maxUtf8,
            keepSourceBackground: keepSourceBackground
        ),
           !s.isEmpty, s.utf8.count <= maxUtf8
        { return s }
        let flat = FlyerLogoBackgroundPrepared.imageForFlyerLogoExport(self, keepSourceBackground: keepSourceBackground)
        if !keepSourceBackground,
           flat.flyerImageLikelyHasTransparency,
           let s = flat.flyerFittingPngDataURLForTransparencyTight(maxEncodedLength: maxUtf8), !s.isEmpty
        { return s }
        let sides: [CGFloat] = [2048, 1792, 1536, 1280, 1152, 1024, 896, 768, 640, 512, 420, 360, 300, 256, 220, 180, 160, 128, 112, 96, 80, 64, 56, 48, 40, 32]
        return flyerExportJPEGDataURLFitting(flat: flat.flyerFlattenUpIfNeeded(), maxUtf8: maxUtf8, sides: sides)
    }

    /// Fond personnalisé (calque natif) : JPEG sous le plafond `custom_bg_data_url` serveur.
    func flyerCustomBgExportDataURLReliable(maxUtf8: Int) -> String {
        let sides: [CGFloat] = [2560, 2200, 1920, 1600, 1280, 1024, 896, 768, 640, 512, 420, 360, 300, 256, 220, 180, 160, 128, 112, 96, 80, 64, 56, 48, 40, 32]
        return flyerExportJPEGDataURLFitting(flat: flyerFlattenUpIfNeeded(), maxUtf8: maxUtf8, sides: sides)
    }

    private func flyerExportJPEGDataURLFitting(flat: UIImage, maxUtf8: Int, sides: [CGFloat]) -> String {
        let maxPxIn = max(flat.size.width, flat.size.height)
        let qualities: [CGFloat] = [0.9, 0.85, 0.78, 0.7, 0.62, 0.54, 0.46, 0.38, 0.3, 0.22, 0.16, 0.12, 0.1, 0.08, 0.06]
        for cap in sides {
            let scale = min(1, cap / max(1, maxPxIn))
            let newSize = CGSize(width: max(1, flat.size.width * scale), height: max(1, flat.size.height * scale))
            let fmt = UIGraphicsImageRendererFormat.default()
            fmt.opaque = false
            fmt.scale = 1
            let img = UIGraphicsImageRenderer(size: newSize, format: fmt).image { _ in
                flat.draw(in: CGRect(origin: .zero, size: newSize))
            }
            for q in qualities {
                if let d = img.jpegData(compressionQuality: q) {
                    let s = "data:image/jpeg;base64,\(d.base64EncodedString())"
                    if s.utf8.count <= maxUtf8 { return s }
                }
            }
        }
        let tiny = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { _ in
            flat.draw(in: CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        for q: CGFloat in [0.22, 0.18, 0.14, 0.1, 0.08, 0.06, 0.05] {
            if let d = tiny.jpegData(compressionQuality: q) {
                let s = "data:image/jpeg;base64,\(d.base64EncodedString())"
                if s.utf8.count <= maxUtf8 { return s }
            }
        }
        if let d = tiny.jpegData(compressionQuality: 0.04) {
            return "data:image/jpeg;base64,\(d.base64EncodedString())"
        }
        if let p = tiny.pngData() {
            return "data:image/png;base64,\(p.base64EncodedString())"
        }
        return "data:image/jpeg;base64,"
    }
}

#Preview {
    NavigationStack {
        MerchantProgramHubView(context: PersistenceController.preview.container.viewContext)
            .environmentObject(SyncService(container: PersistenceController.preview.container))
    }
}
