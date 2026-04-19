//
//  MyfidpassOnboardingQCMProcessUI.swift
//  myfidpass
//
//  Composants onboarding : titres, container, QCM sélection unique et multi.
//  **Une seule présentation de boutons** (alignée sur « Qu’est-ce qui compte le plus pour vous ? ») :
//  texte seul, `.glassStyle()`, coins 16, opacité selon sélection — thème **clair**.
//

import SwiftUI

// MARK: - Constantes

enum MyfidpassOnboardingConstants {
    static let titleToContentSpacing: CGFloat = 60
    static let titleAreaHeight: CGFloat = 150
    static let titleTopPadding: CGFloat = 110
    static let titleTopPaddingAfterPrimaryGoal: CGFloat = 60
    /// Comme Process `FirstNameInputStepView` : `titleToContentSpacing + 60` sous la zone titre.
    static let processStyleFieldExtraSpacing: CGFloat = 60
}

// MARK: - Titre

struct MyfidpassOnboardingTitleView: View {
    let lines: [String]
    let opacity: Double

    init(_ line1: String, _ line2: String, opacity: Double = 1.0) {
        self.lines = [line1, line2]
        self.opacity = opacity
    }

    init(_ title: String, opacity: Double = 1.0) {
        self.lines = [title]
        self.opacity = opacity
    }

    init(_ line1: String, _ line2: String, _ line3: String, opacity: Double = 1.0) {
        self.lines = [line1, line2, line3]
        self.opacity = opacity
    }

    var body: some View {
        Text(lines.joined(separator: " "))
            .font(.system(size: 26, weight: .bold, design: .default))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .shadow(color: Color.black.opacity(0.06), radius: 1, x: 0, y: 1)
            .opacity(opacity)
            .lineLimit(4)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: false)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 40)
            .padding(.trailing, 20)
    }
}

// MARK: - Container titre + contenu

struct MyfidpassOnboardingStepContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    let subtitle2: String?
    let content: Content

    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30

    init(
        title: String,
        subtitle: String? = nil,
        subtitle2: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.subtitle2 = subtitle2
        self.content = content()
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 150)

                content
                    .opacity(contentOpacity)
                    .offset(y: contentOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .opacity(titleOpacity)
                            .offset(y: titleOffset)
                    }

                    if let subtitle2 = subtitle2 {
                        Text(subtitle2)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .opacity(titleOpacity)
                            .offset(y: titleOffset)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.top, 100)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(.onboardingEntrance) {
                titleOpacity = 1.0
                titleOffset = 0
            }
            withAnimation(.onboardingEntrance.delay(0.12)) {
                contentOpacity = 1.0
                contentOffset = 0
            }
        }
        .onDisappear {
            titleOpacity = 0
            titleOffset = 20
            contentOpacity = 0
            contentOffset = 30
        }
    }
}

// MARK: - Ligne de choix (style unique = page priorités)

private struct MyfidpassOnboardingChoiceRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .glassStyle()
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .opacity(isSelected ? 1.0 : 0.6)
    }
}

// MARK: - QCM une réponse (même grille que le multi)

struct MyfidpassQCMSingleBlock<Option: Hashable>: View {
    let line1: String
    let line2: String
    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: MyfidpassOnboardingConstants.titleAreaHeight)
                Spacer()
                    .frame(height: 5)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(options, id: \.self) { option in
                            MyfidpassOnboardingChoiceRow(
                                title: label(option),
                                isSelected: selection == option
                            ) {
                                HapticManager.shared.selection()
                                selection = option
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
                .frame(maxHeight: 500)
            }

            VStack {
                MyfidpassOnboardingTitleView(line1, line2)
                    .padding(.top, MyfidpassOnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                Spacer()
            }
        }
    }
}

// MARK: - QCM plusieurs réponses

struct MyfidpassQCMMultiBlock<Option: Hashable>: View {
    let line1: String
    let line2: String
    let options: [Option]
    let label: (Option) -> String
    @Binding var selected: Set<Option>

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: MyfidpassOnboardingConstants.titleAreaHeight)
                Spacer()
                    .frame(height: 5)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(options, id: \.self) { option in
                            MyfidpassOnboardingChoiceRow(
                                title: label(option),
                                isSelected: selected.contains(option)
                            ) {
                                HapticManager.shared.selection()
                                if selected.contains(option) {
                                    selected.remove(option)
                                } else {
                                    selected.insert(option)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
                .frame(maxHeight: 500)
            }

            VStack {
                MyfidpassOnboardingTitleView(line1, line2)
                    .padding(.top, MyfidpassOnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                Spacer()
            }
        }
    }
}
