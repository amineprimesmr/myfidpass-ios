//
//  DashboardView.swift
//  myfidpass
//
//  Tableau de bord : stats (Cartes actives → liste membres, Scans aujourd'hui → activité), scan, notifications.
//

import SwiftUI
import CoreData

enum DashboardRoute: Hashable {
    case members
    case scansToday
}

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var appState: AppState
    @StateObject private var dataService: DataService
    @State private var isAnimating = false
    @State private var showScanner: Bool = false
    @State private var showToast: Bool = false
    @State private var successToast: Toast = .example1
    @State private var scanError: String?
    @FocusState private var isNotificationFieldFocused: Bool
    @State private var notificationMessage: String = ""
    @State private var isSendingNotification = false
    @State private var notifyResultMessage: String?
    @State private var menuConfig: MenuConfig = MenuConfig(symbolImage: "person.2.fill")
    /// Catégories sélectionnées pour l'envoi de notification (vide = tous les membres).
    @State private var selectedCategoryIdsForNotify: [String] = []
    @State private var showCategoriesManagement = false
    @State private var navigationPath = NavigationPath()
    @State private var titleAppeared = false
    /// Après scan : si programme points, afficher la sheet pour saisir le montant du panier.
    @State private var scanResultSheet: ScanResultSheetData?
    @State private var isScanAmountSubmitting = false

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    private var totalClients: Int { dataService.totalClientCardsCount() }
    private var stampsToday: Int { dataService.stampsCountToday() }

    private var menuActions: [MenuAction] {
        var list: [MenuAction] = []
        list.append(MenuAction(id: "notify-all", symbolImage: "person.2.fill", text: "Tous les membres") {
            menuConfig.showMenu = false
            selectedCategoryIdsForNotify = []
            isNotificationFieldFocused = true
        })
        for category in categoriesForNotify {
            let cat = category
            let sid = cat.serverId ?? UUID().uuidString
            list.append(MenuAction(id: "cat-\(sid)", symbolImage: "folder.fill", text: cat.name ?? "Catégorie") {
                menuConfig.showMenu = false
                selectedCategoryIdsForNotify = [sid]
                isNotificationFieldFocused = true
            })
        }
        list.append(MenuAction(id: "manage-categories", symbolImage: "folder.badge.gearshape", text: "Gérer les catégories") {
            menuConfig.showMenu = false
            showCategoriesManagement = true
        })
        return list
    }

    var body: some View {
        CustomMenuView(config: $menuConfig, actions: menuActions) {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        statsSection
                    }
                    .padding(AppTheme.Spacing.md)
                    .padding(.bottom, 120)
                    .opacity(titleAppeared ? 1 : 0)
                    .offset(y: titleAppeared ? 0 : 16)
                }
                .background(AppTheme.Colors.background)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.55).delay(0.08)) {
                        titleAppeared = true
                    }
                }
                .refreshable {
                    await syncService.syncIfNeeded(force: true)
                }
                .qrScanner(isScanning: $showScanner) { code in
                    handleQRScanned(code)
                }
                .dynamicIslandToast(isPresented: $showToast, value: successToast)
                .alert("Erreur scan", isPresented: .constant(scanError != nil)) {
                    Button("OK") { scanError = nil }
                } message: {
                    if let msg = scanError { Text(msg) }
                }

                if syncService.isSyncing {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppTheme.Colors.primary)
                            .padding(.top, 12)
                        Spacer()
                    }
                }

                // Barre en bas : chips + barre message (destinataires / envoyer)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    notificationRecipientChips
                    notificationBottomBar
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 15)
                .padding(.bottom, 10)
            }
            .navigationTitle("Tableau de bord")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scanner", systemImage: "qrcode.viewfinder")
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                }
            }
            .alert("Notification", isPresented: Binding(
                get: { notifyResultMessage != nil },
                set: { if !$0 { notifyResultMessage = nil } }
            )) {
                Button("OK") { notifyResultMessage = nil }
            } message: {
                if let msg = notifyResultMessage { Text(msg) }
            }
        }
        }
        .sheet(isPresented: $showCategoriesManagement) {
            CategoriesManagementView(context: viewContext)
                .environmentObject(syncService)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .modifier(LiquidGlassSheetModifier())
        }
        .sheet(item: $scanResultSheet) { data in
            ScanAmountSheet(
                memberName: data.memberName,
                barcode: data.barcode,
                pointsPerEuro: data.pointsPerEuro,
                isSubmitting: $isScanAmountSubmitting,
                onDismiss: { scanResultSheet = nil },
                onSubmit: { amountEur in
                    await submitScanAmount(slug: data.slug, barcode: data.barcode, amountEur: amountEur)
                    scanResultSheet = nil
                    showToast = true
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .modifier(LiquidGlassSheetModifier())
        }
    }

    /// Barre de saisie en bas : icône destinataires quand vide/fermée, icône envoyer dès qu’il y a du texte.
    private var notificationBottomBar: some View {
        let fillColor = Color.gray.opacity(0.15)
        let hasText = !notificationMessage.trimmingCharacters(in: .whitespaces).isEmpty
        return AnimatedBottomBar(
            hint: "Message pour tous les membres…",
            tint: AppTheme.Colors.primary,
            text: $notificationMessage,
            isFocused: $isNotificationFieldFocused,
            leadingAction: {
                recipientsButtonView(fillColor: fillColor)
            },
            trailingAction: {
                // Barre ouverte : bouton bleu = envoyer tout de suite (pas de reconfirmation), puis replier.
                if isNotificationFieldFocused {
                    Button {
                        if hasText {
                            sendNotificationToAll()
                        }
                        isNotificationFieldFocused = false
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.medium)
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppTheme.Colors.primary.gradient, in: .circle)
                    }
                } else {
                    Color.clear
                        .frame(width: 35, height: 35)
                }
            },
            mainAction: {
                // Dès qu’il y a du texte : icône envoyer. Sinon (barre fermée ou champ vide) : icône destinataires (menu).
                if isNotificationFieldFocused && hasText {
                    Button {
                        sendNotificationToAll()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.body)
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .disabled(isSendingNotification)
                } else {
                    recipientsButtonView(fillColor: fillColor)
                }
            }
        )
    }

    /// Chips pour choisir les destinataires de la notification (tous ou par catégorie).
    @ViewBuilder
    private var notificationRecipientChips: some View {
        let cats = categoriesForNotify
        if !cats.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                RecipientChip(
                    title: "Tous les membres",
                    isSelected: selectedCategoryIdsForNotify.isEmpty,
                    color: AppTheme.Colors.primary
                ) {
                    selectedCategoryIdsForNotify = []
                }
                ForEach(cats, id: \.serverId) { category in
                    let isSelected = selectedCategoryIdsForNotify.contains(category.serverId ?? "")
                    RecipientChip(
                        title: category.name ?? "",
                        isSelected: isSelected,
                        color: (category.colorHex.flatMap { Color(hex: $0) }) ?? AppTheme.Colors.primary
                    ) {
                        if isSelected {
                            selectedCategoryIdsForNotify.removeAll { $0 == category.serverId }
                        } else {
                            if let id = category.serverId { selectedCategoryIdsForNotify.append(id) }
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .padding(.bottom, 4)
        }
    }

    private var categoriesForNotify: [MemberCategory] {
        guard let template = dataService.currentCardTemplate() else { return [] }
        return dataService.categories(for: template)
    }

    @ViewBuilder
    private func recipientsButtonView(fillColor: Color) -> some View {
        MenuSourceButton(config: $menuConfig) {
            Image(systemName: "person.2.fill")
                .fontWeight(.medium)
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(fillColor, in: .circle)
        } onTap: {
            isNotificationFieldFocused = false
        }
    }

    private func sendNotificationToAll() {
        let msg = notificationMessage.trimmingCharacters(in: .whitespaces)
        guard !msg.isEmpty else { return }
        guard let slug = AuthStorage.currentBusinessSlug else {
            notifyResultMessage = "Aucun commerce. Reconnectez-vous."
            return
        }
        isSendingNotification = true
        notifyResultMessage = nil
        isNotificationFieldFocused = false
        Task {
            do {
                let result = try await APIClient.shared.request(
                    APIEndpoint.notifyClients(slug: slug, message: msg, categoryIds: selectedCategoryIdsForNotify.isEmpty ? nil : selectedCategoryIdsForNotify)
                ) as NotifyClientsResult
                await MainActor.run {
                    isSendingNotification = false
                    let n = result.sent ?? 0
                    notifyResultMessage = n > 0 ? "Notification envoyée (\(n) appareil(s))." : "Aucun appareil cible (Wallet / Web). Message enregistré."
                    notificationMessage = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        notifyResultMessage = nil
                    }
                }
            } catch {
                await MainActor.run {
                    isSendingNotification = false
                    notifyResultMessage = (error as? APIError)?.errorDescription ?? "Erreur lors de l'envoi."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        notifyResultMessage = nil
                    }
                }
            }
        }
    }

    /// Extrait l’ID membre (UUID) du code scanné (brut ou contenu dans une URL).
    private func normalizeBarcodeToMemberId(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return raw }
        let uuidPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        if let range = s.range(of: uuidPattern, options: .regularExpression) {
            return String(s[range])
        }
        if s.count == 36, s.contains("-") { return s }
        return s
    }

    /// Lookup client puis, selon le type de programme (tampons vs points), soit on enregistre 1 tampon, soit on affiche la sheet pour saisir le montant du panier.
    private func handleQRScanned(_ code: String) {
        guard let slug = AuthStorage.currentBusinessSlug else {
            appState.showError("Aucun commerce. Reconnectez-vous.")
            scanError = "Aucun commerce. Reconnectez-vous."
            return
        }
        let barcode = normalizeBarcodeToMemberId(code)
        Task {
            do {
                async let lookupTask = APIClient.shared.request(.scanLookup(slug: slug, barcode: barcode)) as ScanLookupResponse
                async let settingsTask = APIClient.shared.request(.businessSettings(slug: slug)) as BusinessSettingsResponse
                let lookup = try await lookupTask
                let settings = try await settingsTask
                let memberName = lookup.member.name ?? "Client"
                let programType = (settings.programType ?? "stamps").lowercased()
                let pointsPerEuro = settings.pointsPerEuro ?? 1

                if programType == "points" {
                    await MainActor.run {
                        scanResultSheet = ScanResultSheetData(
                            slug: slug,
                            memberName: memberName,
                            barcode: barcode,
                            pointsPerEuro: pointsPerEuro
                        )
                    }
                    return
                }

                // Programme tampons : enregistrer 1 passage (1 tampon) immédiatement.
                let response: ScanResponse = try await APIClient.shared.request(.scan(slug: slug, barcode: barcode, visit: true, points: nil, amountEur: nil))
                await MainActor.run {
                    successToast = Toast.scanStampSuccess(memberName: response.member.name ?? memberName)
                    showToast = true
                }
                await syncService.syncIfNeeded()
            } catch APIError.notFound {
                await MainActor.run {
                    scanError = "Code non reconnu pour ce commerce. Scannez le QR affiché sur la carte dans le Wallet du client (pas le lien « Ajouter à Wallet »)."
                    appState.showError(scanError ?? "Code non reconnu.")
                }
            } catch {
                let msg = (error as? APIError)?.errorDescription ?? "Erreur lors du scan."
                await MainActor.run {
                    scanError = msg
                    appState.showError(msg)
                }
            }
        }
    }

    private func submitScanAmount(slug: String, barcode: String, amountEur: Double) async {
        isScanAmountSubmitting = true
        defer { Task { @MainActor in isScanAmountSubmitting = false } }
        do {
            let response: ScanResponse = try await APIClient.shared.request(.scan(slug: slug, barcode: barcode, visit: false, points: nil, amountEur: amountEur))
            await MainActor.run {
                successToast = Toast.scanSuccess(
                    memberName: response.member.name ?? "Client",
                    pointsAdded: response.pointsAdded
                )
            }
            await syncService.syncIfNeeded()
        } catch {
            await MainActor.run {
                scanError = (error as? APIError)?.errorDescription ?? "Erreur lors de l'enregistrement."
                appState.showError(scanError ?? "Erreur")
            }
        }
    }

    private var statsSection: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            NavigationLink(value: DashboardRoute.members) {
                StatCard(
                    title: "Cartes actives",
                    value: "\(totalClients)",
                    icon: "person.2.fill",
                    color: AppTheme.Colors.primary
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(isAnimating ? 1 : 0.95)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isAnimating)

            NavigationLink(value: DashboardRoute.scansToday) {
                StatCard(
                    title: "Scans aujourd'hui",
                    value: "\(stampsToday)",
                    icon: "qrcode.viewfinder",
                    color: AppTheme.Colors.accent
                )
            }
            .buttonStyle(.plain)
            .scaleEffect(isAnimating ? 1 : 0.95)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: isAnimating)
        }
        .onAppear { isAnimating = true }
        .navigationDestination(for: DashboardRoute.self) { route in
            switch route {
            case .members:
                MembersListView(context: viewContext)
                    .environmentObject(syncService)
            case .scansToday:
                ScansTodayView(context: viewContext)
                    .environmentObject(syncService)
            }
        }
    }

}

// MARK: - Sheet montant du panier (programme points)
private struct ScanResultSheetData: Identifiable {
    let id = UUID()
    let slug: String
    let memberName: String
    let barcode: String
    let pointsPerEuro: Int
}

private struct ScanAmountSheet: View {
    let memberName: String
    let barcode: String
    let pointsPerEuro: Int
    @Binding var isSubmitting: Bool
    var onDismiss: () -> Void
    var onSubmit: (Double) async -> Void

    @State private var amountText = ""
    @FocusState private var amountFocused: Bool

    private var amountValue: Double? {
        let s = amountText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        return Double(s)
    }

    private var pointsFromAmount: Int {
        guard let a = amountValue, a > 0 else { return 0 }
        return Int(floor(a * Double(pointsPerEuro)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.xl) {
                Text("Client reconnu")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text(memberName)
                    .font(AppTheme.Fonts.title3())
                    .foregroundStyle(AppTheme.Colors.primary)

                Text("Montant du panier")
                    .font(AppTheme.Fonts.callout())
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Button {
                    amountFocused = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(amountText.isEmpty ? "0" : amountText)
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(amountText.isEmpty ? AppTheme.Colors.textSecondary.opacity(0.5) : AppTheme.Colors.primary)
                        Text("€")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Appuyez pour saisir le montant")

                TextField("Montant", text: $amountText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .focused($amountFocused)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)

                if pointsFromAmount > 0 {
                    Text("= \(pointsFromAmount) point\(pointsFromAmount > 1 ? "s" : "")")
                        .font(AppTheme.Fonts.title3())
                        .foregroundStyle(AppTheme.Colors.accent)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                Button {
                    guard let amount = amountValue, amount > 0 else { return }
                    Task {
                        await onSubmit(amount)
                    }
                } label: {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.md)
                    } else {
                        Text("Enregistrer")
                            .font(AppTheme.Fonts.headline())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.md)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.primary)
                .disabled(amountValue == nil || amountValue ?? 0 <= 0 || isSubmitting)
            }
            .padding(AppTheme.Spacing.xl)
            .animation(.easeOut(duration: 0.25), value: amountText)
            .animation(.easeOut(duration: 0.25), value: pointsFromAmount)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    amountFocused = true
                }
            }
            .navigationTitle("Ajouter des points")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onDismiss() }
                }
            }
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(AppTheme.Fonts.largeTitle())
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(title)
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .shadow(color: AppTheme.Colors.shadow, radius: 6, x: 0, y: 2)
    }
}

private struct RecipientChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Fonts.caption())
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : AppTheme.Colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : Color.gray.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct MemberRow: View {
    let name: String
    let points: Int

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundStyle(AppTheme.Colors.primary)
            Text(name)
                .font(AppTheme.Fonts.body())
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
            Text("\(points) pt\(points > 1 ? "s" : "")")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
    }
}

private struct RecentStampRow: View {
    let clientName: String
    let date: Date

    private var formattedDate: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.locale = Locale(identifier: "fr_FR")
        return f.localizedString(for: date, relativeTo: Date())
    }

    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.Colors.success)
            Text(clientName)
                .font(AppTheme.Fonts.body())
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
            Text(formattedDate)
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(AppTheme.Spacing.sm)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
    }
}

#Preview {
    DashboardView(context: PersistenceController.preview.container.viewContext)
        .environmentObject(SyncService(context: PersistenceController.preview.container.viewContext))
        .environmentObject(AppState.shared)
}
