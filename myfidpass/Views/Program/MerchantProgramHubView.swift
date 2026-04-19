//
//  MerchantProgramHubView.swift
//  myfidpass
//
//  Onglet « Flyer » : assistant IA (génération), validation, lien partage, éditeur visuel fusionné.
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
    /// Depuis Commerce (carte « Flyer enregistré ») : forcer un `GET …/dashboard/flyer` pour afficher le mode compact — sinon `loadFromServerIfStale(120s)` laisse un modèle vide.
    private let forceRefreshFlyerFromServer: Bool
    /// Après enregistrement du flyer IA : revenir sur la checklist Commerce au lieu de l’écran noir du hub (animation « rangement » uniquement là-bas).
    private let onFlyerSaveSuccessReturnToCommerce: (() -> Void)?
    @State private var didApplyOpenMyCardSeed = false
    @State private var navigateToMyCard = false

    init(
        context _: NSManagedObjectContext,
        seedOpenMyCard: Bool = false,
        seedRecreateFlyer: Bool = false,
        forceRefreshFlyerFromServer: Bool = false,
        onFlyerSaveSuccessReturnToCommerce: (() -> Void)? = nil
    ) {
        self.seedOpenMyCard = seedOpenMyCard
        self.seedRecreateFlyer = seedRecreateFlyer
        self.forceRefreshFlyerFromServer = forceRefreshFlyerFromServer
        self.onFlyerSaveSuccessReturnToCommerce = onFlyerSaveSuccessReturnToCommerce
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
                        forceInitialFlyerLoad: seedRecreateFlyer || forceRefreshFlyerFromServer,
                        onFlyerSaveSuccessReturnToCommerce: onFlyerSaveSuccessReturnToCommerce
                    )
                    .environmentObject(syncService)
                } else {
                    flyerNoSlugPlaceholder
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $navigateToMyCard) {
            MyCardView(context: viewContext)
                .environmentObject(syncService)
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenProgramMyCard)) { _ in
            navigateToMyCard = true
        }
        .onAppear {
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
    let forceInitialFlyerLoad: Bool
    let onFlyerSaveSuccessReturnToCommerce: (() -> Void)?
    @EnvironmentObject private var syncService: SyncService
    @StateObject private var model: ProgramFlyerEditorModel

    init(
        slug: String,
        palette: DashboardRevolutPalette,
        seedRecreateFlyer: Bool = false,
        forceInitialFlyerLoad: Bool = false,
        onFlyerSaveSuccessReturnToCommerce: (() -> Void)? = nil
    ) {
        self.slug = slug
        self.palette = palette
        self.seedRecreateFlyer = seedRecreateFlyer
        self.forceInitialFlyerLoad = forceInitialFlyerLoad
        self.onFlyerSaveSuccessReturnToCommerce = onFlyerSaveSuccessReturnToCommerce
        _model = StateObject(wrappedValue: ProgramFlyerEditorModel(slug: slug))
    }

    var body: some View {
        FlyerAIGeneratorSheet(
            slug: slug,
            palette: palette,
            initialPrimaryHex: model.state.colorPrimary,
            flyerModel: model,
            isTabRoot: true,
            seedRecreateFlyerSession: seedRecreateFlyer,
            onFlyerSaveSuccessReturnToCommerce: onFlyerSaveSuccessReturnToCommerce
        )
        .task(id: slug) {
            if seedRecreateFlyer || forceInitialFlyerLoad {
                await model.load()
            } else {
                await model.loadFromServerIfStale(minimumInterval: 120)
            }
        }
        .refreshable {
            await syncService.syncAfterServerMutation()
            await model.load()
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
    /// PNG logo encodé pour le dashboard (boucle de réduction côté `flyerLogoPNGDataURLForAI`).
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
    @Published var loadError: String?
    @Published var saveError: String?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published private(set) var bootstrapPreviewBase64: String?
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
    /// Après « Recréer » / régénérer : n’injecte pas l’ancien `custom_logo_data_url` du dashboard dans le bootstrap (sinon WKWebView garde l’ancien logo jusqu’au prochain enregistrement).
    var suppressDashboardCustomLogoForPreview = false

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init(slug: String) {
        self.slug = slug
        self.state = FlyerStateDTO.default
        refreshPreviewBootstrap()
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
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
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

    func refreshPreviewBootstrap() {
        var st = state
        st.normalizeClamps()
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .useDefaultKeys
        let payload = FlyerBootstrapPreviewPayload(
            flyerPrefs: .init(
                state: st,
                customLogoDataUrl: customLogoDataUrlForBootstrap(),
                customBgDataUrl: effectiveBgPreview(),
                businessSlug: slug
            ),
            updatedAt: serverUpdatedAt,
            shareUrl: shareUrl
        )
        if let data = try? enc.encode(payload) {
            bootstrapPreviewBase64 = data.base64EncodedString()
            return
        }
        var safe = FlyerStateDTO.default
        safe.headline = st.headline
        safe.ctaBanner = st.ctaBanner
        safe.ctaBannerBgColor = st.ctaBannerBgColor
        safe.ctaTextColor = st.ctaTextColor
        safe.step1 = st.step1
        safe.step2 = st.step2
        safe.step3 = st.step3
        safe.wheelColorOdd = st.wheelColorOdd
        safe.wheelColorEven = st.wheelColorEven
        safe.headlineSizePct = st.headlineSizePct
        safe.headlineTextColor = st.headlineTextColor
        safe.headlineGiftStrokeColor = st.headlineGiftStrokeColor
        safe.flyerLogoCenterYFrac = st.flyerLogoCenterYFrac
        safe.flyerLogoMaxWFrac = st.flyerLogoMaxWFrac
        safe.flyerLogoMaxHFrac = st.flyerLogoMaxHFrac
        safe.normalizeClamps()
        let fallbackPayload = FlyerBootstrapPreviewPayload(
            flyerPrefs: .init(
                state: safe,
                customLogoDataUrl: customLogoDataUrlForBootstrap(),
                customBgDataUrl: effectiveBgPreview(),
                businessSlug: slug
            ),
            updatedAt: serverUpdatedAt,
            shareUrl: shareUrl
        )
        if let data2 = try? enc.encode(fallbackPayload) {
            bootstrapPreviewBase64 = data2.base64EncodedString()
        }
    }

    /// Même JSON que l’aperçu studio (`flyer-embed`), avec fond optionnellement forcé (ex. PNG IA avant enregistrement).
    /// `provisionalCustomLogoDataURL` : logo choisi dans la sheet IA (`logoPreview`) avant `applyLogoPayload` au moment du glissement.
    func encodedPreviewBootstrapBase64(
        provisionalCustomBgDataURL: String?,
        provisionalCustomLogoDataURL: String? = nil
    ) -> String? {
        var st = state
        st.normalizeClamps()
        let bg = provisionalCustomBgDataURL ?? effectiveBgPreview()
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
        if let data = try? enc.encode(payload) {
            return data.base64EncodedString()
        }
        /// Repli : état par défaut + textes courants — évite l’aperçu « PNG nu » (sans roue / QR canvas) si l’encodage échoue encore.
        var safe = FlyerStateDTO.default
        safe.headline = st.headline
        safe.ctaBanner = st.ctaBanner
        safe.ctaBannerBgColor = st.ctaBannerBgColor
        safe.ctaTextColor = st.ctaTextColor
        safe.step1 = st.step1
        safe.step2 = st.step2
        safe.step3 = st.step3
        safe.wheelColorOdd = st.wheelColorOdd
        safe.wheelColorEven = st.wheelColorEven
        safe.headlineSizePct = st.headlineSizePct
        safe.headlineTextColor = st.headlineTextColor
        safe.headlineGiftStrokeColor = st.headlineGiftStrokeColor
        safe.flyerLogoCenterYFrac = st.flyerLogoCenterYFrac
        safe.flyerLogoMaxWFrac = st.flyerLogoMaxWFrac
        safe.flyerLogoMaxHFrac = st.flyerLogoMaxHFrac
        safe.normalizeClamps()
        let fallbackPayload = FlyerBootstrapPreviewPayload(
            flyerPrefs: .init(
                state: safe,
                customLogoDataUrl: logoForBootstrap,
                customBgDataUrl: bg,
                businessSlug: slug
            ),
            updatedAt: serverUpdatedAt,
            shareUrl: shareUrl
        )
        guard let data2 = try? enc.encode(fallbackPayload) else { return nil }
        return data2.base64EncodedString()
    }

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
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
            isUndoRedoOrLoad = true
            if let fp = res.flyerPrefs {
                serverLogoDataUrl = fp.customLogoDataUrl
                serverBgDataUrl = fp.customBgDataUrl
                if let s = fp.state {
                    var merged = s
                    merged.normalizeClamps()
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
            refreshPreviewBootstrap()
            /// Parallélise les deux fetches réseau (logo public + fond public) — économise ~2 s de latence séquentielle.
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.prefetchPublicLogoCacheIfNeeded() }
                group.addTask { await self.hydrateCustomBgFromPublicEndpointIfNeeded() }
            }
            refreshPreviewBootstrap()
            lastSuccessfulServerLoadAt = Date()
        } catch {
            isUndoRedoOrLoad = false
            let detail = (error as? APIError)?.errorDescription ?? error.localizedDescription
            loadError = detail
        }
    }

    /// Remplit `serverBgDataUrl` depuis `GET …/public/flyer-custom-bg` lorsque le dashboard ne renvoie pas le data URL (évite l’écran « créer le flyer » alors qu’un fond est en ligne).
    private func hydrateCustomBgFromPublicEndpointIfNeeded() async {
        if let s = serverBgDataUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return }
        let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        let baseRoot = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseRoot)/api/businesses/\(enc)/public/flyer-custom-bg") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 40
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

    /// Recharge le flyer depuis le serveur seulement si les données ne sont pas déjà « fraîches » (retour onglet sans flash).
    /// `load()` et « Tirer pour actualiser » restent des rechargements complets.
    func loadFromServerIfStale(minimumInterval: TimeInterval = 120) async {
        if let last = lastSuccessfulServerLoadAt, Date().timeIntervalSince(last) < minimumInterval {
            return
        }
        await load()
    }

    func save() async -> Bool {
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
            _ = try await APIClient.shared.request(APIEndpoint.dashboardFlyerPut(slug: slug, payload: payload)) as FlyerPutAPIResponse
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
            refreshPreviewBootstrap()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await load()
            if loadError != nil {
                try? await Task.sleep(nanoseconds: 450_000_000)
                await load()
            }
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
        return await save()
    }
}

// MARK: - Studio « Canva » (plein écran)

private enum FlyerStudioTheme {
    /// Accent type Canva (violet).
    static let accent = Color(red: 0.45, green: 0.32, blue: 0.96)

}

/// Chargement depuis `PhotosPickerItem` : `UIImage(data:)` seul échoue souvent (HEIC, profils) → repli `ImageIO`.
/// (`PhotosPickerItem` n’expose pas `itemProvider` sur iOS SwiftUI — seulement `loadTransferable`.)
private enum FlyerPickerUIImageLoader {
    static func load(from item: PhotosPickerItem) async -> UIImage? {
        guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else {
            return nil
        }
        if let ui = UIImage(data: data) { return ui }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let scale = await MainActor.run { UIScreen.main.scale }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
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

/// Constantes d’animation hors du type générique (Swift n’autorise pas `static let` dans `struct ...<Content: View>`).
private enum FlyerGenerationAuthenticRevealTiming {
    /// Huit paliers : bandes cumulées du haut vers le bas (titre → roue → bandeau / CTA+QR → étapes).
    static let maxPhase = 8
    static let cumulativeHeightFraction: [CGFloat] = [
        0.0,
        0.11,
        0.24,
        0.50,
        0.64,
        0.78,
        0.88,
        0.96,
        1.0
    ]
    /// Dévoilement plus rapide : moins d’effet « saccadé » en fin de génération.
    static let initialDelayNs: UInt64 = 72_000_000
    static let stepDelayNs: UInt64 = 110_000_000
}

/// Cadre neutre pendant la génération IA : aucun aperçu flyer (pas de WKWebView, pas de dévoilement partiel roue/QR).
private struct FlyerGeneratingHeroPlaceholder: View {
    var cornerRadius: CGFloat = 20
    var maxWidth: CGFloat = 300
    var aspectRatio: CGFloat

    var body: some View {
        ZStack {
            Color(white: 0.1)
            FlyerGenerationScanOverlay(cornerRadius: cornerRadius)
                .allowsHitTesting(false)
        }
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: maxWidth)
    }
}

/// Pendant l’appel IA : dévoilement progressif du **vrai** rendu (`WKWebView` + fond natif), aligné sur la mise en page du flyer embarqué — pas de roue / QR / titre factices en SwiftUI.
private struct FlyerGenerationAuthenticCanvasReveal<Content: View>: View {
    let isGenerating: Bool
    @ViewBuilder var content: () -> Content

    @State private var revealPhase: Int = 0
    @State private var phaseTask: Task<Void, Never>?

    private var displayHeightFraction: CGFloat {
        if !isGenerating { return 1 }
        let i = min(max(revealPhase, 0), FlyerGenerationAuthenticRevealTiming.maxPhase)
        return FlyerGenerationAuthenticRevealTiming.cumulativeHeightFraction[i]
    }

    var body: some View {
        content()
            .mask(alignment: .top) {
                GeometryReader { geo in
                    let h = max(0, geo.size.height * displayHeightFraction)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: geo.size.width, height: h)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .animation(.spring(response: 0.58, dampingFraction: 0.82), value: displayHeightFraction)
            .onAppear {
                Task { @MainActor in
                    if isGenerating {
                        startRevealSequence()
                    } else {
                        revealPhase = FlyerGenerationAuthenticRevealTiming.maxPhase
                    }
                }
            }
            .onChange(of: isGenerating) { _, on in
                Task { @MainActor in
                    if on {
                        startRevealSequence()
                    } else {
                        cancelSequence()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.92)) {
                            revealPhase = FlyerGenerationAuthenticRevealTiming.maxPhase
                        }
                    }
                }
            }
            .onDisappear {
                cancelSequence()
            }
    }

    private func startRevealSequence() {
        cancelSequence()
        revealPhase = 0
        phaseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: FlyerGenerationAuthenticRevealTiming.initialDelayNs)
            for step in 1...FlyerGenerationAuthenticRevealTiming.maxPhase {
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.56, dampingFraction: 0.81)) {
                    revealPhase = step
                }
                if step < FlyerGenerationAuthenticRevealTiming.maxPhase {
                    try? await Task.sleep(nanoseconds: FlyerGenerationAuthenticRevealTiming.stepDelayNs)
                }
            }
        }
    }

    private func cancelSequence() {
        phaseTask?.cancel()
        phaseTask = nil
    }
}

// MARK: - Sources média IA (JPEG snapshot pour labels PhotosPicker @Sendable / Swift 6)

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
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
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

private struct FlyerAIStylePhotosPickerSlot: View {
    @Binding var selection: [PhotosPickerItem]
    var styleJPEGs: [Data]

    var body: some View {
        let isActive = !styleJPEGs.isEmpty
        let firstJPEG = styleJPEGs.first
        let extra = max(0, styleJPEGs.count - 1)
        PhotosPicker(selection: $selection, maxSelectionCount: 3, matching: .images) {
            FlyerAISourcePickerCard(
                title: "Inspiration DA",
                symbol: "sparkles",
                isActive: isActive,
                preview: {
                    if let firstJPEG, let ui = UIImage(data: firstJPEG) {
                        FlyerAISourceThumbImage(ui: ui, extraCountBadge: extra)
                    } else {
                        FlyerAISourceThumbEmpty(
                            systemImage: "rectangle.stack.badge.plus",
                            label: "Importer des références"
                        )
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

/// Masque la tab bar sur l’écran de création (saisie, aperçu hors génération) ; la réaffiche **uniquement** pendant l’animation de génération IA pour permettre de naviguer dans l’app.
private struct MerchantFlyerTabBarForCreationVisibility: ViewModifier {
    let isTabRoot: Bool
    let isGenerating: Bool

    func body(content: Content) -> some View {
        if isTabRoot && !isGenerating {
            content.toolbar(.hidden, for: .tabBar)
        } else {
            content
        }
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
    /// Si non nil : après sauvegarde réussie du flyer IA, fermer le hub et afficher la checklist Commerce (évite le mode compact sur fond noir).
    var onFlyerSaveSuccessReturnToCommerce: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var syncService: SyncService

    @State private var brandName = ""
    @State private var cuisineOrConcept = ""
    /// Couleur flyer IA : une teinte (priorité pour l’API).
    @State private var flyerPalettePriorityHexes: [String] = ["#FF6B9D"]
    /// Mise à jour programmée (init, prefill, extraction logo) — ne pas marquer la couleur comme personnalisée.
    @State private var isUpdatingAccentFromEngine = false
    /// Dès que l’utilisateur touche la teinte (pastille ou fiche précision), on ne re-suggère plus depuis les images.
    @State private var flyerAccentUserCustomized = false
    @State private var logoPickerItem: PhotosPickerItem?
    @State private var logoPreview: UIImage?
    @State private var stylePickerItems: [PhotosPickerItem] = []
    @State private var stylePreviews: [UIImage] = []

    @State private var isGenerating = false
    /// Évite deux reprises concurrentes (`.task` + retour au premier plan).
    @State private var isResumingFlyerJob = false
    @State private var errorMessage: String?
    @State private var generatedBase64: String?
    @State private var didApplyInitialColors = false
    @State private var isSavingKeep = false
    @State private var didPrefillCommerce = false
    /// Grand aperçu flyer + zone scan : visible après « Générer le flyer » (ou si un rendu existe déjà).
    @State private var flyerHeroRevealed = false
    @State private var heroCompositePreviewLoading = false
    @State private var flyerInteractiveWebLoading = false
    @FocusState private var isPromptFieldFocused: Bool
    @State private var flyerValidatedOnTab = false
    /// L'utilisateur a ouvert « Modifier » / « Continuer avec l'IA » depuis le mode compact : afficher l'éditeur complet même si un fond est déjà en base.
    @State private var flyerExpandedEditorFromValidated = false
    /// Après « Régénérer » : ne pas rouvrir automatiquement l’aperçu héros tant que l’utilisateur n’a pas relancé une génération.
    @State private var flyerCreationFreshStart = false
    @State private var didApplyRecreateSeed = false
    @State private var showRegenerateFlyerConfirm = false
    @Namespace private var flyerValidateMorph

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

    /// Générations flyer IA disponibles (quota ou illimité serveur).
    private var canUseFlyerIA: Bool {
        flyerUnlimitedEffective || flyerModel.flyerAiGenerationsRemaining > 0
    }

    /// Aperçu héros post-IA : même canvas que l’éditeur (`flyer-embed`) avec le PNG IA en fond provisoire.
    private var flyerHeroCompositeBootstrap: String? {
        guard let raw = generatedBase64, !raw.isEmpty else { return nil }
        let dataURL = "data:image/png;base64,\(raw)"
        let fromPicker = logoPreview.flatMap {
            $0.flyerLogoPNGDataURLForAI(maxEncodedLength: FlyerDashboardFlyerPrefsLimits.logoPngMaxEncodedUtf8Bytes)
                ?? $0.normalizedFlyerDataURLForFlyerAI()
        }
        /// Si l’export data URL depuis `UIImage` échoue, le modèle peut déjà porter le même logo (`.dataURL`) — évite de retomber sur l’ancien logo serveur.
        let provisionalLogo: String? = fromPicker ?? {
            if case .dataURL(let s) = flyerModel.logoPayload { return s }
            return nil
        }()
        return flyerModel.encodedPreviewBootstrapBase64(
            provisionalCustomBgDataURL: dataURL,
            provisionalCustomLogoDataURL: provisionalLogo
        )
    }

    /// Aperçu interactif : fond IA non validé si présent, sinon prefs serveur.
    private var effectiveFlyerPreviewBootstrap: String? {
        flyerHeroCompositeBootstrap ?? flyerModel.bootstrapPreviewBase64
    }

    /// Après cold start / GET flyer : montrer le bloc aperçu (roue + QR) même sans `generatedBase64` en mémoire.
    private func syncFlyerHeroRevealedForPersistedServerFlyer() {
        if flyerCreationFreshStart { return }
        if generatedBase64 != nil {
            flyerHeroRevealed = true
            return
        }
        if hasPersistedFlyerBackgroundOnServer,
           let b64 = flyerModel.bootstrapPreviewBase64, !b64.isEmpty {
            flyerHeroRevealed = true
        }
    }

    private var bottomScrollPadding: CGFloat {
        if isGenerating { return 52 }
        return flyerHeroRevealed ? 120 : 140
    }

    /// Découpé du `body` pour accélérer l’inférence de types du compilateur.
    private var flyerAIGeneratorScrollAndChrome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Retour masqué pendant la génération IA (navigation via tab bar ; la génération continue en arrière-plan).
                if !isGenerating {
                    HStack {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Retour")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundStyle(FlyerAIEditorTheme.textSecondary)
                            .padding(.vertical, 8)
                            .padding(.trailing, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 4)
                }

                fieldsBlock
                    .transition(
                        .asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .bottom)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.97, anchor: .bottom))
                        )
                    )
                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .padding(.top, 8)
            .padding(.bottom, bottomScrollPadding)
        }
        .scrollIndicators(.hidden)
        // Scroll autorisé pendant la génération (tab bar utilisable ; pas de blocage « figé » sur l’écran).
        .background {
            ZStack {
                FlyerAIEditorTheme.canvas
                if isGenerating {
                    flyerAIIridescentBackdrop()
                        .transition(.opacity.animation(.easeInOut(duration: 0.45)))
                }
            }
            .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom) {
            if !isGenerating {
                stickyGenerateBar
            }
        }
    }

    var body: some View {
        flyerAIGeneratorScrollAndChrome
        .alert("Régénérer le flyer ?", isPresented: $showRegenerateFlyerConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Continuer") {
                Task { await performFlyerRegenerationFromValidated() }
            }
        } message: {
            Text(
                "Le flyer visible par vos clients reste en place et sauvegardé tant que vous n’enregistrez pas un nouveau visuel.\n\n"
                    + "Chaque nouvelle image générée consomme une création sur votre quota. Vous pourrez saisir un nouveau texte et de nouvelles images de référence avant de lancer la génération."
            )
        }
        .onAppear {
            if flyerPalettePriorityHexes.count > 1 {
                let first = flyerPalettePriorityHexes.compactMap { Self.normalizeHex($0) }.first
                if let f = first { setFlyerPaletteProgrammatically([f]) }
            }
            // Restore pending AI background from disk (survives force-quit before server save).
            if generatedBase64 == nil, let saved = FlyerPendingBgStorage.shared.loadBase64(slug: slug) {
                generatedBase64 = saved
            }
            guard !didApplyInitialColors else { return }
            didApplyInitialColors = true
            setFlyerPaletteProgrammatically([Self.normalizeHex(initialPrimaryHex) ?? "#f97316"])
            if generatedBase64 != nil {
                flyerHeroRevealed = true
            }
            syncFlyerHeroRevealedForPersistedServerFlyer()
        }
        .onReceive(flyerModel.objectWillChange.receive(on: RunLoop.main)) { _ in
            syncFlyerHeroRevealedForPersistedServerFlyer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            flyerScenePhaseChanged(newPhase)
        }
        .onChange(of: flyerPalettePriorityHexes) { _, _ in
            guard !isUpdatingAccentFromEngine else { return }
            flyerAccentUserCustomized = true
        }
        .onChange(of: isGenerating) { _, newValue in
            if newValue {
                startScanAnimation()
            } else {
                stopScanAnimation()
            }
        }
        .onChange(of: stylePickerItems) { _, new in
            Task { @MainActor in
                await syncStylePreviews(from: new)
            }
        }
        .onChange(of: logoPickerItem) { _, new in
            Task { @MainActor in
                await handleFlyerLogoPick(new)
            }
        }
        .task {
            await prefillCommerceFieldsIfNeeded()
            if !seedRecreateFlyerSession {
                await resumePendingFlyerJobIfNeeded()
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
                    await flyerModel.load()
                }
            }
            if seedRecreateFlyerSession, !didApplyRecreateSeed {
                didApplyRecreateSeed = true
                await performFlyerRegenerationFromValidated()
            }
        }
        .modifier(MerchantFlyerTabBarForCreationVisibility(isTabRoot: isTabRoot, isGenerating: isGenerating))
    }

    private func flyerScenePhaseChanged(_ newPhase: ScenePhase) {
        guard newPhase == .active else { return }
        Task { @MainActor in
            await resumePendingFlyerJobIfNeeded()
        }
    }

    private var logoImportBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if #available(iOS 26.0, *) {
                    PhotosPicker(selection: $logoPickerItem, matching: .images) {
                        Label("Choisir le logo", systemImage: "photo.on.rectangle.angled")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: 20))
                    .controlSize(.large)
                } else {
                    PhotosPicker(selection: $logoPickerItem, matching: .images) {
                        Label("Choisir le logo", systemImage: "photo.on.rectangle.angled")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .foregroundStyle(palette.onCanvasPrimary)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    )
                }
                if logoPreview != nil {
                    if #available(iOS 26.0, *) {
                        Button("Effacer") {
                            logoPickerItem = nil
                            logoPreview = nil
                            flyerModel.applyLogoPayload(.clear)
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .controlSize(.regular)
                    } else {
                        Button("Effacer") {
                            logoPickerItem = nil
                            logoPreview = nil
                            flyerModel.applyLogoPayload(.clear)
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                    }
                }
            }
            if let lp = logoPreview {
                Image(uiImage: lp)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 72)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
                    )
            }
        }
    }

    private var referenceAssetsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 12) {
                if #available(iOS 26.0, *) {
                    PhotosPicker(selection: $stylePickerItems, maxSelectionCount: 3, matching: .images) {
                        Label("Inspiration DA (0–3)", systemImage: "square.stack.3d.up")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: 20))
                    .controlSize(.large)
                } else {
                    PhotosPicker(selection: $stylePickerItems, maxSelectionCount: 3, matching: .images) {
                        Label("Inspiration DA (0–3)", systemImage: "square.stack.3d.up")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .foregroundStyle(palette.onCanvasPrimary)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    )
                }
                if !stylePreviews.isEmpty {
                    if #available(iOS 26.0, *) {
                        Button("Effacer") {
                            stylePickerItems = []
                            stylePreviews = []
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .controlSize(.regular)
                    } else {
                        Button("Effacer") {
                            stylePickerItems = []
                            stylePreviews = []
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                    }
                }
            }

            if !stylePreviews.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(stylePreviews.enumerated()), id: \.offset) { _, img in
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }

    @MainActor
    private func syncStylePreviews(from items: [PhotosPickerItem]) async {
        var imgs: [UIImage] = []
        for item in items.prefix(2) {
            if let ui = await FlyerPickerUIImageLoader.load(from: item) {
                imgs.append(ui)
            }
        }
        stylePreviews = imgs
        applyFlyerAccentFromImportedImagesIfAllowed()
    }

    /// Ne pas vider `logoPreview` quand `logoPickerItem` repasse à `nil` : après un import réussi on remettait
    /// `logoPickerItem = nil`, ce qui relançait `onChange` et effaçait l’aperçu immédiatement.
    @MainActor
    private func handleFlyerLogoPick(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        let ui = await FlyerPickerUIImageLoader.load(from: item)
        guard let ui else {
            logoPreview = nil
            logoPickerItem = nil
            return
        }
        /// Vision + PNG transparent hors thread UI (peut prendre ~0,5–2 s).
        let (processed, dataUrl): (UIImage, String?) = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = FlyerLogoBackgroundPrepared.imageForFlyerLogoExport(ui)
                let u = p.flyerLogoPNGDataURLForAI(maxEncodedLength: FlyerDashboardFlyerPrefsLimits.logoPngMaxEncodedUtf8Bytes)
                    ?? ui.normalizedFlyerDataURLForFlyerAI()
                continuation.resume(returning: (p, u))
            }
        }
        logoPreview = processed
        applyFlyerAccentFromImportedImagesIfAllowed()
        if let dataUrl {
            flyerModel.applyLogoPayload(.dataURL(dataUrl))
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
        if let logo = logoPreview { appendFrom(logo) }
        for img in stylePreviews {
            appendFrom(img)
        }
        return ordered
    }

    private func setFlyerPaletteProgrammatically(_ hexes: [String]) {
        let normalized = hexes.compactMap { Self.normalizeHex($0) }
        guard !normalized.isEmpty else { return }
        let capped = Array(normalized.prefix(1))
        isUpdatingAccentFromEngine = true
        defer {
            DispatchQueue.main.async {
                isUpdatingAccentFromEngine = false
            }
        }
        flyerPalettePriorityHexes = capped
    }

    private func applyFlyerAccentFromImportedImagesIfAllowed() {
        guard generatedBase64 == nil else { return }
        guard !flyerAccentUserCustomized else { return }
        guard logoPreview != nil || !stylePreviews.isEmpty else { return }
        let list = collectFlyerImageDistinctHex6List()
        guard !list.isEmpty else { return }
        let withHash = list.prefix(1).map { "#\($0)" }
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
                }
                if !flyerHeroRevealed && !isGenerating {
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
                // Toujours afficher la carte : pendant la génération elle contient `FlyerAIGenerationProgressExperience`
                // (barre + étapes). Avant : `if !isGenerating` masquait toute la carte → aucune barre visible.
                aiPromptComposerCard
            }
            .animation(.spring(response: 0.52, dampingFraction: 0.86), value: flyerHeroRevealed)
        }
    }

    private var flyerPostGenerationPreviewBlock: some View {
        HStack {
            Spacer(minLength: 0)
            Group {
                if isGenerating {
                    FlyerGeneratingHeroPlaceholder(
                        cornerRadius: 20,
                        maxWidth: Self.flyerHeroMaxWidth,
                        aspectRatio: Self.flyerCanvasAspect
                    )
                    .shadow(color: .black.opacity(0.4), radius: 22, y: 12)
                    .modifier(FlyerHeroGenerationLiveMotion(isGenerating: isGenerating))
                    .matchedGeometryEffect(id: "flyerValidateHero", in: flyerValidateMorph)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.9, anchor: .top)),
                            removal: .opacity
                        )
                    )
                } else if let rawBootstrap = effectiveFlyerPreviewBootstrap, !rawBootstrap.isEmpty {
                    /// Fond IA : JSON allégé (sans `custom_bg_data_url`) + UIImage natif sous la WebView (session ou fond serveur décodé).
                    let pair = strippedBootstrapAndUnderlayPair(rawBootstrap: rawBootstrap)
                    let webBootstrap = pair?.bootstrap ?? rawBootstrap
                    let underlay = pair?.underlay
                    ZStack {
                        FlyerGenerationAuthenticCanvasReveal(isGenerating: false) {
                            ZStack {
                                if let u = underlay {
                                    Image(uiImage: u)
                                        .resizable()
                                        .scaledToFit()
                                }
                                FlyerPreviewWebView(
                                    bootstrapBase64: webBootstrap,
                                    isLoading: $flyerInteractiveWebLoading,
                                    skipCanvasSolidBackground: underlay != nil
                                )
                            }
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

    /// Fond type studio : pastel irisé qui respire pendant la génération (inspiré rendu produit).
    private func flyerAIIridescentBackdrop() -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = sin(t * 0.65) * 0.5 + 0.5
            let phase2 = cos(t * 0.48) * 0.5 + 0.5
            ZStack {
                RadialGradient(
                    colors: [
                        Color(red: 0.90, green: 0.62, blue: 0.94).opacity(0.22 + phase * 0.14),
                        Color(red: 0.58, green: 0.76, blue: 0.98).opacity(0.16 + phase2 * 0.12),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.42 + phase * 0.16, y: 0.28 + phase2 * 0.1),
                    startRadius: 24,
                    endRadius: 520
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.75, green: 0.58, blue: 0.98).opacity(0.18 + phase2 * 0.08),
                        Color(red: 0.45, green: 0.82, blue: 0.92).opacity(0.1),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.68 - phase2 * 0.12, y: 0.52 - phase * 0.08),
                    startRadius: 16,
                    endRadius: 440
                )
            }
            .blur(radius: 52)
            .allowsHitTesting(false)
        }
    }

    private var generatedUIImage: UIImage? {
        guard let generatedBase64, let data = Data(base64Encoded: generatedBase64) else { return nil }
        return UIImage(data: data)
    }

    /// PNG de session ou fond enregistré côté serveur — pour underlay + JSON allégé (même rendu que l’aperçu héros).
    private var flyerAiBackgroundUnderlayUIImage: UIImage? {
        if let ui = generatedUIImage { return ui }
        return FlyerDataURLImageDecode.uiImage(fromDataURLString: flyerModel.serverBgDataUrl)
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
                if isGenerating {
                    Color(white: 0.1)
                } else if let b64 = flyerHeroCompositeBootstrap {
                    let heroPair = strippedBootstrapAndUnderlayPair(rawBootstrap: b64)
                    let webB64 = heroPair?.bootstrap ?? b64
                    let heroUnder = heroPair?.underlay
                    FlyerGenerationAuthenticCanvasReveal(isGenerating: false) {
                        ZStack(alignment: .topTrailing) {
                            ZStack {
                                if let u = heroUnder {
                                    Image(uiImage: u)
                                        .resizable()
                                        .scaledToFit()
                                }
                                FlyerPreviewWebView(
                                    bootstrapBase64: webB64,
                                    isLoading: $heroCompositePreviewLoading,
                                    skipCanvasSolidBackground: heroUnder != nil
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
                    }
                } else if let image = generatedUIImage {
                    FlyerGenerationAuthenticCanvasReveal(isGenerating: false) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    }
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

            if isGenerating {
                FlyerGenerationScanOverlay(cornerRadius: corner)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isGenerating)
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.38), radius: 22, y: 11)
        .modifier(FlyerHeroGenerationLiveMotion(isGenerating: isGenerating))
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: generatedBase64)
    }

    private var aiSourceRow: some View {
        HStack(alignment: .top, spacing: 12) {
            FlyerAILogoPhotosPickerSlot(
                selection: $logoPickerItem,
                logoJPEG: logoPreview.flatMap { $0.jpegData(compressionQuality: FlyerAISourcePickerJPEG.quality) }
            )
            FlyerAIStylePhotosPickerSlot(
                selection: $stylePickerItems,
                styleJPEGs: stylePreviews.compactMap { $0.jpegData(compressionQuality: FlyerAISourcePickerJPEG.quality) }
            )
        }
    }

    private var aiPromptComposerCard: some View {
        Group {
            if isGenerating {
                // Pendant la génération : barre + étapes affichées directement sur le fond sombre,
                // sans carte grise, sans bordure, sans ombre.
                FlyerAIGenerationProgressExperience(isGenerating: isGenerating, totalDuration: 70)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    TextField(
                        "",
                        text: $cuisineOrConcept,
                        prompt: Text(generationPromptPlaceholder)
                            .foregroundStyle(FlyerAIEditorTheme.textTertiary),
                        axis: .vertical
                    )
                    .lineLimit(flyerHeroRevealed ? 2...4 : 5...10)
                    .textFieldStyle(.plain)
                    .focused($isPromptFieldFocused)
                    .foregroundStyle(FlyerAIEditorTheme.textPrimary)
                    .tint(FlyerStudioTheme.accent)
                    .padding(14)
                    .frame(minHeight: flyerHeroRevealed ? 76 : 148, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 10) {
                        Divider()
                            .background(FlyerAIEditorTheme.hairline.opacity(0.55))
                            .padding(.horizontal, 14)
                        Text("Couleur du flyer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FlyerAIEditorTheme.textSecondary)
                            .padding(.horizontal, 14)
                        FlyerAIPriorityPaletteRow(
                            orderedHexes: $flyerPalettePriorityHexes,
                            suggestedFromImages: collectFlyerImageDistinctHex6List(),
                            compactEmbedded: true,
                            selectionRingColor: FlyerStudioTheme.accent,
                            maxSlots: 1
                        )
                        .padding(.bottom, 10)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(FlyerAIEditorTheme.promptSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(FlyerAIEditorTheme.hairline, lineWidth: 1)
                )
                .overlay(
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.07), Color.white.opacity(0.02), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 5)
                        Spacer(minLength: 0)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .allowsHitTesting(false)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    /// Barre fixe : génération (saisie complète) ou réessai d’enregistrement si la sauvegarde serveur a échoué — plus de glisser pour valider.
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
            } else if generatedBase64 != nil {
                Button {
                    Task { @MainActor in
                        isPromptFieldFocused = false
                        await validateGeneratedFlyer()
                    }
                } label: {
                    Text("Réessayer l'enregistrement")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.borderedProminent)
                .tint(FlyerStudioTheme.accent)
                .disabled(isGenerating)
                .opacity(isGenerating ? 0.45 : 1)
            } else {
                Button {
                    Task { @MainActor in
                        isPromptFieldFocused = false
                        flyerCreationFreshStart = false
                        withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                            flyerHeroRevealed = true
                        }
                        try? await Task.sleep(nanoseconds: 160_000_000)
                        await runGeneration()
                    }
                } label: {
                    Text("Générer le flyer")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                }
                .buttonStyle(.borderedProminent)
                .tint(FlyerStudioTheme.accent)
                .disabled(!canSubmit || isGenerating)
                .opacity((isGenerating || !canSubmit) ? 0.45 : 1)
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

    private var canSubmit: Bool {
        let quotaOK = flyerUnlimitedEffective || flyerModel.flyerAiGenerationsRemaining > 0
        let paletteOK = flyerPalettePriorityHexes.compactMap { Self.normalizeHex($0) }.isEmpty == false
        return quotaOK
            && !cuisineOrConcept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && paletteOK
    }

    private var generationPromptPlaceholder: String {
        "Décrivez votre concept, produits, ambiance, couleurs…"
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

    private static func defaultConceptLine(sector: String?) -> String {
        let raw = (sector ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let s = raw.lowercased()
        if s.contains("fast") { return "Restauration rapide, vente à emporter" }
        if s.contains("cafe") || s.contains("café") { return "Café, salon de thé, boissons" }
        if s.contains("boulanger") { return "Boulangerie — pâtisserie" }
        if s.contains("beauty") || s.contains("beauté") { return "Institut de beauté, soins" }
        if s.contains("coiff") { return "Salon de coiffure" }
        if raw.isEmpty { return "Commerce de proximité — fidélité et récompenses" }
        return "Commerce — secteur « \(raw) »"
    }

    private func startScanAnimation() {
        /// Animation génération : `FlyerGenerationScanOverlay` + `FlyerHeroGenerationLiveMotion`.
    }

    private func stopScanAnimation() {}

    private func applyFlyerGenerationResult(status: FlyerAIGenerateJobStatusResponseDTO, accent: String, sec: String?) {
        if status.flyerAiUnlimited == true {
            flyerModel.flyerAiUnlimited = true
            flyerModel.flyerAiGenerationsRemaining = 999
        } else if let rem = status.flyerAiGenerationsRemaining {
            flyerModel.flyerAiUnlimited = false
            flyerModel.flyerAiGenerationsRemaining = max(0, rem)
        }
        guard let b64 = status.imageBase64, !b64.isEmpty else { return }
        generatedBase64 = b64
        FlyerPendingBgStorage.shared.save(pngBase64: b64, slug: slug)
        cuisineOrConcept = ""
        var st = flyerModel.state
        st.wheelColorOdd = accent
        st.wheelColorEven = sec ?? "#fef3c7"
        st.colorPrimary = accent
        if let s = sec { st.colorSecondary = s }
        if let top = Self.tintBackgroundTop(fromAccentHex: accent) {
            st.colorBgTop = top
            st.colorBgBottom = Self.darkenHex(top, by: 0.12) ?? top
        }
        st.ctaBannerBgColor = accent
        st.ctaTextColor = FlyerAIWheelPairColor.contrastingOnAccentHex(accent)
        st.headlineGiftStrokeColor = FlyerAIWheelPairColor.contrastingOnAccentHex(accent)
        flyerModel.applyState(st, recordUndo: false)
        flyerCreationFreshStart = false
    }

    /// Reprend un job serveur après fermeture de l’app ou changement d’onglet (polling).
    /// Polling **hors** de l’arborescence de tâches SwiftUI (bouton / `.task`) pour qu’un changement d’onglet n’annule pas le job serveur.
    /// Délègue au coordinateur (polling non annulé par changement d’onglet — voir `respectsTaskCancellation` côté coordinator).
    private func pollFlyerJobInDetachedTask(slug: String, jobId: String) async throws -> FlyerAIGenerateJobStatusResponseDTO {
        try await FlyerAIGenerationCoordinator.shared.pollUntilComplete(
            slug: slug,
            jobId: jobId,
            respectsTaskCancellation: false
        )
    }

    @MainActor
    private func resumePendingFlyerJobIfNeeded() async {
        guard let pending = FlyerAIGenerationCoordinator.shared.peekPending(), pending.slug == slug else { return }
        guard !isGenerating else { return }
        guard !isResumingFlyerJob else { return }
        isResumingFlyerJob = true
        defer { isResumingFlyerJob = false }
        let ordered = flyerPalettePriorityHexes.compactMap { Self.normalizeHex($0) }
        guard let accent = ordered.first else { return }
        let sec: String? = {
            if ordered.count >= 2 { return ordered[1] }
            return Self.normalizeHex(FlyerAIWheelPairColor.evenHex(fromAccentHex: accent))
        }()
        let validatedSnapshot = flyerValidatedOnTab
        errorMessage = nil
        isGenerating = true
        if isTabRoot {
            flyerValidatedOnTab = false
        }
        defer { isGenerating = false }
        do {
            let status = try await pollFlyerJobInDetachedTask(slug: slug, jobId: pending.jobId)
            applyFlyerGenerationResult(status: status, accent: accent, sec: sec)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Validation automatique : plus besoin de glisser pour valider
            await validateGeneratedFlyer()
        } catch {
            if isTabRoot {
                flyerValidatedOnTab = validatedSnapshot
            }
            if case APIError.notFound = error {
                FlyerAIGenerationCoordinator.shared.clearPending()
            }
            errorMessage = flyerGenerationFailureUserMessage(from: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    @MainActor
    private func runGeneration() async {
        errorMessage = nil
        let ordered = flyerPalettePriorityHexes.compactMap { Self.normalizeHex($0) }
        guard let accent = ordered.first else {
            errorMessage = "Ajoutez au moins une couleur valide (#RRVVBB)."
            return
        }
        let sec: String? = {
            if ordered.count >= 2 { return ordered[1] }
            return Self.normalizeHex(FlyerAIWheelPairColor.evenHex(fromAccentHex: accent))
        }()
        let stylePayload: [String]? = {
            let urls = stylePreviews.compactMap { $0.normalizedFlyerDataURLForFlyerAI() }
            return urls.isEmpty ? nil : urls
        }()
        let logoPayload: String? = logoPreview.flatMap {
            $0.flyerLogoPNGDataURLForAI(maxEncodedLength: FlyerDashboardFlyerPrefsLimits.logoPngMaxEncodedUtf8Bytes)
                ?? $0.normalizedFlyerDataURLForFlyerAI()
        }
        let resolvedBrandName = brandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? slug.replacingOccurrences(of: "-", with: " ")
            : brandName.trimmingCharacters(in: .whitespacesAndNewlines)
        let isModification = (generatedBase64?.isEmpty == false)
        let body = FlyerAIGenerateRequestDTO(
            brandName: resolvedBrandName,
            cuisineOrConcept: cuisineOrConcept.trimmingCharacters(in: .whitespacesAndNewlines),
            accentColorHex: accent,
            secondaryColorHex: sec,
            extraContext: isModification ? Self.flyerAIExtraContextLayering : nil,
            paletteColorsHex: ordered,
            logoBase64: logoPayload,
            styleReferenceImagesBase64: stylePayload
        )
        let validatedSnapshot = flyerValidatedOnTab
        isGenerating = true
        if isTabRoot {
            flyerValidatedOnTab = false
        }
        defer { isGenerating = false }
        do {
            let enqueue: FlyerAIGenerateEnqueueResponseDTO = try await APIClient.shared.request(
                .dashboardFlyerAIGenerate(slug: slug, body: body)
            )
            FlyerAIGenerationCoordinator.shared.savePending(slug: slug, jobId: enqueue.jobId)
            let status = try await pollFlyerJobInDetachedTask(slug: slug, jobId: enqueue.jobId)
            applyFlyerGenerationResult(status: status, accent: accent, sec: sec)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            // Validation automatique : plus besoin de glisser pour valider
            await validateGeneratedFlyer()
        } catch {
            if isTabRoot {
                flyerValidatedOnTab = validatedSnapshot
            }
            if case APIError.notFound = error {
                FlyerAIGenerationCoordinator.shared.clearPending()
            }
            errorMessage = flyerGenerationFailureUserMessage(from: error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    /// Rappel côté modèle : le PNG est le fond ; QR / roue / textes sont composés par l’app (pas de z-order « au-dessus du QR » dans ce fichier).
    private static let flyerAIExtraContextLayering =
        "Calques appli : ce visuel est le fond uniquement ; logo, roue, accroche, QR et pied de page sont dessinés par-dessus en positions fixes. Une consigne du type « mettre X au-dessus du QR » ne peut pas être réalisée dans ce PNG : placer mascottes ou sujets sur les marges latérales ou en bandeau haut, jamais sur la zone bas-droite (QR) ni au centre réservé à la roue."

    private func flyerGenerationFailureUserMessage(from error: Error) -> String {
        let base = (error as? APIError)?.errorDescription ?? error.localizedDescription
        return base + "\n\nSi l’opération n’a pas abouti, aucune création n’est décomptée sur votre quota. Le dernier flyer affiché est conservé."
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
        guard generatedBase64 != nil else { return }
        guard !flyerValidatedOnTab, !isGenerating, !isSavingKeep else { return }
        // Attendre que le modèle serveur soit chargé avant de tenter la sauvegarde
        var attempts = 0
        while flyerModel.isLoading, attempts < 30 {
            try? await Task.sleep(nanoseconds: 300_000_000)
            attempts += 1
        }
        guard !flyerValidatedOnTab, !isGenerating, !isSavingKeep else { return }
        await validateGeneratedFlyer()
    }

    /// Quitte le mode « flyer enregistré » compact : formulaire vierge (nouveau prompt / visuels), sans relancer une génération automatiquement.
    private func performFlyerRegenerationFromValidated() async {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if !flyerModel.hasCompletedSuccessfulFlyerLoad {
            await flyerModel.load()
        }
        /// L’aperçu WK ne doit plus réinjecter l’ancien `custom_logo_data_url` du dashboard (clé omise → logo public commerce ou vide selon embed).
        flyerModel.beginFlyerRecreateSessionForPreview()
        cuisineOrConcept = ""
        stylePickerItems = []
        stylePreviews = []
        logoPickerItem = nil
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
        guard let rawBase64 = generatedBase64 else { return }
        isSavingKeep = true
        defer { isSavingKeep = false }
        guard let url = Self.dataURLForFlyerBackgroundPersisting(generatedPNGBase64: rawBase64) else {
            await MainActor.run {
                errorMessage = "Le fond généré est trop lourd ou illisible pour être enregistré. Réessayez une génération."
            }
            return
        }
        if let lp = logoPreview,
           let logoDataUrl = lp.flyerLogoPNGDataURLForAI(maxEncodedLength: FlyerDashboardFlyerPrefsLimits.logoPngMaxEncodedUtf8Bytes)
               ?? lp.normalizedFlyerDataURLForFlyerAI() {
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
                    isPromptFieldFocused = false
                    // On garde generatedBase64 après sauvegarde : sert d’underlay UIImage natif pour le fond IA
                    // (évite la dépendance fragile au JSON WKWebView pour afficher le fond).
                    // generatedBase64 sera effacé au prochain runGeneration() via applyFlyerGenerationResult.
                    FlyerPendingBgStorage.shared.clear(slug: slug)
                    logoPreview = nil
                    logoPickerItem = nil
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

/// Découpage explicite pour le type-checker (Swift 6 / gros `Canvas`).
private enum FlyerGenerationScanParticleDrawing {
    static func draw(into cx: GraphicsContext, size: CGSize, time: TimeInterval) {
        let cols = max(10, Int(size.width / 22))
        let rows = max(16, Int(size.height / 14))
        let cellW = size.width / CGFloat(cols)
        let cellH = size.height / CGFloat(rows)
        let drift = CGFloat(time * 72).truncatingRemainder(dividingBy: cellH * 2)

        var rowIdx = -1
        while rowIdx < rows + 2 {
            var colIdx = 0
            while colIdx < cols {
                let col = CGFloat(colIdx)
                let row = CGFloat(rowIdx)
                let x = col * cellW + cellW * 0.5
                let yRaw = row * cellH + drift
                let y = yRaw.truncatingRemainder(dividingBy: size.height + cellH) - cellH * 0.5

                let wave = sin(time * 4.0 + Double(colIdx) * 0.14 + Double(rowIdx) * 0.07)
                let normalized: Double = wave * 0.5 + 0.5
                let opacity: Double = 0.12 + 0.55 * normalized

                let rect = CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2)
                let p = Path(ellipseIn: rect)
                cx.fill(p, with: .color(Color.white.opacity(opacity)))

                colIdx += 1
            }
            rowIdx += 1
        }
    }
}

/// Points animés sur tout le flyer + pastille « Génération » + **barre de progression** (même fenêtre ~70 s que l’écran du bas).
private struct FlyerGenerationScanOverlay: View {
    let cornerRadius: CGFloat
    /// Aligné sur `FlyerAIGenerationProgressExperience.totalDuration` (estimation visuelle).
    private let totalDuration: TimeInterval = 70

    @State private var sessionStart: Date?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let barWidth = min(w * 0.72, 220)
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    Canvas { cx, size in
                        FlyerGenerationScanParticleDrawing.draw(into: cx, size: size, time: t)
                    }
                    .frame(width: w, height: h)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                VStack(spacing: 10) {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                        let p = overlayProgress(at: context.date)
                        VStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.22))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.65, green: 0.55, blue: 1),
                                                Color(red: 0.45, green: 0.35, blue: 0.96)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(6, barWidth * CGFloat(p)))
                            }
                            .frame(width: barWidth, height: 8)
                            .clipShape(Capsule())

                            HStack {
                                Text("Génération")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                Spacer(minLength: 8)
                                Text("\(Int(round(p * 100)))%")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.92))
                                    .contentTransition(.numericText())
                            }
                            .frame(width: barWidth)
                        }
                    }

                    ProgressView()
                        .controlSize(.regular)
                        .tint(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 14, y: 5)
            }
            .onAppear {
                if sessionStart == nil { sessionStart = Date() }
            }
        }
    }

    private func overlayProgress(at date: Date) -> Double {
        guard let start = sessionStart else { return 0 }
        let elapsed = date.timeIntervalSince(start)
        return min(1, max(0, elapsed / totalDuration))
    }
}

/// Respiration + léger roulis / tangage pendant la génération (TimelineView, pas `repeatForever` sur `@State`).
/// Le canvas réel est masqué pendant l’IA : seul le placeholder neutre est animé.
private struct FlyerHeroGenerationLiveMotion: ViewModifier {
    let isGenerating: Bool

    func body(content: Content) -> some View {
        Group {
            if isGenerating {
                TimelineView(.animation(minimumInterval: 1.0 / 45.0)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let breathe = 1.0 + 0.024 * sin(t * 2.1)
                    let bob = 3.2 * sin(t * 1.85)
                    let tiltX = 3.8 * sin(t * 0.92)
                    let tiltY = 2.6 * sin(t * 1.15)
                    content
                        .scaleEffect(breathe)
                        .rotation3DEffect(
                            .degrees(tiltX),
                            axis: (x: 1, y: 0, z: 0),
                            anchor: .center,
                            anchorZ: 0,
                            perspective: 0.92
                        )
                        .rotation3DEffect(
                            .degrees(tiltY),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .center,
                            anchorZ: 0,
                            perspective: 0.95
                        )
                        .offset(y: bob)
                }
            } else {
                content
            }
        }
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
}

#Preview {
    NavigationStack {
        MerchantProgramHubView(context: PersistenceController.preview.container.viewContext)
            .environmentObject(SyncService(container: PersistenceController.preview.container))
    }
}
