//
//  BorderBeamManualNotificationBlock.swift
//  myfidpass
//
//  `BorderBeamEffect.swift` + barre basse : copie alignée sur le projet Bureau
//  `/Users/amine/Desktop/BorderBeam/BorderBeam/` (ContentView `CustomBottomBar` / `CustomButton`).
//

import SwiftUI

extension View {
    @ViewBuilder
    func borderBeam(
        border: Color,
        hideFadeBorder: Bool = true,
        beam: [Color],
        beamBlur: CGFloat,
        cornerRadius: CGFloat,
        isEnabled: Bool = true
    ) -> some View {
        self
            .modifier(
                BorderBeamEffect(
                    border: border,
                    hideFadeBorder: hideFadeBorder,
                    beam: beam,
                    beamBlur: beamBlur,
                    cornerRadius: cornerRadius,
                    isEnabled: isEnabled
                )
            )
    }
}

struct BorderBeamEffect: ViewModifier {
    var border: Color
    var hideFadeBorder: Bool
    var beam: [Color]
    var beamBlur: CGFloat
    var cornerRadius: CGFloat
    var isEnabled: Bool
    func body(content: Content) -> some View {
        content
            .background {
                if isEnabled {
                    BorderBeamView()
                }
            }
    }

    @ViewBuilder
    private func BorderBeamView() -> some View {
        ZStack {
            /// OPTIONAL: Faded Border
            if !hideFadeBorder {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(border.tertiary, lineWidth: 0.6)
            }

            /// Using Keyframe Animator to animate the border beam!
            KeyframeAnimator(initialValue: 0.0, repeating: true) { value in
                let rotation = value * 360

                let borderGradient = AngularGradient(
                    colors: [.clear, border, .clear],
                    center: .center,
                    startAngle: .degrees(140 + rotation),
                    endAngle: .degrees(270 + rotation)
                )

                let beamGradient = LinearGradient(
                    colors: beam,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                /// Beam Gradient
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(beamGradient)
                    /// Inverse masking to show only some limited amount of beam gradient
                    .mask {
                        Rectangle()
                            .overlay {
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    /// Using blur instead of padding, so that we can get smooth ending
                                    .blur(radius: beamBlur)
                                    .blendMode(.destinationOut)
                            }
                    }
                    .mask {
                        /// Masking it with the already having border gradient to sync with the border effect
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(borderGradient)
                            .blur(radius: beamBlur / 1.5)
                            .padding(-beamBlur * 2)
                    }

                /// Border Gradient
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderGradient, lineWidth: 0.6)
            } keyframes: { _ in
                LinearKeyframe(1, duration: 2.5)
            }
        }
        .padding(0.5)
    }
}

// MARK: - Barre basse identique à ContentView / CustomBottomBar (+ branchement notif)

struct BorderBeamManualNotificationComposerView: View {
    @Binding var messageBody: String
    @Binding var segment: String?
    let segmentChoices: [(key: String, label: String)]
    let defaultMessages: [String: String]
    let keepManualMessageFieldClearedAfterSend: Bool

    let hasSlug: Bool
    /// `true` tant que l’abonnement payant (Stripe web) n’est pas actif : pas d’envoi manuel.
    var sendingLocked: Bool = false
    let isSending: Bool
    let isUploadingNotificationIcon: Bool
    let sendSuccessCount: Int?
    let onSend: () -> Void

    @FocusState private var messageFieldFocused: Bool
    @State private var placeholderCharIndex: Int = 0
    @State private var placeholderLoopTask: Task<Void, Never>?

    private static let beamPalette: [Color] = [.green, .blue, .pink, .orange, .indigo]
    private let placeholderFull = "Écrivez votre message"

    private var segmentMenuLabel: String {
        guard let s = segment, !s.isEmpty else { return "Tous les clients" }
        return segmentChoices.first(where: { $0.key == s })?.label ?? s
    }

    private var sendDisabled: Bool {
        sendingLocked
            || isSending
            || sendSuccessCount != nil
            || isUploadingNotificationIcon
            || messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !hasSlug
    }

    private var animatedPlaceholderText: String {
        String(placeholderFull.prefix(placeholderCharIndex))
    }

    var body: some View {
        customBottomBarLikeBorderBeam()
            .borderBeam(
                border: .white,
                beam: Self.beamPalette,
                beamBlur: 15,
                cornerRadius: 20,
                isEnabled: true
            )
            .background(Color.white.opacity(0.06), in: .rect(cornerRadius: 20))
            .preferredColorScheme(.dark)
            .onAppear { restartPlaceholderAnimation() }
            .onDisappear {
                placeholderLoopTask?.cancel()
                placeholderLoopTask = nil
            }
            .onChange(of: messageBody) { _, newValue in
                // Ne pas remplacer `\n` par un espace : la touche « Terminé » du clavier peut livrer un `\n`
                // → on supprime seulement les retours chariot (pas d’espace parasite).
                let withoutNewlines = newValue.replacingOccurrences(of: "\n", with: "")
                if withoutNewlines != newValue {
                    messageBody = withoutNewlines
                    return
                }
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    placeholderCharIndex = 0
                }
                restartPlaceholderAnimation()
            }
            .onChange(of: messageFieldFocused) { _, focused in
                if focused { placeholderCharIndex = 0 }
                restartPlaceholderAnimation()
            }
            .onChange(of: segment) { _, newValue in
                guard let key = newValue, let def = defaultMessages[key] else { return }
                if messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !keepManualMessageFieldClearedAfterSend {
                    messageBody = def
                }
            }
    }

    /// Copie de `ContentView.CustomBottomBar()` : mêmes `spacing`, `padding`, `TextField`, `HStack`, icônes.
    @ViewBuilder
    private func customBottomBarLikeBorderBeam() -> some View {
        VStack(alignment: .leading, spacing: 25) {
            ZStack(alignment: .topLeading) {
                TextField("", text: $messageBody, axis: .vertical)
                    .focused($messageFieldFocused)
                    .disabled(sendingLocked)
                    .lineLimit(3 ... 10)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .padding(.top, 8)
                    .submitLabel(.done)
                    .onSubmit {
                        messageFieldFocused = false
                    }

                if messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !messageFieldFocused {
                    Text(animatedPlaceholderText)
                        .font(.body)
                        .foregroundStyle(Color.primary.opacity(0.42))
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 8)

            HStack(spacing: 20) {
                categoryCapsuleLikeNameModelButton()

                Spacer(minLength: 0)

                customSendButtonLikeBorderBeam()
                    .foregroundStyle(Color.primary)
            }
        }
        .padding(15)
    }

    private func restartPlaceholderAnimation() {
        placeholderLoopTask?.cancel()
        placeholderLoopTask = nil
        let trimmed = messageBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty, !messageFieldFocused else { return }

        placeholderLoopTask = Task { @MainActor in
            while !Task.isCancelled {
                let n = placeholderFull.count
                guard n > 0 else { break }
                for i in 0 ... n {
                    guard !Task.isCancelled else { return }
                    let stillEmpty = messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    guard stillEmpty, !messageFieldFocused else {
                        placeholderCharIndex = 0
                        return
                    }
                    placeholderCharIndex = i
                    try? await Task.sleep(nanoseconds: 48_000_000)
                }
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                guard !Task.isCancelled else { return }
                placeholderCharIndex = 0
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    /// Même capsule que « Name/Model Name » : `Menu` pour les catégories (popup système).
    @ViewBuilder
    private func categoryCapsuleLikeNameModelButton() -> some View {
        Menu {
            Button("Tous les clients") {
                segment = nil
            }
            ForEach(segmentChoices, id: \.key) { c in
                Button(c.label) {
                    segment = c.key
                }
            }
        } label: {
            Text(segmentMenuLabel)
                .font(.caption)
                .foregroundStyle(Color.primary.opacity(0.8))
                .lineLimit(1)
                .padding(.vertical, 8)
                .padding(.horizontal, 15)
                .background(.fill, in: .capsule)
        }
        .disabled(!hasSlug || sendingLocked)
    }

    /// Copie de `ContentView.CustomButton()` : `arrow.up` 35×35 + `borderBeam` + cercle `.background`.
    @ViewBuilder
    private func customSendButtonLikeBorderBeam() -> some View {
        Button {
            onSend()
        } label: {
            Group {
                if sendSuccessCount != nil {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "arrow.up")
                        .foregroundStyle(Color.primary)
                }
            }
            .frame(width: 35, height: 35)
            .borderBeam(
                border: .white,
                beam: Self.beamPalette,
                beamBlur: 15,
                cornerRadius: 20,
                isEnabled: true
            )
            .background(.background, in: .circle)
        }
        .disabled(sendDisabled)
        .accessibilityLabel(isSending ? "Envoi de la notification en cours" : "Envoyer la campagne")
    }
}

#if DEBUG
#Preview {
    BorderBeamManualNotificationComposerView(
        messageBody: .constant(""),
        segment: .constant(nil),
        segmentChoices: [
            ("inactive14", "Client inactif +14 jours"),
            ("recurrent", "Clients fidèles (+10 visites par mois)"),
        ],
        defaultMessages: [:],
        keepManualMessageFieldClearedAfterSend: false,
        hasSlug: true,
        isSending: false,
        isUploadingNotificationIcon: false,
        sendSuccessCount: nil,
        onSend: {}
    )
}
#endif
