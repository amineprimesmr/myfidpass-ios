//
//  MerchantSetupChecklistSection.swift
//  myfidpass
//
//  Checklist « lancement » (commerce, carte, flyer, affichage) — alignée sur le SaaS web.
//

import SwiftUI
import UIKit

struct MerchantSetupProgress: Equatable {
    var commerceDone: Bool
    var cardDone: Bool
    var flyerDone: Bool
    var printDone: Bool
    var doneCount: Int
    var total: Int

    var allDone: Bool {
        commerceDone && cardDone && flyerDone && printDone
    }

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(doneCount) / Double(total)
    }
}

enum MerchantSetupProgressCalculator {
    /// Même clé que le web (`localStorage`) pour l’accusé « flyer affiché ».
    static func flyerDisplayedStorageKey(slug: String) -> String {
        "fidpass_merchant_setup_flyer_ok:\(slug.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    /// Déconnexion / nouveau compte : sans ça, un slug réutilisé garde l’accusé « flyer affiché » de l’ancien commerce.
    static func clearAllFlyerDisplayedAcknowledgementsFromUserDefaults() {
        let prefix = "fidpass_merchant_setup_flyer_ok:"
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }

    static func compute(
        settings: BusinessSettingsResponse?,
        slug: String,
        flyerLooksCustomized: Bool,
    ) -> MerchantSetupProgress {
        let s = settings
        let org = (s?.organizationName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let addr = (s?.locationAddress ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let lat = s?.locationLat
        let lng = s?.locationLng
        let hasCoords =
            (lat.map { $0.isFinite } == true)
            && (lng.map { $0.isFinite } == true)
        let commerceDone = org.count >= 2 && (addr.count >= 5 || hasCoords)

        let logo = (s?.logoUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let cardDone = !logo.isEmpty
            || (s?.hasCardBackground == true)
            || (s?.hasStampIcon == true)

        let flyerDone = flyerLooksCustomized

        let key = flyerDisplayedStorageKey(slug: slug)
        let printDone = UserDefaults.standard.string(forKey: key) == "1"

        let flags = [commerceDone, cardDone, flyerDone, printDone]
        let doneCount = flags.filter { $0 }.count
        return MerchantSetupProgress(
            commerceDone: commerceDone,
            cardDone: cardDone,
            flyerDone: flyerDone,
            printDone: printDone,
            doneCount: doneCount,
            total: 4,
        )
    }

    static func flyerLooksCustomizedFromDisk(slug: String) -> Bool {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return false }
        CommerceFlyerStore.shared.hydrateFromDiskIfNeeded(slug: s)
        guard let snap = CommerceFlyerStore.shared.snapshot(for: s) else { return false }
        let hasBootstrap = !(snap.bootstrapPreviewB64 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCustomBg = !(snap.customBgDataURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return snap.flyerRegistered || hasBootstrap || hasCustomBg
    }
}

// MARK: - UI

struct MerchantSetupChecklistSection: View {
    let progress: MerchantSetupProgress
    let businessSlug: String
    var onAckPrint: () -> Void

    @State private var celebrateAllDone = false
    @Environment(\.colorScheme) private var colorScheme

    /// Première étape encore à faire (1…4). Toutes complétées → `nil`.
    private var currentOpenStepIndex: Int? {
        if !progress.commerceDone { return 1 }
        if !progress.cardDone { return 2 }
        if !progress.flyerDone { return 3 }
        if !progress.printDone { return 4 }
        return nil
    }

    var body: some View {
        GroupedSettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                header
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(UIColor.tertiarySystemFill))
                        Capsule()
                            .fill(AppTheme.Colors.primary.opacity(colorScheme == .dark ? 0.92 : 1))
                            .frame(width: max(8, geo.size.width * progress.progress))
                    }
                }
                .frame(height: 6)
                .accessibilityHidden(true)

                VStack(spacing: 0) {
                    stepRow(
                        index: 1,
                        title: "Connecter votre commerce",
                        done: progress.commerceDone,
                        buttonTitle: "Ouvrir Mon commerce",
                    ) {
                        openCommerceSetup()
                    }
                    GroupedSettingsRowDivider()
                    stepRow(
                        index: 2,
                        title: "Personnaliser la carte de fidélité",
                        done: progress.cardDone,
                        buttonTitle: "Ouvrir Ma carte",
                    ) {
                        openMyCardFromHome()
                    }
                    GroupedSettingsRowDivider()
                    stepRow(
                        index: 3,
                        title: "Créer le flyer de jeu",
                        done: progress.flyerDone,
                        buttonTitle: "Créer le flyer",
                    ) {
                        openFlyerHubFromHome(startCreateAssistant: true)
                    }
                    GroupedSettingsRowDivider()
                    printStepBlock
                }
            }
            .padding(.vertical, 8)
        }
        .scaleEffect(celebrateAllDone ? 1.02 : 1)
        .animation(.spring(response: 0.42, dampingFraction: 0.62), value: celebrateAllDone)
        .onChange(of: progress.allDone) { wasDone, isDone in
            guard !wasDone, isDone else { return }
            celebrateAllDone = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                celebrateAllDone = false
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Votre lancement")
                        .font(.headline.weight(.semibold))
                    if !progress.allDone {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 9, height: 9)
                            .accessibilityHidden(true)
                    }
                }
                Spacer(minLength: 8)
                Text("\(progress.doneCount) / \(progress.total) étapes")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text("Complétez ces étapes pour activer toute l’expérience.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
        .padding(.top, GroupedSettingsMetrics.rowVerticalPadding)
    }

    private func stepRow(
        index: Int,
        title: String,
        done: Bool,
        buttonTitle: String,
        primary: @escaping () -> Void,
    ) -> some View {
        let isActiveStep = !done && currentOpenStepIndex == index
        let isLockedFuture = !done && (currentOpenStepIndex.map { index > $0 } ?? false)

        return HStack(alignment: .top, spacing: 12) {
            stepBadge(index: index, done: done)
                .animation(.spring(response: 0.32, dampingFraction: 0.75), value: done)

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(done ? .secondary : (isLockedFuture ? Color(UIColor.tertiaryLabel) : .primary))
                    .strikethrough(done, color: Color(UIColor.tertiaryLabel))

                if isActiveStep {
                    Button(action: primary) {
                        Text(buttonTitle)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .liquidGlassButtonAppearance(.adaptive, cornerRadius: 12)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
    }

    @ViewBuilder
    private func stepBadge(index: Int, done: Bool) -> some View {
        if done {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.success)
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Étape validée")
        } else {
            ZStack {
                Circle()
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(width: 28, height: 28)
                Text("\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var printStepBlock: some View {
        let done = progress.printDone
        let isActive = !done && currentOpenStepIndex == 4
        let isLockedFuture = !done && (currentOpenStepIndex.map { 4 > $0 } ?? false)

        return HStack(alignment: .top, spacing: 12) {
            stepBadge(index: 4, done: done)
                .animation(.spring(response: 0.32, dampingFraction: 0.75), value: done)

            VStack(alignment: .leading, spacing: 10) {
                Text("Imprimer et afficher le flyer")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(done ? .secondary : (isLockedFuture ? Color(UIColor.tertiaryLabel) : .primary))
                    .strikethrough(done, color: Color(UIColor.tertiaryLabel))

                if isActive {
                    HStack(spacing: 10) {
                        Button {
                            openFlyerHubFromHome()
                        } label: {
                            Text("Télécharger")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .liquidGlassButtonAppearance(.adaptive, cornerRadius: 12)
                        .controlSize(.small)

                        Button {
                            let key = MerchantSetupProgressCalculator.flyerDisplayedStorageKey(slug: businessSlug)
                            UserDefaults.standard.set("1", forKey: key)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            NotificationCenter.default.post(name: .myfidpassMerchantSetupProgressUpdated, object: nil)
                            onAckPrint()
                        } label: {
                            Text("C’est affiché ✓")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .liquidGlassButtonAppearance(.regularTint(AppTheme.Colors.primary), cornerRadius: 12)
                        .controlSize(.small)
                        .foregroundStyle(.white)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
    }

    private func dismissSettingsAndRun(_ body: @escaping () -> Void) {
        NotificationCenter.default.post(name: .myfidpassCloseGlobalSettingsSheet, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            body()
        }
    }

    private func openCommerceSetup() {
        dismissSettingsAndRun {
            NotificationCenter.default.post(name: .myfidpassSelectMerchantHomeTab, object: nil)
        }
    }

    private func openMyCardFromHome() {
        dismissSettingsAndRun {
            NotificationCenter.default.post(name: .myfidpassSelectMerchantHomeTab, object: nil)
            NotificationCenter.default.post(name: .myfidpassOpenHomeMyCardFullScreen, object: nil)
        }
    }

    /// - Parameter startCreateAssistant: étape 3 checklist — forcer l’assistant **Créer le flyer** (évite « Votre flyer » si brouillon disque).
    private func openFlyerHubFromHome(startCreateAssistant: Bool = false) {
        dismissSettingsAndRun {
            NotificationCenter.default.post(name: .myfidpassSelectMerchantHomeTab, object: nil)
            var info: [AnyHashable: Any]? = nil
            if startCreateAssistant {
                info = [MyfidpassNotificationUserInfoKey.flyerHubStartCreateAssistant: true]
            }
            NotificationCenter.default.post(name: .myfidpassOpenMerchantFlyerHub, object: nil, userInfo: info)
        }
    }
}
