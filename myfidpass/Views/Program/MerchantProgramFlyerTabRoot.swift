//
//  MerchantProgramFlyerTabRoot.swift
//  myfidpass — extrait de MerchantProgramHubView.swift
//

import SwiftUI
import UIKit

// MARK: - Racine onglet Flyer (IA + éditeur)

@MainActor
struct ProgramFlyerTabRoot: View {
    let slug: String
    let palette: DashboardRevolutPalette
    let seedRecreateFlyer: Bool
    let seedOpenFlyerForEdit: Bool
    let startInCreateFromEditBack: Bool
    let liveCommerceSnapshot: CommerceFlyerLiveSnapshot?
    let onFlyerSaveSuccessReturnToCommerce: (() -> Void)?
    let onBackFromModifyToCreateFlyer: (() -> Void)?
    let onBackFromModifyToYourFlyerPreview: (() -> Void)?
    let onExitFlyerHubPopCommerce: (() -> Void)?
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
        onBackFromModifyToCreateFlyer: (() -> Void)? = nil,
        onBackFromModifyToYourFlyerPreview: (() -> Void)? = nil,
        onExitFlyerHubPopCommerce: (() -> Void)? = nil
    ) {
        self.slug = slug
        self.palette = palette
        self.seedRecreateFlyer = seedRecreateFlyer
        self.seedOpenFlyerForEdit = seedOpenFlyerForEdit
        self.startInCreateFromEditBack = startInCreateFromEditBack
        self.liveCommerceSnapshot = liveCommerceSnapshot
        self.onFlyerSaveSuccessReturnToCommerce = onFlyerSaveSuccessReturnToCommerce
        self.onBackFromModifyToCreateFlyer = onBackFromModifyToCreateFlyer
        self.onBackFromModifyToYourFlyerPreview = onBackFromModifyToYourFlyerPreview
        self.onExitFlyerHubPopCommerce = onExitFlyerHubPopCommerce
        let tryDraft = !seedRecreateFlyer
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
            onBackFromModifyToCreateFlyer: onBackFromModifyToCreateFlyer,
            onBackFromModifyToYourFlyerPreview: onBackFromModifyToYourFlyerPreview,
            onExitFlyerHubPopCommerce: onExitFlyerHubPopCommerce
        )
        .onChange(of: scenePhase) { _, new in
            if new == .background { model.persistUnsavedFlyerSessionDraftIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            model.persistUnsavedFlyerSessionDraftIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassMatchPredictionsConfigDidSave)) { note in
            guard let s = note.userInfo?["slug"] as? String, s == slug else { return }
            if let on = note.userInfo?["enabled"] as? Bool {
                model.applyMatchPredictionsEnabledForPreview(on)
            }
            Task { await model.load(showProgress: false) }
        }
        .task(id: slug) {
            if seedRecreateFlyer {
                CommerceFlyerEditorDraftStore.clear(slug: slug)
                await model.load(showProgress: true, forceFullFlyerPrefsMerge: true)
            } else if model.usesInstantCommerceAlignedBootstrap {
                Task { @MainActor in
                    await model.load(showProgress: false)
                }
            } else {
                await model.load(
                    showProgress: !model.hasCompletedSuccessfulFlyerLoad,
                    forceFullFlyerPrefsMerge: true
                )
            }
        }
    }
}
