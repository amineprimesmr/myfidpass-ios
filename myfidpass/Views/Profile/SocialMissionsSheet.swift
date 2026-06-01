//
//  SocialMissionsSheet.swift
//  myfidpass
//
//  Sheet "Connecter mes réseaux" — config missions par pseudo (Instagram, TikTok, Facebook, X).
//  Le commerçant saisit son @pseudo, le backend génère l'URL et active la mission pour les clients.
//

import SwiftUI
import UIKit

private struct NetworkModel: Identifiable {
    let id: String          // "instagram" | "tiktok" | "facebook" | "twitter"
    let label: String
    let color: Color
    let placeholder: String
    let assetImage: String
    var username: String = ""
    var enabled: Bool = false
    var points: Int = 20
}

struct SocialMissionsSheet: View {
    let slug: String
    var onSaved: (() -> Void)?

    @State private var networks: [NetworkModel] = Self.defaultNetworks()
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Les clients voient une mission « nous suivre » sur leur carte (comme le profil complet). Choisissez le @ de votre commerce et les points offerts par réseau.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        ForEach($networks) { $net in
                            networkCard(net: $net)
                                .transition(Self.missionRowExitTransition)
                        }
                        if let msg = errorMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        if let ok = savedMessage {
                            Text(ok)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                        saveButton
                    }
                }
                .padding(16)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Connecter mes réseaux")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func networkCard(net: Binding<NetworkModel>) -> some View {
        let network = net.wrappedValue
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(network.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    if UIImage(named: network.assetImage) != nil {
                        Image(network.assetImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: Self.fallbackSystemSymbol(for: network.id))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(network.color)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(network.label)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    if !network.username.isEmpty {
                        Text("@\(network.username)")
                            .font(.caption)
                            .foregroundStyle(network.color)
                    } else {
                        Text("Non configuré")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                Spacer()
                Toggle("", isOn: net.enabled)
                    .labelsHidden()
                    .disabled(network.username.isEmpty)
            }

            HStack(spacing: 10) {
                Image(systemName: "at")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                TextField(network.placeholder, text: net.username)
                    .font(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .onChange(of: net.username.wrappedValue) { _, newVal in
                        if !newVal.isEmpty && !net.enabled.wrappedValue {
                            net.enabled.wrappedValue = true
                        }
                    }
            }
            .padding(10)
            .background(AppTheme.Colors.background.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
            )

            HStack {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Text("Points offerts au client")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Spacer()
                HStack(spacing: 0) {
                    Button {
                        if net.points.wrappedValue > 5 { net.points.wrappedValue -= 5 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    Text("\(network.points) pts")
                        .font(.caption.weight(.semibold))
                        .frame(minWidth: 56)
                        .multilineTextAlignment(.center)
                    Button {
                        if net.points.wrappedValue < 200 { net.points.wrappedValue += 5 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
                .buttonStyle(.plain)
            }

            if !network.username.isEmpty {
                let url = Self.buildUrl(network: network.id, username: network.username)
                Text(url)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(14)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: AppTheme.Colors.shadow, radius: 4, y: 2)
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                        .padding(.trailing, 4)
                }
                Text(isSaving ? "Enregistrement…" : "Enregistrer")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.Colors.primary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isSaving)
        .padding(.top, 8)
    }

    private func load() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let resp: SocialMissionsResponse = try await APIClient.shared.request(.dashboardSocialMissions(slug: slug))
            await MainActor.run {
                applyResponse(resp)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func save() async {
        await MainActor.run { isSaving = true; errorMessage = nil; savedMessage = nil }
        let payload = buildPayload()
        do {
            let resp: SocialMissionsResponse = try await APIClient.shared.request(
                .dashboardSocialMissionsPatch(slug: slug, payload: payload)
            )
            await MainActor.run {
                applyResponse(resp)
                isSaving = false
                savedMessage = "Missions enregistrées ✓"
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            onSaved?()
            NotificationCenter.default.post(name: .myfidpassSocialMissionsDidSave, object: nil)
            await animateCompletedMissionsOffThenDismissOrStay()
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = "Impossible d'enregistrer. Vérifiez votre connexion."
            }
        }
    }

    /// Transition « balayée » vers la droite + léger scale à la disparition.
    private static var missionRowExitTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .leading)),
            removal: .move(edge: .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.94, anchor: .leading))
        )
    }

    private func isMissionComplete(_ net: NetworkModel) -> Bool {
        let u = net.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return net.enabled && !u.isEmpty
    }

    /// Retire une par une les missions complètes avec vibration progressive le long de chaque animation.
    private func animateCompletedMissionsOffThenDismissOrStay() async {
        let completedIds = networks.filter { isMissionComplete($0) }.map(\.id)
        guard !completedIds.isEmpty else {
            try? await Task.sleep(nanoseconds: 650_000_000)
            await MainActor.run { dismiss() }
            return
        }
        let swipeDuration: TimeInterval = 0.36
        for id in completedIds {
            let haptics = Task { await Self.rampSwipeHaptics(over: swipeDuration) }
            await MainActor.run {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 26)) {
                    networks.removeAll { $0.id == id }
                }
            }
            await haptics.value
            try? await Task.sleep(nanoseconds: 72_000_000)
        }
        await MainActor.run {
            if networks.isEmpty {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.92)
                dismiss()
            } else {
                savedMessage = "Enregistré — terminez les réseaux restants si besoin."
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
            }
        }
    }

    /// Courbe d’intensité croissante, ticks rapides pour une sensation « continue » pendant le balayage.
    private static func rampSwipeHaptics(over duration: TimeInterval) async {
        let steps = max(10, Int(duration / 0.03))
        let gen = UIImpactFeedbackGenerator(style: .soft)
        await MainActor.run { gen.prepare() }
        for s in 0..<steps {
            let u = Double(s + 1) / Double(steps)
            let curved = 0.1 + 0.9 * pow(u, 0.82)
            await MainActor.run {
                gen.impactOccurred(intensity: CGFloat(curved))
            }
            let slice = duration / Double(steps)
            try? await Task.sleep(nanoseconds: UInt64(slice * 1_000_000_000))
        }
    }

    private func applyResponse(_ resp: SocialMissionsResponse) {
        func apply(idx: Int, cfg: SocialMissionConfig?) {
            guard let cfg else { return }
            networks[idx].username = cfg.username
            networks[idx].enabled = cfg.enabled
            networks[idx].points = cfg.points
        }
        apply(idx: 0, cfg: resp.instagram)
        apply(idx: 1, cfg: resp.tiktok)
        apply(idx: 2, cfg: resp.facebook)
        apply(idx: 3, cfg: resp.twitter)
    }

    private func buildPayload() -> SocialMissionsPatchPayload {
        func item(_ net: NetworkModel) -> SocialMissionsPatchItem {
            SocialMissionsPatchItem(username: net.username, enabled: net.enabled && !net.username.isEmpty, points: net.points)
        }
        return SocialMissionsPatchPayload(
            instagram: item(networks[0]),
            tiktok: item(networks[1]),
            facebook: item(networks[2]),
            twitter: item(networks[3])
        )
    }

    private static func buildUrl(network: String, username: String) -> String {
        let h = username.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard !h.isEmpty else { return "" }
        switch network {
        case "instagram": return "instagram.com/\(h)"
        case "tiktok":    return "tiktok.com/@\(h)"
        case "facebook":  return "facebook.com/\(h)"
        case "twitter":   return "x.com/\(h)"
        default:          return ""
        }
    }

    private static func fallbackSystemSymbol(for networkID: String) -> String {
        switch networkID {
        case "instagram":
            return "camera.aperture"
        case "tiktok":
            return "music.note"
        case "facebook":
            return "f.square"
        case "twitter":
            return "xmark"
        default:
            return "network"
        }
    }

    private static func defaultNetworks() -> [NetworkModel] {[
        NetworkModel(id: "instagram", label: "Instagram", color: Color(red: 0.88, green: 0.19, blue: 0.55),
                     placeholder: "votre_pseudo_instagram", assetImage: "SocialInstagram"),
        NetworkModel(id: "tiktok", label: "TikTok", color: .black,
                     placeholder: "votre_pseudo_tiktok", assetImage: "SocialTikTok"),
        NetworkModel(id: "facebook", label: "Facebook", color: Color(red: 0.23, green: 0.35, blue: 0.60),
                     placeholder: "votre_page_facebook", assetImage: "SocialFacebook"),
        NetworkModel(id: "twitter", label: "X (Twitter)", color: .black,
                     placeholder: "votre_pseudo_x", assetImage: "SocialX"),
    ]}
}
