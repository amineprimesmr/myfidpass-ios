//
//  AddPointsAmountSheet.swift
//  myfidpass
//
//  Plein écran « Ajouter des points » : fond noir en dégradé radial, carte client, pavé numérique, glisser pour créditer.
//

import SwiftUI
import UIKit

/// Évite NaN / ∞ → avertissements SwiftUI « Invalid frame dimension ».
private func sanitizeDimension(_ x: CGFloat) -> CGFloat {
    guard x.isFinite, x > 0 else { return 1 }
    return x
}

// MARK: - Données (scan programme points)

/// Crédit (scan / fiche membre) ou retrait (correction) avec la même UI montant €.
enum AddPointsAmountMode: Equatable {
    case credit
    case debit
}

/// Palier points / récompense (aligné sur `points_reward_tiers` du SaaS).
struct ScanRewardTier: Hashable {
    let points: Int
    let label: String
}

struct ScanResultSheetData: Identifiable {
    let id = UUID()
    let slug: String
    let memberName: String
    let barcode: String
    let pointsPerEuro: Int
    let memberPoints: Int?
    /// Paliers triés côté appelant (points croissants).
    let rewardTiers: [ScanRewardTier]
    /// Si le montant du panier est strictement inférieur, 0 pt crédité (règle commerce).
    let pointsMinAmountEur: Double?
    /// Plafond serveur `scan_max_points_per_transaction` (nil ou 0 = illimité).
    let scanMaxPointsPerTransaction: Int?
}

/// Fiche membre : même plein écran que le scan (crédit ou correction débit).
struct MemberPointsAmountFlow: Identifiable {
    let id = UUID()
    let data: ScanResultSheetData
    let mode: AddPointsAmountMode
}

// MARK: - Saisie montant (clavier custom)

private struct AmountEntry {
    var intDigits: String = ""
    var fracDigits: String = ""
    var hasComma: Bool = false

    mutating func appendDigit(_ d: Int) {
        let c = String(d)
        if hasComma {
            guard fracDigits.count < 2 else { return }
            fracDigits.append(c)
        } else {
            if intDigits == "0" && c == "0" { return }
            if intDigits == "0" { intDigits = c; return }
            guard intDigits.count < 7 else { return }
            intDigits.append(c)
        }
    }

    mutating func appendComma() {
        guard !hasComma else { return }
        hasComma = true
        if intDigits.isEmpty { intDigits = "0" }
    }

    mutating func backspace() {
        if !fracDigits.isEmpty {
            fracDigits.removeLast()
            return
        }
        if hasComma {
            hasComma = false
            return
        }
        if !intDigits.isEmpty { intDigits.removeLast() }
    }

    private var fracAsDouble: Double {
        guard !fracDigits.isEmpty else { return 0 }
        let n = Double(fracDigits) ?? 0
        let div = pow(10.0, Double(fracDigits.count))
        return n / div
    }

    func amountEurosOrZero() -> Double {
        let intPart = Double(intDigits.isEmpty ? "0" : intDigits) ?? 0
        return intPart + fracAsDouble
    }

    var displayInteger: String {
        intDigits.isEmpty && !hasComma ? "0" : (intDigits.isEmpty ? "0" : intDigits)
    }

    var displayFraction: String {
        guard hasComma else { return "" }
        return fracDigits
    }
}

// MARK: - Couleurs (réf. maquette type Wallet / iOS)

private enum AddPointsTheme {
    /// Noir légèrement bleuté, un peu plus sombre que #121212
    static let darkBase = Color(red: 0.045, green: 0.048, blue: 0.062)
    /// #2C2C2E
    static let cardFill = Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
    /// #F2F2F7
    static let keypadBg = Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
    static let keyFill = Color.white
    /// Coins supérieurs du panneau pavé numérique
    static let keypadTopCornerRadius: CGFloat = 52
    /// Marge minimale sous la carte dans la zone sombre.
    static let darkExtraBelowCard: CGFloat = 2
    /// Hauteur sombre en plus : pousse le joint sombre/clair vers le bas pour que la feuille grise ne soit pas plus haute que le pavé + bouton.
    static let darkAdditionalPullDown: CGFloat = 200
    /// Marge entre la zone sombre et la feuille grise du pavé.
    static let balanceBadgeTopInLightZone: CGFloat = 8
    /// Marge sous le bord arrondi haut de la feuille grise jusqu’au pavé (sans grand vide).
    static let keypadPanelInnerTopPadding: CGFloat = 10
    /// Ajustement fin vertical du pavé dans la feuille.
    static let keypadLiftInSheet: CGFloat = -6
    /// Plancher de secours si le calcul intrinsèque échoue (très petit écran).
    static let minLightPanelHeightFloor: CGFloat = 280
}

/// Couleurs zone « sombre » (en-tête + montant + carte) selon le thème app.
private struct AddPointsTopChrome {
    let light: Bool
    var primary: Color { light ? Color(red: 0.07, green: 0.09, blue: 0.15) : .white }
    var secondary: Color { light ? Color(red: 0.42, green: 0.48, blue: 0.56) : Color.white.opacity(0.55) }
    var tertiary: Color { light ? Color(red: 0.5, green: 0.55, blue: 0.62) : Color.white.opacity(0.28) }
    var cardFill: Color { light ? Color(red: 0.93, green: 0.94, blue: 0.97) : AddPointsTheme.cardFill }
    var glassStroke: Color { light ? Color.black.opacity(0.12) : Color.white.opacity(0.22) }
    var mutedFill: Color { light ? Color.black.opacity(0.08) : Color.white.opacity(0.12) }
}

// MARK: - Vue principale (plein écran)

struct AddPointsAmountSheet: View {
    var mode: AddPointsAmountMode = .credit
    let memberName: String
    let barcode: String
    let pointsPerEuro: Int
    let memberPoints: Int?
    let rewardTiers: [ScanRewardTier]
    let pointsMinAmountEur: Double?
    var scanMaxPointsPerTransaction: Int? = nil
    @Binding var isSubmitting: Bool
    /// Même instance que l’écran parent : le scan ticket doit se présenter **depuis** cette feuille (évite 2 `fullScreenCover` imbriqués depuis la racine, qui ne s’affichent pas).
    @ObservedObject var receiptCoordinator: ReceiptValidationCoordinator
    var onDismiss: () -> Void
    var onSubmit: (Double) async -> Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var entry = AmountEntry()

    init(
        mode: AddPointsAmountMode = .credit,
        memberName: String,
        barcode: String,
        pointsPerEuro: Int,
        memberPoints: Int?,
        rewardTiers: [ScanRewardTier],
        pointsMinAmountEur: Double?,
        scanMaxPointsPerTransaction: Int? = nil,
        isSubmitting: Binding<Bool>,
        receiptCoordinator: ReceiptValidationCoordinator,
        onDismiss: @escaping () -> Void,
        onSubmit: @escaping (Double) async -> Bool
    ) {
        self.mode = mode
        self.memberName = memberName
        self.barcode = barcode
        self.pointsPerEuro = pointsPerEuro
        self.memberPoints = memberPoints
        self.rewardTiers = rewardTiers
        self.pointsMinAmountEur = pointsMinAmountEur
        self.scanMaxPointsPerTransaction = scanMaxPointsPerTransaction
        _isSubmitting = isSubmitting
        _receiptCoordinator = ObservedObject(wrappedValue: receiptCoordinator)
        self.onDismiss = onDismiss
        self.onSubmit = onSubmit
    }

    /// Toujours « mode sombre » : la zone haut (titre, EUR, carte) a son propre fond en dégradé gris / noir (`darkRadialBackground`), y compris en apparence claire.
    private var topChrome: AddPointsTopChrome { AddPointsTopChrome(light: false) }

    private var amountValue: Double { entry.amountEurosOrZero() }

    /// Points que ce montant fera gagner (0 si sous le minimum commerce).
    private var pointsFromAmount: Int {
        guard amountValue > 0 else { return 0 }
        if let minEur = pointsMinAmountEur, amountValue < minEur - 1e-9 { return 0 }
        return Int(floor(amountValue * Double(pointsPerEuro)))
    }

    /// Points réellement crédités après plafond sécurité caisse (mode crédit).
    private var creditPointsApplied: Int {
        ScanCreditLimits.effectivePoints(raw: pointsFromAmount, maxPerTransaction: scanMaxPointsPerTransaction)
    }

    /// Points effectivement retirés (plafonnés au solde affiché).
    private var effectiveDebitPoints: Int {
        let raw = pointsFromAmount
        let cap = memberPoints ?? 0
        return min(raw, max(0, cap))
    }

    private var canSubmit: Bool {
        guard amountValue > 0, !isSubmitting else { return false }
        switch mode {
        case .credit:
            return creditPointsApplied > 0
        case .debit:
            return effectiveDebitPoints > 0
        }
    }

    private func lightTap() {
        MerchantUXFeedback.shared.play(.tap)
    }

    /// Calcul hors `ViewBuilder` : évite « Type '()' cannot conform to 'View' » dans le `GeometryReader`.
    /// Hauteur minimale de la colonne **claire** : feuille grise + pavé + bouton + marges (sans grand vide imposé).
    private func minLightColumnHeight(
        keyHeight: CGFloat,
        keySpacing: CGFloat,
        compactDark: Bool,
        bottomPad: CGFloat
    ) -> CGFloat {
        let keypadStackH = 4 * keyHeight + 3 * keySpacing
        let confirmH: CGFloat = compactDark ? 58 : 64
        let sheetContent =
            AddPointsTheme.keypadPanelInnerTopPadding
                + keypadStackH + 6
                + 4 + confirmH
                + bottomPad + 10
        let raw = AddPointsTheme.balanceBadgeTopInLightZone + sheetContent + 12
        return max(AddPointsTheme.minLightPanelHeightFloor, raw)
    }

    private func darkAndLightColumnHeights(
        layoutH: CGFloat,
        safeTop: CGFloat,
        darkFloor: CGFloat,
        bottomPad: CGFloat,
        minLightNeeded: CGFloat
    ) -> (darkColumnH: CGFloat, lightColumnH: CGFloat) {
        guard layoutH.isFinite, layoutH > 0 else {
            return (sanitizeDimension(1), sanitizeDimension(1))
        }
        /// Cœur sombre (sous la safe top) ne peut pas dépasser ça sinon la colonne claire < minimum utile.
        let darkCoreMax = max(0, layoutH - safeTop - minLightNeeded)
        let darkCoreH = min(darkCoreMax, darkFloor + AddPointsTheme.darkAdditionalPullDown)
        let darkColumnH = safeTop + darkCoreH
        let lightColumnH = layoutH - darkColumnH
        return (
            sanitizeDimension(max(1, darkColumnH)),
            sanitizeDimension(max(1, lightColumnH))
        )
    }

    var body: some View {
        // Fond plein écran ; le contenu respecte la safe area → plus de header sous la barre d’état
        // (bug fréquent avec `.ignoresSafeArea()` + `GeometryReader` + `safeAreaInsets.top == 0`).
        ZStack(alignment: .top) {
            // Dégradé sur tout l’écran (y compris encoche) : évite la bande « vide » en haut.
            // Le contenu au-dessus garde les mêmes positions (safe area inchangée).
            GeometryReader { proxy in
                let pw = sanitizeDimension(proxy.size.width)
                let ph = sanitizeDimension(proxy.size.height)
                // Toujours sombre sur tout l’écran (sinon en thème clair la zone barre d’état restait claire).
                darkRadialBackground(width: pw, height: ph)
                    .frame(width: pw, height: ph)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GeometryReader { geo in
                let w = sanitizeDimension(geo.size.width)
                let h = sanitizeDimension(geo.size.height)
                let bottomInset = geo.safeAreaInsets.bottom
                let bottomPad = max(bottomInset, 12)
                /// Hauteur logique pleine écran (zone safe + bande home) pour remplir jusqu’en bas.
                let layoutH = h + bottomInset
                let usableH = max(120, layoutH - bottomPad)
                let compactDark = usableH < 500
                let eurLabelSize: CGFloat = compactDark ? 38 : 50
                let amountMainSize: CGFloat = compactDark ? 42 : 56
                let amountFracSize: CGFloat = compactDark ? 24 : 30
                let amountEuroSuffixSize: CGFloat = compactDark ? 28 : 34
                let keyH: CGFloat = compactDark ? 58 : 68
                let keySpacing: CGFloat = compactDark ? 10 : 12

                /// Sous `ignoresSafeArea(.top)`, `geo.safeAreaInsets.top` peut être 0 → bouton retour sous la barre d’état / Dynamic Island.
                let headerTopInset: CGFloat = {
                    let g = geo.safeAreaInsets.top
                    if g >= 12 { return g }
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let w = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                        return max(g, w.safeAreaInsets.top)
                    }
                    return max(g, 47)
                }()

                let minLightNeeded = minLightColumnHeight(
                    keyHeight: keyH,
                    keySpacing: keySpacing,
                    compactDark: compactDark,
                    bottomPad: bottomPad
                )
                /// Hauteur « serrée » header + montant + carte (évite le grand vide noir sous la carte).
                let darkContentTight: CGFloat = {
                    let header: CGFloat = 48
                    let eur: CGFloat = compactDark ? 52 : 66
                    let card: CGFloat = compactDark ? 108 : 120
                    let verticalPad: CGFloat = compactDark ? 14 : 18
                    return header + eur + card + verticalPad
                }()
                /// Bloc sombre élargi vers le bas jusqu’à la limite qui laisse juste la feuille claire utile (pavé + bouton).
                let darkFloor = darkContentTight + AddPointsTheme.darkExtraBelowCard
                let columnHeights = darkAndLightColumnHeights(
                    layoutH: layoutH,
                    safeTop: headerTopInset,
                    darkFloor: darkFloor,
                    bottomPad: bottomPad,
                    minLightNeeded: minLightNeeded
                )
                let darkColumnH = columnHeights.darkColumnH
                let lightColumnH = columnHeights.lightColumnH
                let sheetH = max(1, lightColumnH - AddPointsTheme.balanceBadgeTopInLightZone)
                let sheetGrayFillH = sheetH
                let keypadHPadding: CGFloat = 16

                VStack(spacing: 0) {
                    /// Barre titre + retour en haut (comme avant) ; seuls EUR + carte suivent le bas vers le clavier.
                    VStack(spacing: 0) {
                        headerBar
                            .padding(.horizontal, 12)
                            .padding(.top, headerTopInset + 10)

                        Spacer(minLength: compactDark ? 4 : 6)

                        VStack(alignment: .leading, spacing: 0) {
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text("EUR")
                                    .font(.system(size: eurLabelSize, weight: .medium, design: .default))
                                    .foregroundStyle(topChrome.tertiary)
                                    .tracking(1.2)
                                Spacer(minLength: 8)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(entry.displayInteger)
                                        .font(.system(size: amountMainSize, weight: .bold, design: .default))
                                        .foregroundStyle(topChrome.primary)
                                        .contentTransition(.numericText())
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                    if entry.hasComma {
                                        Text(",")
                                            .font(.system(size: amountMainSize, weight: .bold, design: .default))
                                            .foregroundStyle(topChrome.primary)
                                    }
                                    if !entry.displayFraction.isEmpty {
                                        Text(entry.displayFraction)
                                            .font(.system(size: amountFracSize, weight: .semibold, design: .default))
                                            .foregroundStyle(topChrome.primary.opacity(0.92))
                                    }
                                    Text("€")
                                        .font(.system(size: amountEuroSuffixSize, weight: .medium, design: .default))
                                        .foregroundStyle(topChrome.secondary)
                                        .padding(.leading, 4)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.top, compactDark ? 8 : 12)
                            .padding(.bottom, compactDark ? 6 : 8)
                            .animation(.snappy(duration: 0.11), value: entry.displayInteger)
                            .animation(.snappy(duration: 0.11), value: entry.displayFraction)
                        }
                    }
                    .frame(width: w, height: darkColumnH)
                    .background {
                        darkRadialBackground(width: w, height: darkColumnH)
                    }
                    .clipped()

                    /// Marge fixe sous la zone sombre, puis feuille grise pleine hauteur (pavé + bouton en bas).
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: AddPointsTheme.balanceBadgeTopInLightZone)

                        ZStack(alignment: .bottom) {
                            UnevenRoundedRectangle(
                                cornerRadii: RectangleCornerRadii(
                                    topLeading: AddPointsTheme.keypadTopCornerRadius,
                                    bottomLeading: 0,
                                    bottomTrailing: 0,
                                    topTrailing: AddPointsTheme.keypadTopCornerRadius
                                ),
                                style: .continuous
                            )
                            .fill(AddPointsTheme.keypadBg)
                            .frame(width: w, height: sheetGrayFillH)

                            /// Pavé + créditer ancrés en **bas** de la feuille : la feuille est moins haute, pas seulement remontée.
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Color.clear
                                    .frame(height: AddPointsTheme.keypadPanelInnerTopPadding)
                                keypadBlock(totalWidth: w - keypadHPadding * 2, keyHeight: keyH, spacing: keySpacing)
                                    .padding(.horizontal, keypadHPadding)
                                    .padding(.bottom, 6)
                                    .offset(y: AddPointsTheme.keypadLiftInSheet)
                                addPointsConfirmButton(compactDark: compactDark)
                                    .padding(.horizontal, keypadHPadding)
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
        }
        .overlay {
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
        .fullScreenCover(item: $receiptCoordinator.session) { session in
            ReceiptTicketValidationView(session: session) { token in
                receiptCoordinator.complete(with: token)
            }
        }
    }

    // MARK: Fond dégradé (radial haut centre)

    private func darkRadialBackground(width: CGFloat, height: CGFloat) -> some View {
        let dim = max(width, height)
        let endR = dim * 1.02
        let startR = dim * 0.06
        return ZStack {
            // Base quasi noire : garantit des bords très sombres
            Color(red: 0.005, green: 0.007, blue: 0.012)

            // Dégradé principal : centre légèrement relevé, tombée progressive vers l’extérieur plus noir
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

            // Halo bleuté discret en haut (accent, sans gommer le vignettage des bords)
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

    private func lightRadialBackground(width: CGFloat, height: CGFloat) -> some View {
        let dim = max(width, height)
        let endR = dim * 1.02
        let startR = dim * 0.06
        return ZStack {
            Color(red: 0.94, green: 0.95, blue: 0.98)
            RadialGradient(
                colors: [
                    Color(red: 0.99, green: 0.99, blue: 1.0),
                    Color(red: 0.95, green: 0.96, blue: 0.99),
                    Color(red: 0.90, green: 0.92, blue: 0.96),
                    Color(red: 0.88, green: 0.90, blue: 0.95)
                ],
                center: UnitPoint(x: 0.5, y: 0.08),
                startRadius: startR,
                endRadius: endR
            )
            RadialGradient(
                colors: [
                    Color(red: 0.75, green: 0.82, blue: 0.98).opacity(0.35),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: 0.04),
                startRadius: 8,
                endRadius: dim * 0.45
            )
        }
    }

    private var headerBar: some View {
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

            Text(memberName)
                .font(.system(size: 21, weight: .semibold, design: .default))
                .foregroundStyle(topChrome.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            /// Équilibre le chevron gauche pour garder le nom visuellement centré.
            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
    }

    // MARK: Pavé numérique (chiffres uniquement, touches centrées)

    private func keypadBlock(totalWidth: CGFloat, keyHeight: CGFloat, spacing: CGFloat) -> some View {
        let tw = sanitizeDimension(max(totalWidth, spacing * 2 + 9))
        let kh = sanitizeDimension(keyHeight)
        let sp = max(0, spacing.isFinite ? spacing : 0)
        let cellW = max(1, (tw - sp * 2) / 3)
        return VStack(spacing: sp) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: sp) {
                    ForEach(1...3, id: \.self) { col in
                        let n = row * 3 + col
                        keypadKey(n, cellWidth: cellW, keyHeight: kh)
                    }
                }
            }
            HStack(spacing: sp) {
                keypadSideKey(",", cellWidth: cellW, height: kh) {
                    entry.appendComma()
                    lightTap()
                }
                keypadKey(0, cellWidth: cellW, keyHeight: kh)
                keypadDeleteKey(cellWidth: cellW, height: kh)
            }
        }
        .padding(.horizontal, 0)
    }

    private func keypadKey(_ n: Int, cellWidth: CGFloat, keyHeight: CGFloat) -> some View {
        Button {
            entry.appendDigit(n)
            lightTap()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AddPointsTheme.keyFill)
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                Text("\(n)")
                    .font(.system(size: 34, weight: .medium, design: .default))
                    .foregroundStyle(.black.opacity(0.82))
                    .multilineTextAlignment(.center)
            }
            .frame(width: cellWidth, height: keyHeight)
        }
        .buttonStyle(KeypadButtonStyle())
    }

    private func keypadSideKey(_ title: String, cellWidth: CGFloat, height: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AddPointsTheme.keyFill)
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                Text(title)
                    .font(.system(size: 34, weight: .medium, design: .default))
                    .foregroundStyle(.black.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .frame(width: cellWidth, height: height)
        }
        .buttonStyle(KeypadButtonStyle())
    }

    private func keypadDeleteKey(cellWidth: CGFloat, height: CGFloat) -> some View {
        Button {
            entry.backspace()
            lightTap()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AddPointsTheme.keyFill)
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                Image(systemName: "delete.left.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.black.opacity(0.55))
            }
            .frame(width: cellWidth, height: height)
        }
        .buttonStyle(KeypadButtonStyle())
    }

    private func commitSubmit() {
        guard canSubmit else { return }
        let amount = amountValue
        Task {
            _ = await onSubmit(amount)
        }
    }

    /// Même hauteur que l’ancien rail « glisser pour valider », en simple tap.
    @ViewBuilder
    private func addPointsConfirmButton(compactDark: Bool) -> some View {
        let barHeight = compactDark ? 58.0 : 64.0
        let tint = mode == .debit ? Color(red: 0.98, green: 0.48, blue: 0.22) : AppTheme.Colors.primary
        let title = mode == .debit ? "Retirer les points" : "Créditer les points"
        Button {
            MerchantUXFeedback.shared.play(.success)
            commitSubmit()
        } label: {
            Text(title)
                .font(.system(size: compactDark ? 16 : 17, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: barHeight)
                .background {
                    Capsule()
                        .fill(tint.gradient)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                }
        }
        .buttonStyle(KeypadButtonStyle())
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.45)
        .accessibilityLabel(title)
        .accessibilityHint(canSubmit ? "Appuyez pour valider le montant saisi." : "Saisissez un montant valide d’abord.")
    }
}

private struct KeypadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    @Previewable @StateObject var receiptCoordinator = ReceiptValidationCoordinator()
    AddPointsAmountSheet(
        memberName: "Amine",
        barcode: "2766abcd-1234-5678-90ef-123456789012",
        pointsPerEuro: 10,
        memberPoints: 1200,
        rewardTiers: [
            ScanRewardTier(points: 100, label: "Boisson offerte"),
            ScanRewardTier(points: 300, label: "Menu -10 %")
        ],
        pointsMinAmountEur: nil,
        isSubmitting: .constant(false),
        receiptCoordinator: receiptCoordinator,
        onDismiss: {},
        onSubmit: { _ in true }
    )
}
#endif
