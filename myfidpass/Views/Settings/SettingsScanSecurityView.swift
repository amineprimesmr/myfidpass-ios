//
//  SettingsScanSecurityView.swift
//  myfidpass
//
//  Plafonds anti-fraude : passages / jour / client et points max par crédit (serveur).
//

import SwiftUI

struct SettingsScanSecurityView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var syncService: SyncService

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var maxPassesPerDay: Int = 0
    @State private var maxPointsPerTransaction: Int = 0
    @State private var requireReceiptQr: Bool = false
    @State private var receiptToleranceCents: Int = 5
    @State private var isSaving = false
    @State private var saveNotice: String?
    @State private var saveError: String?

    private var theme: SettingsVisualTheme { SettingsVisualTheme(colorScheme: colorScheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GroupedSettingsMetrics.interCardSpacing) {
                if let notice = saveNotice {
                    Text(notice)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.accentPositive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(theme.noticeBG)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if let err = loadError ?? saveError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Color(UIColor.systemRed).opacity(colorScheme == .dark ? 0.95 : 1))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.systemRed).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                GroupedSettingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        stepperRow(
                            title: "Passages max par client et par jour",
                            value: $maxPassesPerDay,
                            range: 0...999
                        )
                        GroupedSettingsRowDivider()
                        stepperRow(
                            title: "Points max par opération",
                            value: $maxPointsPerTransaction,
                            range: 0...999_999
                        )
                    }
                    .padding(.vertical, 4)
                }

                GroupedSettingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(isOn: $requireReceiptQr) {
                            Text("Validation par ticket de caisse")
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color(UIColor.label))
                        }
                        .tint(AppTheme.Colors.primary)
                        if requireReceiptQr {
                            GroupedSettingsRowDivider()
                            stepperRow(
                                title: "Tolérance montant (centimes)",
                                value: $receiptToleranceCents,
                                range: 0...500
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        if isSaving { ProgressView().tint(.white) }
                        Text(isSaving ? "Enregistrement…" : "Enregistrer")
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.Colors.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(isSaving || isLoading)
            }
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(GroupedSettingsMetrics.pageBackground)
        .navigationTitle("Sécurité caisse")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
    }

    private func stepperRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(Color(UIColor.label))
            Stepper(value: value, in: range) {
                Text(value.wrappedValue == 0 ? "Illimité" : "\(value.wrappedValue)")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(Color(UIColor.label))
            }
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
    }

    private func load() async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            await MainActor.run {
                loadError = "Aucun commerce sélectionné."
                isLoading = false
            }
            return
        }
        await MainActor.run {
            loadError = nil
            isLoading = true
        }
        do {
            let s: BusinessSettingsResponse = try await APIClient.shared.request(.businessSettings(slug: slug))
            await MainActor.run {
                maxPassesPerDay = s.scanMaxPassesPerMemberPerDay ?? 0
                maxPointsPerTransaction = s.scanMaxPointsPerTransaction ?? 0
                requireReceiptQr = (s.requireReceiptQrValidation ?? 0) == 1
                receiptToleranceCents = min(500, max(0, s.receiptQrToleranceCents ?? 5))
                isLoading = false
            }
        } catch {
            await MainActor.run {
                loadError = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func save() async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            await MainActor.run { saveError = "Aucun commerce sélectionné." }
            return
        }
        await MainActor.run {
            saveError = nil
            saveNotice = nil
            isSaving = true
        }
        do {
            var patch = FullDashboardSettingsPatch()
            patch.scanMaxPassesPerMemberPerDay = maxPassesPerDay
            patch.scanMaxPointsPerTransaction = maxPointsPerTransaction
            patch.requireReceiptQrValidation = requireReceiptQr
            patch.receiptQrToleranceCents = receiptToleranceCents
            _ = try await APIClient.shared.request(.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
            await MainActor.run {
                isSaving = false
                saveNotice = "Réglages enregistrés."
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            await syncService.syncAfterServerMutation()
        } catch {
            await MainActor.run {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsScanSecurityView()
            .environmentObject(SyncService(container: PersistenceController.preview.container))
    }
}
