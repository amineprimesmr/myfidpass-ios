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
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
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
        IPhoneNotificationPreviewShell(statusBarTime: statusBarTime) {
            notificationCard
        }
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

    var body: some View {
        IPhoneNotificationPreviewShell(statusBarTime: statusBarTime) {
            editableNotificationCard
        }
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

                TextField("", text: $messageBody, prompt: Text("Message…").foregroundStyle(.white.opacity(0.42)), axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.subheadline.weight(.regular))
                    .foregroundStyle(.white)
                    .lineLimit(2...5)
                    .multilineTextAlignment(.leading)
                    .focused(focusedField, equals: .message)
                    /// Multiligne : pas de `onSubmit` fiable — sauvegarde auto côté écran parent (debounce) + flush avant envoi.
                    .accessibilityLabel("Message de la notification")
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

    private var notificationIconPickerArea: some View {
        PhotosPicker(selection: $iconPhotoItem, matching: .images, photoLibrary: .shared()) {
            ZStack(alignment: .bottomTrailing) {
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Changer l’icône de notification")
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
