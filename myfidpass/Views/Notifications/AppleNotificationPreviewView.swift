//
//  AppleNotificationPreviewView.swift
//  myfidpass
//
//  Aperçu campagne : aligné sur les vraies notifications iOS (écran verrouillé) :
//  icône squircle, titre gras, corps en blanc, « maintenant » à droite sur la 1ʳᵉ ligne.
//

import SwiftUI
import PhotosUI

// MARK: - Constantes (calquées sur la notification système)

private enum IOSNotificationMetrics {
    /// Taille typique de l’icône d’app dans une bannière iOS (≈48 pt).
    static let iconSide: CGFloat = 48
    /// Rayon d’angle proche du « squircle » des icônes (ratio ~0.23 × côté).
    static let iconCornerRadius: CGFloat = 11
    static let cardCornerRadius: CGFloat = 22
    static let iconTextSpacing: CGFloat = 12
    static let titleBodySpacing: CGFloat = 3
}

// MARK: - Chrome iPhone (partagé lecture / édition)

private struct IPhoneNotificationPreviewWallpaper: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.11, blue: 0.16),
                Color(red: 0.06, green: 0.07, blue: 0.11),
                Color.black,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct IPhoneNotificationBatteryGlyph: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.1)
                .frame(width: 25, height: 12)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .frame(width: 18, height: 8)
                .padding(.leading, 3)
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color.white.opacity(0.55))
                .frame(width: 1.5, height: 5)
                .offset(x: 25)
        }
        .frame(width: 28, height: 14, alignment: .leading)
        .accessibilityHidden(true)
    }
}

private struct IPhoneNotificationStatusBarChrome: View {
    var statusBarTime: String

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Text(statusBarTime)
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Color.clear
                    .frame(width: 128)

                HStack(spacing: 5) {
                    Image(systemName: "cellularbars")
                    Image(systemName: "wifi")
                    IPhoneNotificationBatteryGlyph()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 22)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.06),
                            Color.black,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 124, height: 36)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Aperçu barre d’état iPhone")
    }
}

private struct IPhoneNotificationPreviewShell<Card: View>: View {
    var statusBarTime: String
    @ViewBuilder var card: () -> Card

    var body: some View {
        VStack(spacing: 0) {
            IPhoneNotificationStatusBarChrome(statusBarTime: statusBarTime)
                .padding(.top, 10)
                .padding(.bottom, 14)

            card()
                .padding(.horizontal, 16)
        }
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background {
            IPhoneNotificationPreviewWallpaper()
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
    }
}

// MARK: - Lecture seule

/// Rendu type haut d’iPhone récent + bannière comme sur l’écran verrouillé (titre gras + corps, pas de 3ᵉ ligne « commerce »).
struct AppleNotificationPreviewView: View {
    /// Titre de la notification (ligne gras, comme « Apple » ou le nom du commerce).
    var title: String
    /// Corps (message).
    var bodyText: String
    /// Si `title` est vide, utilisé comme titre (équivalent nom d’expéditeur).
    var appDisplayName: String
    var logoURL: String? = nil
    var statusBarTime: String

    private var effectiveTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        return appDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var effectiveBody: String {
        let b = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !b.isEmpty { return b }
        return "Votre message apparaîtra ici pour les clients."
    }

    var body: some View {
        notificationCard
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 2)
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }

    private var notificationCard: some View {
        HStack(alignment: .center, spacing: IOSNotificationMetrics.iconTextSpacing) {
            notificationAppIcon

            VStack(alignment: .leading, spacing: IOSNotificationMetrics.titleBodySpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(effectiveTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    Text("maintenant")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Text(effectiveBody)
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(.white)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background {
            RoundedRectangle(cornerRadius: IOSNotificationMetrics.cardCornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
        .overlay(
            RoundedRectangle(cornerRadius: IOSNotificationMetrics.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        )
    }

    private var notificationAppIcon: some View {
        Group {
            if let raw = logoURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
                BusinessLogoView(
                    logoURL: raw,
                    logoAssetContext: .campaignNotificationIcon,
                    size: IOSNotificationMetrics.iconSide,
                    cornerRadius: IOSNotificationMetrics.iconCornerRadius
                )
            } else {
                Image("logonotif")
                    .resizable()
                    .scaledToFill()
                    .frame(width: IOSNotificationMetrics.iconSide, height: IOSNotificationMetrics.iconSide)
                    .clipShape(RoundedRectangle(cornerRadius: IOSNotificationMetrics.iconCornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            }
        }
    }
}

// MARK: - Aperçu îlot (lecture seule)

/// Bannière style îlot / riche : texte **lecture seule** (pas de champ), icône notif nette.
struct ManualRichNotificationReadOnlyPreview: View {
    let senderTitle: String
    let messageBody: String
    let appDisplayNameFallback: String
    let logoURL: String?
    /// Masque la ligne titre commerce + « maintenant » (ex. pop-up choix du logo notification).
    var hidesSenderTitleRow: Bool = false
    /// Corps affiché tel quel, sans repli sur le libellé par défaut quand non vide.
    var messageCopyOverride: String? = nil

    private let iconSide: CGFloat = 52
    private let iconCorner: CGFloat = 12

    private var displayTitle: String {
        let t = senderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        return appDisplayNameFallback.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayBody: String {
        if let o = messageCopyOverride?.trimmingCharacters(in: .whitespacesAndNewlines), !o.isEmpty {
            return o
        }
        let b = messageBody.trimmingCharacters(in: .whitespacesAndNewlines)
        if !b.isEmpty { return b }
        return "Votre message apparaîtra ici pour les clients."
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            notificationIconBlock
            VStack(alignment: .leading, spacing: 3) {
                if !hidesSenderTitleRow {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.black)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Text("maintenant")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.black.opacity(0.45))
                    }
                }
                Text(displayBody)
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(Color.black.opacity(0.88))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .glassEffect(.regular, cornerRadius: 22)
        .shadow(color: .clear, radius: 0, y: 0)
        .preferredColorScheme(.light)
    }

    private var notificationIconBlock: some View {
        Group {
            if let raw = logoURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
                BusinessLogoView(
                    logoURL: raw,
                    logoAssetContext: .campaignNotificationIcon,
                    size: iconSide,
                    cornerRadius: iconCorner
                )
            } else {
                Image("logonotif")
                    .resizable()
                    .scaledToFill()
                    .frame(width: iconSide, height: iconSide)
                    .clipShape(RoundedRectangle(cornerRadius: iconCorner, style: .continuous))
            }
        }
    }
}

// MARK: - Édition inline

/// Champs éditables (focus partagé avec la barre clavier sur l’écran parent).
enum CampaignNotificationEditorField: Hashable {
    case title, message
}

/// Même disposition que la notif système : titre gras + corps ; tap sur l’icône pour la photo.
struct AppleNotificationCampaignEditorPreview: View {
    @Binding var commerceBannerTitle: String
    @Binding var messageBody: String
    @Binding var iconPhotoItem: PhotosPickerItem?
    var bannerPromptFallback: String
    var logoURL: String?
    var statusBarTime: String
    var isUploadingIcon: Bool
    /// Focus géré par l’écran parent pour que `ToolbarItemGroup(placement: .keyboard)` s’affiche (SwiftUI).
    var focusedField: FocusState<CampaignNotificationEditorField?>.Binding
    /// Sauvegarde immédiate (barre « Enregistrer » + touche retour titre).
    var onSaveTexts: () async -> Void
    @State private var messageHintVisibleCount = 0
    @State private var messageHintAnimationTask: Task<Void, Never>?
    @State private var iconBlinkOn = false
    @State private var iconBlinkTask: Task<Void, Never>?
    private let messageHintFullText = "Ecrivez votre message..."

    private var hasCustomNotificationLogo: Bool {
        let raw = logoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !raw.isEmpty
    }

    private var isMessageEmpty: Bool {
        messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        editableNotificationCard
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 0)
            .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
    }

    private var editableNotificationCard: some View {
        HStack(alignment: .center, spacing: IOSNotificationMetrics.iconTextSpacing) {
            notificationIconPickerArea

            VStack(alignment: .leading, spacing: IOSNotificationMetrics.titleBodySpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("", text: $commerceBannerTitle, prompt: Text(bannerPromptFallback).foregroundStyle(.white.opacity(0.42)))
                        .textFieldStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .focused(focusedField, equals: .title)
                        /// Touche bleue clavier (Retour / Terminé) : enregistrer + fermer — comme `enterKeyHint` côté web.
                        .submitLabel(.done)
                        .onSubmit {
                            Task {
                                await onSaveTexts()
                                focusedField.wrappedValue = nil
                            }
                        }
                        .accessibilityLabel("Titre de la notification")

                    Spacer(minLength: 4)

                    Text("maintenant")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                TextField("", text: $messageBody, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(.white)
                    .lineLimit(2...5)
                    .multilineTextAlignment(.leading)
                    .focused(focusedField, equals: .message)
                    /// Multiligne : pas de `onSubmit` fiable — sauvegarde auto côté écran parent (debounce) + flush avant envoi.
                    .accessibilityLabel("Message de la notification")
                    .overlay(alignment: .leading) {
                        if isMessageEmpty {
                            Text(animatedMessageHintText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .allowsHitTesting(false)
                        }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background {
            RoundedRectangle(cornerRadius: IOSNotificationMetrics.cardCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.14, blue: 0.17),
                            Color(red: 0.19, green: 0.19, blue: 0.22),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: IOSNotificationMetrics.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
        )
        .onAppear {
            restartMessageHintAnimationIfNeeded()
            restartIconBlinkIfNeeded()
        }
        .onChange(of: isMessageEmpty) { _, _ in
            restartMessageHintAnimationIfNeeded()
        }
        .onChange(of: focusedField.wrappedValue) { _, _ in
            restartMessageHintAnimationIfNeeded()
        }
        .onDisappear {
            stopMessageHintAnimation()
            stopIconBlink()
        }
    }

    private func stopMessageHintAnimation() {
        messageHintAnimationTask?.cancel()
        messageHintAnimationTask = nil
        messageHintVisibleCount = 0
    }

    private var animatedMessageHintText: String {
        let total = messageHintFullText.count
        let clamped = max(0, min(total, messageHintVisibleCount))
        return String(messageHintFullText.prefix(clamped))
    }

    /// Animation continue lettre par lettre quand le champ message est vide et non focus.
    private func restartMessageHintAnimationIfNeeded() {
        stopMessageHintAnimation()
        guard isMessageEmpty, focusedField.wrappedValue != .message else { return }
        messageHintAnimationTask = Task { @MainActor in
            let total = messageHintFullText.count
            while !Task.isCancelled {
                for i in 1...total {
                    guard !Task.isCancelled else { return }
                    messageHintVisibleCount = i
                    try? await Task.sleep(nanoseconds: 55_000_000)
                }
                try? await Task.sleep(nanoseconds: 650_000_000)
                guard !Task.isCancelled else { return }
                messageHintVisibleCount = 0
                try? await Task.sleep(nanoseconds: 230_000_000)
            }
        }
    }

    private func stopIconBlink() {
        iconBlinkTask?.cancel()
        iconBlinkTask = nil
        iconBlinkOn = false
    }

    private func restartIconBlinkIfNeeded() {
        stopIconBlink()
        guard !isUploadingIcon, !hasCustomNotificationLogo else { return }
        iconBlinkTask = Task { @MainActor in
            while !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.55)) { iconBlinkOn = true }
                try? await Task.sleep(nanoseconds: 560_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.55)) { iconBlinkOn = false }
                try? await Task.sleep(nanoseconds: 560_000_000)
            }
        }
    }

    private var notificationIconPickerArea: some View {
        PhotosPicker(selection: $iconPhotoItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                Group {
                    if let raw = logoURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
                        BusinessLogoView(
                            logoURL: raw,
                            logoAssetContext: .campaignNotificationIcon,
                            size: IOSNotificationMetrics.iconSide,
                            cornerRadius: IOSNotificationMetrics.iconCornerRadius
                        )
                    } else {
                        Image("logonotif")
                            .resizable()
                            .scaledToFill()
                            .frame(width: IOSNotificationMetrics.iconSide, height: IOSNotificationMetrics.iconSide)
                            .clipShape(RoundedRectangle(cornerRadius: IOSNotificationMetrics.iconCornerRadius, style: .continuous))
                            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    }
                }

                if isUploadingIcon {
                    RoundedRectangle(cornerRadius: IOSNotificationMetrics.iconCornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.4))
                        .frame(width: IOSNotificationMetrics.iconSide, height: IOSNotificationMetrics.iconSide)
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                }
            }
            .frame(width: IOSNotificationMetrics.iconSide, height: IOSNotificationMetrics.iconSide)
            .opacity((hasCustomNotificationLogo || isUploadingIcon) ? 1 : (iconBlinkOn ? 1 : 0.58))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Changer l’icône de notification")
        .onChange(of: isUploadingIcon) { _, _ in
            restartIconBlinkIfNeeded()
        }
        .onChange(of: logoURL) { _, _ in
            restartIconBlinkIfNeeded()
        }
    }
}

#if DEBUG
#Preview {
    AppleNotificationPreviewView(
        title: "",
        bodyText: "Carte de fidélité modifiée",
        appDisplayName: "Apple",
        logoURL: nil,
        statusBarTime: "9:41"
    )
    .padding()
    .background(Color.gray)
}
#endif
