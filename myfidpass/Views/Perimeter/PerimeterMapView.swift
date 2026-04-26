//
//  PerimeterMapView.swift
//  myfidpass
//
//  Carte de l’entreprise avec périmètre de notification (25–100 m, aligné Apple Wallet
//  pour cartes magasin / fidélité).
//

import SwiftUI
import MapKit
import CoreLocation
import CoreData
import Combine
import UIKit

// MARK: - Vue principale

struct PerimeterMapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var syncService: SyncService
    /// Fermeture depuis une feuille (ex. Campagnes) — `nil` quand l’écran est un onglet.
    private let onDismissEmbedded: (() -> Void)?
    @StateObject private var dataService: DataService
    @StateObject private var locationManager = PerimeterLocationManager()

    @State private var locationLat: Double?
    @State private var locationLng: Double?
    @State private var locationAddress: String = ""
    @State private var radiusMeters: Int = 100
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var saveSuccess = false
    @State private var errorMessage: String?
    @State private var cameraPosition: MapCameraPosition = .automatic
    /// Dernière caméra connue (gestes + programme) pour boussole / 2D–3D / recadrage.
    @State private var lastMapCamera: MapCamera?
    @State private var isGeocoding = false
    @State private var contentAppeared = false
    /// Message envoyé aux clients qui entrent dans le périmètre (pass Wallet / notification).
    @State private var perimeterMessage: String = ""
    /// Feuille d’édition (même gabarit que la personnalisation carte Wallet).
    @State private var showPerimeterSheet = false
    /// Données modifiées mais pas encore enregistrées.
    @State private var hasUnsavedChanges = false

    /// Apple Wallet (carte fidélité) : pertinence ~100 m max ; 25–100 m côté produit.
    private let radiusRange = 25...100
    private var hasLocation: Bool { locationLat != nil && locationLng != nil }
    private var businessCoordinate: CLLocationCoordinate2D? {
        guard let lat = locationLat, let lng = locationLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Style carte : 3D réaliste, thème sombre via l’environnement (sans .muted pour garder la carte lisible).
    private var standardMapStyle: MapStyle {
        .standard(elevation: .realistic)
    }

    private var dashboardPalette: DashboardRevolutPalette {
        DashboardRevolutPalette(colorScheme: colorScheme)
    }

    /// Libellé 2D / 3D aligné sur le comportement du `MapPitchToggle` système.
    private var isMapPitch3D: Bool {
        let pitch = lastMapCamera?.pitch ?? (hasLocation ? 55 : 0)
        return pitch >= 30
    }

    /// Boussole / 2D–3D : besoin d’une caméra connue ou d’un commerce géolocalisé.
    private var canUseMapOrientationChrome: Bool {
        lastMapCamera != nil || hasLocation
    }

    init(context: NSManagedObjectContext, onDismissEmbedded: (() -> Void)? = nil) {
        self.onDismissEmbedded = onDismissEmbedded
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mapLayer
                    .ignoresSafeArea(edges: .all)
                bottomBar
            }
            .overlay(alignment: .topLeading) {
                if let onDismissEmbedded {
                    DashboardHomeGlassIconButton(
                        palette: dashboardPalette,
                        systemName: "xmark",
                        iconPointSize: 15,
                        accessibilityLabel: "Fermer la carte",
                        action: onDismissEmbedded
                    )
                    .padding(.top, 54)
                    .padding(.leading, 12)
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task { await loadSettings() }
            .refreshable { await loadSettings() }
            .alert("Erreur", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
            .opacity(contentAppeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: contentAppeared)
        }
        .sheet(isPresented: $showPerimeterSheet) {
            PerimeterEditorSheet(
                locationAddress: $locationAddress,
                radiusMeters: $radiusMeters,
                perimeterMessage: $perimeterMessage,
                locationLat: $locationLat,
                locationLng: $locationLng,
                isGeocoding: $isGeocoding,
                isSaving: $isSaving,
                saveSuccess: $saveSuccess,
                hasUnsavedChanges: $hasUnsavedChanges,
                radiusRange: radiusRange,
                locationManager: locationManager,
                onGeocode: { geocodeAddress($0) },
                onUseLocation: useMyLocation,
                onSave: { await saveLocation() },
                onDismiss: { showPerimeterSheet = false }
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { contentAppeared = true }
        }
    }

    // MARK: - Carte

    private var mapLayer: some View {
        Group {
            if let center = businessCoordinate {
                Map(position: $cameraPosition, interactionModes: .all) {
                    Annotation("Commerce", coordinate: center) {
                        pinView
                    }
                    MapCircle(center: center, radius: CLLocationDistance(radiusMeters))
                        .foregroundStyle(AppTheme.Colors.primary.opacity(0.2))
                        .stroke(AppTheme.Colors.primary, lineWidth: 2)
                }
                .mapStyle(standardMapStyle)
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: 52)
                }
                .mapControls {
                    MapScaleView()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    lastMapCamera = context.camera
                }
            } else {
                Map(position: $cameraPosition, interactionModes: .all)
                    .mapStyle(standardMapStyle)
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Color.clear.frame(height: 52)
                    }
                    .mapControls {
                        MapScaleView()
                    }
                    .overlay {
                        emptyMapOverlay
                    }
                    .onMapCameraChange(frequency: .onEnd) { context in
                        lastMapCamera = context.camera
                    }
            }
        }
        .overlay(alignment: .topTrailing) {
            mapFloatingGlassControls
                .padding(.top, 56)
                .padding(.trailing, 12)
        }
        .animation(.easeInOut(duration: 0.35), value: hasLocation)
    }

    /// Contrôles carte en Liquid Glass (même principe que profil / accueil : `DashboardHomeGlassIconButton`).
    private var mapFloatingGlassControls: some View {
        VStack(alignment: .trailing, spacing: 8) {
            DashboardHomeGlassIconButton(
                palette: dashboardPalette,
                systemName: "location.north.fill",
                iconPointSize: 17,
                accessibilityLabel: "Orientation nord",
                action: { resetMapNorthUp() }
            )
            .disabled(!canUseMapOrientationChrome)
            .opacity(canUseMapOrientationChrome ? 1 : 0.45)

            PerimeterMapPitchGlassButton(
                palette: dashboardPalette,
                is3D: isMapPitch3D,
                action: { toggleMapPitch() }
            )
            .disabled(!canUseMapOrientationChrome)
            .opacity(canUseMapOrientationChrome ? 1 : 0.45)

            DashboardHomeGlassIconButton(
                palette: dashboardPalette,
                systemName: "location.fill",
                iconPointSize: 17,
                accessibilityLabel: "Ma position",
                action: { centerMapOnUserLocation() }
            )
        }
    }

    private var pinView: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.Colors.primary)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            Image(systemName: "triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Colors.primary)
                .offset(y: -6)
        }
    }

    private var emptyMapOverlay: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "map.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.6))
            Text("Définissez l’emplacement de votre commerce")
                .font(AppTheme.Fonts.headline())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background.opacity(0.85))
    }

    // MARK: - Barre bas (minimal)

    private var bottomBar: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if isLoading {
                ProgressView()
                    .padding(AppTheme.Spacing.md)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if hasLocation {
                Button {
                    showPerimeterSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.Colors.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(locationAddress.isEmpty ? "Commerce" : locationAddress)
                                .font(AppTheme.Fonts.subheadline().weight(.medium))
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                            Text("\(radiusMeters) m")
                                .font(AppTheme.Fonts.caption())
                                .foregroundStyle(Color.secondary)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showPerimeterSheet = true
                } label: {
                    Label("Définir l’emplacement", systemImage: "mappin.and.ellipse")
                        .font(AppTheme.Fonts.subheadline().weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.xs)
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: hasLocation)
    }

    // MARK: - Actions

    private func loadSettings() async {
        var slug = AuthStorage.currentBusinessSlug
        if slug == nil, AuthStorage.isLoggedIn {
            await syncService.syncAfterServerMutation()
            slug = AuthStorage.currentBusinessSlug
        }
        guard let slug else {
            await MainActor.run {
                isLoading = false
                errorMessage = "Commerce non chargé. Actualisez le tableau de bord."
            }
            return
        }
        do {
            let settings = try await APIClient.shared.request(APIEndpoint.businessSettings(slug: slug)) as BusinessSettingsResponse
            await MainActor.run {
                var r = settings.locationRadiusMeters ?? 500
                r = min(max(r, radiusRange.lowerBound), radiusRange.upperBound)
                radiusMeters = r
                locationAddress = settings.locationAddress ?? ""
                perimeterMessage = settings.locationRelevantText ?? ""
                if let lat = settings.locationLat, let lng = settings.locationLng {
                    locationLat = lat
                    locationLng = lng
                    updateCameraAndRegion()
                } else {
                    locationLat = nil
                    locationLng = nil
                    let addr = locationAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !addr.isEmpty {
                        geocodeAddress(addr)
                    }
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = (error as? APIError)?.errorDescription ?? "Impossible de charger les paramètres."
            }
        }
    }

    private func updateCameraAndRegion() {
        guard let lat = locationLat, let lng = locationLng else { return }
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let cameraDistance = max(400, CLLocationDistance(radiusMeters) * 4.5)
        let camera = MapCamera(centerCoordinate: center, distance: cameraDistance, heading: 0, pitch: 55)
        cameraPosition = .camera(camera)
    }

    /// Caméra de secours quand l’utilisateur n’a pas encore déclenché `onMapCameraChange`.
    private func fallbackMapCamera() -> MapCamera? {
        guard let lat = locationLat, let lng = locationLng else { return nil }
        let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let cameraDistance = max(400, CLLocationDistance(radiusMeters) * 4.5)
        return MapCamera(centerCoordinate: center, distance: cameraDistance, heading: 0, pitch: 55)
    }

    private func resetMapNorthUp() {
        let base = lastMapCamera ?? fallbackMapCamera()
        guard let base else { return }
        let newCam = MapCamera(
            centerCoordinate: base.centerCoordinate,
            distance: base.distance,
            heading: 0,
            pitch: base.pitch
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .camera(newCam)
        }
    }

    private func toggleMapPitch() {
        let base = lastMapCamera ?? fallbackMapCamera()
        guard let base else { return }
        let newPitch: CGFloat = base.pitch < 30 ? 55 : 0
        let newCam = MapCamera(
            centerCoordinate: base.centerCoordinate,
            distance: base.distance,
            heading: base.heading,
            pitch: newPitch
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .camera(newCam)
        }
    }

    /// Recentre la vue carte sur la position GPS (sans modifier l’adresse enregistrée du commerce).
    private func centerMapOnUserLocation() {
        let dist = lastMapCamera?.distance ?? max(400, CLLocationDistance(radiusMeters) * 4.5)
        let pitch = lastMapCamera?.pitch ?? 55
        let heading = lastMapCamera?.heading ?? 0
        locationManager.requestLocation { coordinate in
            let cam = MapCamera(
                centerCoordinate: coordinate,
                distance: max(400, dist),
                heading: heading,
                pitch: pitch
            )
            withAnimation(.easeInOut(duration: 0.35)) {
                cameraPosition = .camera(cam)
            }
        }
    }

    private func geocodeAddress(_ address: String) {
        guard !address.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isGeocoding = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        let search = MKLocalSearch(request: request)
        search.start { [self] response, _ in
            DispatchQueue.main.async {
                isGeocoding = false
                guard let item = response?.mapItems.first else {
                    errorMessage = "Adresse introuvable."
                    return
                }
                let coord = item.mf_searchCoordinate
                withAnimation(.easeInOut(duration: 0.3)) {
                    locationLat = coord.latitude
                    locationLng = coord.longitude
                    hasUnsavedChanges = true
                    updateCameraAndRegion()
                }
            }
        }
    }

    private func useMyLocation() {
        locationManager.requestLocation { [self] coordinate in
            withAnimation(.easeInOut(duration: 0.3)) {
                locationLat = coordinate.latitude
                locationLng = coordinate.longitude
                locationAddress = "Position actuelle"
                hasUnsavedChanges = true
                updateCameraAndRegion()
            }
            locationManager.reverseGeocode(coordinate: coordinate) { address in
                DispatchQueue.main.async {
                    if let a = address, !a.isEmpty { locationAddress = a }
                }
            }
        }
    }

    private func saveLocation() async {
        guard let slug = AuthStorage.currentBusinessSlug, let lat = locationLat, let lng = locationLng else {
            errorMessage = "Emplacement non défini ou commerce non chargé."
            return
        }
        isSaving = true
        saveSuccess = false
        do {
            _ = try await APIClient.shared.request(APIEndpoint.updateLocationSettings(
                slug: slug,
                locationLat: lat,
                locationLng: lng,
                locationRadiusMeters: radiusMeters,
                locationRelevantText: perimeterMessage.trimmingCharacters(in: .whitespaces).isEmpty ? nil : perimeterMessage.trimmingCharacters(in: .whitespaces),
                locationAddress: locationAddress.isEmpty ? nil : locationAddress,
                walletPassIncludeLocations: true
            )) as EmptyResponse
            await MainActor.run {
                isSaving = false
                hasUnsavedChanges = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    saveSuccess = true
                    showPerimeterSheet = false
                }
                if let b = dataService.currentBusiness() { b.address = locationAddress }
                try? viewContext.save()
            }
            await syncService.syncAfterServerMutation()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run { saveSuccess = false }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = (error as? APIError)?.errorDescription ?? "Enregistrement impossible."
            }
        }
    }
}

// MARK: - Bouton 2D / 3D (Liquid Glass comme « Réglages » sur le profil)

private struct PerimeterMapPitchGlassButton: View {
    let palette: DashboardRevolutPalette
    /// `true` si la carte est en perspective (équivalent affichage « 2D » sur le bouton système).
    let is3D: Bool
    let action: () -> Void

    var body: some View {
        let label = is3D ? "2D" : "3D"
        Group {
            if #available(iOS 26.0, *) {
                Button(action: action) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.onCanvasPrimary)
                        .frame(minWidth: 44, minHeight: 40)
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.capsule)
            } else {
                Button(action: action) {
                    Text(label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.onCanvasPrimary.opacity(0.95))
                        .frame(minWidth: 44, minHeight: 40)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(palette.searchFieldStroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityLabel(is3D ? "Passer en vue 2D" : "Passer en vue 3D")
    }
}

// MARK: - Feuille d’édition (gabarit type carte Wallet)

private struct PerimeterEditorSheet: View {
    @Binding var locationAddress: String
    @Binding var radiusMeters: Int
    @Binding var perimeterMessage: String
    @Binding var locationLat: Double?
    @Binding var locationLng: Double?
    @Binding var isGeocoding: Bool
    @Binding var isSaving: Bool
    @Binding var saveSuccess: Bool
    @Binding var hasUnsavedChanges: Bool

    let radiusRange: ClosedRange<Int>
    @ObservedObject var locationManager: PerimeterLocationManager

    var onGeocode: (String) -> Void
    var onUseLocation: () -> Void
    var onSave: () async -> Void
    var onDismiss: () -> Void

    private var hasLocation: Bool { locationLat != nil && locationLng != nil }

    private var perimeterSheetHeaderRow: some View {
        HStack(alignment: .center, spacing: 8) {
            if #available(iOS 26.0, *) {
                Button("Fermer", action: onDismiss)
                    .buttonStyle(.glass(.regular))
                    .buttonBorderShape(.capsule)
                    .controlSize(.regular)
            } else {
                Button("Fermer", action: onDismiss)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            }
            Spacer(minLength: 8)
            Text("Périmètre")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer(minLength: 8)
            if #available(iOS 26.0, *) {
                Button {
                    Task {
                        guard !isSaving, hasLocation else { return }
                        await onSave()
                    }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else if saveSuccess {
                            Image(systemName: "checkmark.circle.fill")
                        } else {
                            Text("Enregistrer")
                        }
                    }
                }
                .disabled(isSaving || !hasLocation)
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.capsule)
                .controlSize(.regular)
                .tint(AppTheme.Colors.primary)
            } else {
                Button {
                    Task {
                        guard !isSaving, hasLocation else { return }
                        await onSave()
                    }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else if saveSuccess {
                            Image(systemName: "checkmark.circle.fill")
                        } else {
                            Text("Enregistrer")
                        }
                    }
                }
                .disabled(isSaving || !hasLocation)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            }
        }
        .padding(.bottom, 4)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    perimeterSheetHeaderRow
                    if !hasLocation {
                        Text("Recherchez une adresse ou utilisez votre position pour placer le commerce sur la carte.")
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    AddressSearchField(
                        text: $locationAddress,
                        placeholder: "Adresse du commerce…",
                        appearance: .standard,
                        onSelect: { address in
                            locationAddress = address
                            hasUnsavedChanges = true
                            onGeocode(address)
                        }
                    )

                    Button {
                        onUseLocation()
                    } label: {
                        HStack(spacing: 8) {
                            if locationManager.isRequesting {
                                ProgressView()
                                    .scaleEffect(0.85)
                                    .tint(Color.primary)
                            } else {
                                Image(systemName: "location.fill")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Text(locationManager.isRequesting ? "Localisation…" : "Utiliser ma position")
                                .font(AppTheme.Fonts.subheadline().weight(.medium))
                        }
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                    }
                    .disabled(locationManager.isRequesting || isGeocoding)

                    if isGeocoding {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(Color.primary)
                            Text("Recherche de l’adresse…")
                                .font(AppTheme.Fonts.caption())
                                .foregroundStyle(Color.secondary)
                        }
                    }

                    if hasLocation {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Rayon")
                                    .font(AppTheme.Fonts.caption())
                                    .foregroundStyle(Color.secondary)
                                Spacer(minLength: 8)
                                Text("\(radiusMeters) m")
                                    .font(AppTheme.Fonts.subheadline().weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.primary)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(radiusMeters) },
                                    set: { newVal in
                                        let stepped = (newVal / 5).rounded() * 5
                                        radiusMeters = Int(min(max(stepped, Double(radiusRange.lowerBound)), Double(radiusRange.upperBound)))
                                        hasUnsavedChanges = true
                                    }
                                ),
                                in: Double(radiusRange.lowerBound)...Double(radiusRange.upperBound),
                                step: 5
                            )
                            .tint(AppTheme.Colors.primary)
                        }
                        .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Message aux clients dans le périmètre")
                                .font(AppTheme.Fonts.caption())
                                .foregroundStyle(Color.secondary)
                            TextField("Ex : Passez nous voir, offre spéciale aujourd’hui !", text: $perimeterMessage, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(AppTheme.Fonts.subheadline())
                                .padding(10)
                                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
                                .foregroundStyle(Color.primary)
                                .lineLimit(3...5)
                                .onChange(of: perimeterMessage) { _, _ in hasUnsavedChanges = true }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, 16)
                .padding(.bottom, 28)
            }
            .background(AppTheme.Colors.background)
            .sheetHideNavigationBar()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .modifier(LiquidGlassSheetModifier())
        .onChange(of: locationLat) { _, _ in hasUnsavedChanges = true }
        .onChange(of: locationLng) { _, _ in hasUnsavedChanges = true }
    }
}

// MARK: - Gestionnaire de localisation

private final class PerimeterLocationManager: NSObject, ObservableObject {
    private let manager = CLLocationManager()
    @Published var isRequesting = false
    private var locationContinuation: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation(completion: @escaping (CLLocationCoordinate2D) -> Void) {
        guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else {
            isRequesting = true
            manager.requestWhenInUseAuthorization()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.performRequest(completion: completion)
            }
            return
        }
        performRequest(completion: completion)
    }

    private func performRequest(completion: @escaping (CLLocationCoordinate2D) -> Void) {
        isRequesting = true
        manager.requestLocation()
        locationContinuation = completion
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D, completion: @escaping (String?) -> Void) {
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if #available(iOS 26.0, *) {
            reverseGeocodeMapKit26(location: loc, completion: completion)
        } else {
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(loc) { placemarks, _ in
                let text = placemarks?.first.flatMap { Self.shortAddressLabel(from: $0) }
                DispatchQueue.main.async { completion(text) }
            }
        }
    }

    private static func shortAddressLabel(from placemark: CLPlacemark) -> String? {
        if let name = placemark.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        let parts = [placemark.thoroughfare, placemark.locality, placemark.administrativeArea]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let joined = parts.joined(separator: ", ")
        return joined.isEmpty ? nil : joined
    }
}

@available(iOS 26.0, *)
private extension PerimeterLocationManager {
    func reverseGeocodeMapKit26(location: CLLocation, completion: @escaping (String?) -> Void) {
        guard let request = MKReverseGeocodingRequest(location: location) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }
        Task {
            let items = try? await request.mapItems
            let trimmed = items?.first?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let address = trimmed.isEmpty ? nil : trimmed
            await MainActor.run { completion(address) }
        }
    }
}

extension PerimeterLocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isRequesting = false
        guard let loc = locations.last else { return }
        locationContinuation?(loc.coordinate)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isRequesting = false
        locationContinuation = nil
    }
}

// MARK: - Preview

#Preview {
    PerimeterMapView(context: PersistenceController.preview.container.viewContext)
        .environmentObject(SyncService(container: PersistenceController.preview.container))
}
