//
//  AddStampVisitSheet.swift
//  myfidpass
//
//  Plein écran « Tampon » après scan QR : même chrome que le crédit points (fond radial, feuille basse),
//  aperçu carte tampons (CafeDesArtsCardPreview) à la place du pavé numérique.
//

import SwiftUI
import UIKit

// MARK: - Données (scan programme tampons)

struct ScanStampSheetData: Identifiable {
    let id = UUID()
    let slug: String
    let barcode: String
    let memberName: String
    let cardModel: DashboardHomeCardModel
}

// MARK: - Thème (aligné sur AddPointsAmountSheet)

private func sanitizeDimension(_ x: CGFloat) -> CGFloat {
    guard x.isFinite, x > 0 else { return 1 }
    return x
}

private enum StampVisitTheme {
    static let keypadBg = Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
    static let keypadTopCornerRadius: CGFloat = 52
    static let balanceBadgeTopInLightZone: CGFloat = 8
    static let minLightPanelHeightFloor: CGFloat = 148
}

private struct StampVisitTopChrome {
    var primary: Color { .white }
    var secondary: Color { Color.white.opacity(0.55) }
    var tertiary: Color { Color.white.opacity(0.28) }
    var glassStroke: Color { Color.white.opacity(0.22) }
}

// MARK: - Vue

struct AddStampVisitSheet: View {
    let data: ScanStampSheetData
    @Binding var isSubmitting: Bool
    var onDismiss: () -> Void
    var onConfirm: () async -> Bool

    @Environment(\.colorScheme) private var colorScheme

    private let topChrome = StampVisitTopChrome()

    private var model: DashboardHomeCardModel { data.cardModel }

    private var stampCaption: String {
        let total = max(1, Int(model.requiredStamps))
        let filled = min(max(0, Int(model.previewStampsCount)), total)
        if total > 1, filled == total - 1 {
            return "Dernier tampon avant la récompense : la carte repart à zéro après ce passage."
        }
        return "Solde avant cette visite : \(filled) / \(total) tampons"
    }

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                let pw = sanitizeDimension(proxy.size.width)
                let ph = sanitizeDimension(proxy.size.height)
                stampVisitDarkRadialBackground(width: pw, height: ph)
                    .frame(width: pw, height: ph)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GeometryReader { geo in
                let w = sanitizeDimension(geo.size.width)
                let h = sanitizeDimension(geo.size.height)
                let bottomInset = geo.safeAreaInsets.bottom
                let bottomPad = max(bottomInset, 12)
                let layoutH = h + bottomInset
                let headerTopInset: CGFloat = {
                    let g = geo.safeAreaInsets.top
                    if g >= 12 { return g }
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let win = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                        return max(g, win.safeAreaInsets.top)
                    }
                    return max(g, 47)
                }()

                let minLightNeeded = StampVisitTheme.balanceBadgeTopInLightZone + 24 + 64 + bottomPad + 18
                let minLight = max(StampVisitTheme.minLightPanelHeightFloor, minLightNeeded)

                let darkFloor: CGFloat = {
                    let header: CGFloat = 48
                    let caption: CGFloat = 52
                    let cardApprox: CGFloat = min(w * 1.15, 420)
                    let verticalPad: CGFloat = 20
                    return header + caption + cardApprox + verticalPad
                }()

                let darkCoreMax = max(0, layoutH - headerTopInset - minLight)
                let darkCoreH = min(darkCoreMax, darkFloor + 120)
                let darkColumnH = headerTopInset + darkCoreH
                let lightColumnH = max(1, layoutH - darkColumnH)
                let sheetH = max(1, lightColumnH - StampVisitTheme.balanceBadgeTopInLightZone)

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        stampHeaderBar
                            .padding(.horizontal, 12)
                            .padding(.top, headerTopInset + 10)

                        Text(stampCaption)
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundStyle(topChrome.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 22)
                            .padding(.top, 14)
                            .padding(.bottom, 8)

                        CafeDesArtsCardPreview(
                            displayName: model.displayName.isEmpty ? "Ma Carte Fidélité" : model.displayName,
                            requiredStamps: model.requiredStamps,
                            stampsCount: model.previewStampsCount,
                            primaryColorHex: model.primaryHex,
                            accentColorHex: model.accentHex,
                            stripColorHex: nil,
                            logoURL: model.logoURL,
                            stripDisplayMode: model.stripDisplayMode,
                            stripText: model.stripText.isEmpty ? nil : model.stripText,
                            stampEmoji: model.stampEmoji,
                            cardBackgroundImagePath: CardLogoStorage.resolvedDisplayPath(forStoredPath: model.cardBackgroundImagePath),
                            cardBackgroundRemoteURL: model.cardBackgroundRemoteURL,
                            labelColorHex: model.labelHex.trimmingCharacters(in: .whitespaces).isEmpty ? nil : model.labelHex,
                            headerRightText: model.headerRightText,
                            memberPreviewText: model.memberPreviewText,
                            memberColumnTitle: model.memberColumnTitle,
                            stampMidRewardLabel: model.stampMidRewardLabel,
                            stampRewardLabel: model.stampRewardLabel,
                            restantsCaption: model.labelRestants,
                            compact: true,
                            onEditZoneTap: nil,
                            fidelityQRPayloadURL: model.fidelityQRPayloadURL
                        )
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, 4)

                        Spacer(minLength: 8)
                    }
                    .frame(width: w, height: darkColumnH)
                    .background {
                        stampVisitDarkRadialBackground(width: w, height: darkColumnH)
                    }
                    .clipped()

                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: StampVisitTheme.balanceBadgeTopInLightZone)

                        ZStack(alignment: .bottom) {
                            UnevenRoundedRectangle(
                                cornerRadii: RectangleCornerRadii(
                                    topLeading: StampVisitTheme.keypadTopCornerRadius,
                                    bottomLeading: 0,
                                    bottomTrailing: 0,
                                    topTrailing: StampVisitTheme.keypadTopCornerRadius
                                ),
                                style: .continuous
                            )
                            .fill(StampVisitTheme.keypadBg)
                            .frame(width: w, height: sheetH)

                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                confirmStampButton
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, bottomPad + 10)
                            }
                            .frame(width: w, height: sheetH, alignment: .bottom)
                        }
                        .frame(width: w, height: sheetH, alignment: .top)
                    }
                    .frame(width: w, height: lightColumnH, alignment: .top)
                }
                .frame(width: w, height: layoutH)
            }
            .ignoresSafeArea(edges: [.bottom, .top])

            if isSubmitting {
                ZStack {
                    Color(UIColor.tertiarySystemBackground)
                        .opacity(colorScheme == .light ? 0.88 : 0.5)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.35)
                        .tint(AppTheme.Colors.primary)
                }
                .allowsHitTesting(true)
            }
        }
    }

    private var stampHeaderBar: some View {
        HStack(spacing: 0) {
            Group {
                if #available(iOS 26.0, *) {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(topChrome.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass(.regular))
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Annuler")
                } else {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(topChrome.primary)
                            .frame(width: 44, height: 44)
                            .background {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Circle()
                                            .strokeBorder(topChrome.glassStroke, lineWidth: 1)
                                    }
                            }
                    }
                    .accessibilityLabel("Annuler")
                }
            }

            Text(data.memberName)
                .font(.system(size: 21, weight: .semibold, design: .default))
                .foregroundStyle(topChrome.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
    }

    private var confirmStampButton: some View {
        let barHeight: CGFloat = 64
        return Button {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task {
                _ = await onConfirm()
            }
        } label: {
            Text("Ajouter un tampon")
                .font(.system(size: 17, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: barHeight)
                .background {
                    Capsule()
                        .fill(AppTheme.Colors.primary.gradient)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                }
        }
        .buttonStyle(StampVisitKeypadButtonStyle())
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.45 : 1)
        .accessibilityLabel("Ajouter un tampon")
        .accessibilityHint("Enregistre une visite et crédite un tampon sur la carte du client.")
    }
}

private struct StampVisitKeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

// MARK: - Fond (identique à AddPointsAmountSheet)

private func stampVisitDarkRadialBackground(width: CGFloat, height: CGFloat) -> some View {
    let dim = max(width, height)
    let endR = dim * 1.02
    let startR = dim * 0.06
    return ZStack {
        Color(red: 0.005, green: 0.007, blue: 0.012)
        RadialGradient(
            colors: [
                Color(red: 0.09, green: 0.095, blue: 0.13),
                Color(red: 0.055, green: 0.058, blue: 0.078),
                Color(red: 0.032, green: 0.035, blue: 0.048),
                Color(red: 0.018, green: 0.02, blue: 0.032),
                Color(red: 0.01, green: 0.012, blue: 0.022),
                Color(red: 0.004, green: 0.006, blue: 0.014)
            ],
            center: UnitPoint(x: 0.5, y: 0.08),
            startRadius: startR,
            endRadius: endR
        )
        RadialGradient(
            colors: [
                Color(red: 0.16, green: 0.168, blue: 0.215),
                Color(red: 0.07, green: 0.075, blue: 0.095),
                Color.clear
            ],
            center: UnitPoint(x: 0.5, y: 0.035),
            startRadius: 4,
            endRadius: dim * 0.52
        )
        .blendMode(.plusLighter)
        .opacity(0.32)
    }
}

#if DEBUG
#Preview {
    AddStampVisitSheet(
        data: ScanStampSheetData(
            slug: "demo",
            barcode: "00000000-0000-0000-0000-000000000001",
            memberName: "Camille",
            cardModel: DashboardHomeCardModel(
                displayName: "Café des Arts",
                programType: "stamps",
                primaryHex: "1a1a2e",
                accentHex: "eaeaea",
                labelHex: "a0a0a8",
                stripDisplayMode: "logo",
                stripText: "",
                logoURL: nil,
                stampEmoji: "☕️",
                requiredStamps: 8,
                previewStampsCount: 3,
                previewPointsCount: 0,
                cardBackgroundImagePath: nil,
                cardBackgroundRemoteURL: nil,
                headerRightText: "Récompenses ↗",
                memberPreviewText: "Camille",
                labelRestants: "Restants",
                memberColumnTitle: "MEMBRE",
                stampMidRewardLabel: "",
                stampRewardLabel: "-50 %",
                fidelityQRPayloadURL: nil
            )
        ),
        isSubmitting: .constant(false),
        onDismiss: {},
        onConfirm: { true }
    )
}
#endif
