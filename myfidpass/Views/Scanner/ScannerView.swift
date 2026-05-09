//
//  ScannerView.swift
//  myfidpass
//
//  Scan des cartes de fidélité (QR) : lookup client puis choix « 1 passage » ou montant (€) avant d’enregistrer.
//

import SwiftUI
import AVFoundation
import CoreData

struct ScannerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var appState: AppState
    @StateObject private var dataService: DataService
    @StateObject private var receiptCoordinator = ReceiptValidationCoordinator()
    @State private var isScanning = false
    @State private var isLookupInProgress = false
    @State private var isCreditInProgress = false
    @State private var pendingBarcode: String?
    @State private var lookedUpMemberName: String?
    @State private var lookedUpMemberPoints: Int?
    @State private var amountText = ""
    @State private var showSuccess = false
    @State private var showError: String?
    @State private var scannedClientName: String?
    @State private var scannedPointsAdded: Int?
    @State private var isRedeemInProgress = false
    @State private var pointsToRedeemText = ""
    @State private var lastActionWasRedeem = false
    @State private var programType = "points"
    @State private var pointsPerEuro = 1
    @State private var pointsPerVisit = 0
    @FocusState private var amountFocused: Bool

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    private var isChoiceVisible: Bool {
        pendingBarcode != nil && lookedUpMemberName != nil && !showSuccess
    }

    private var pointsFromAmount: Int {
        let s = amountText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let a = Double(s), a > 0 else { return 0 }
        return Int(a) * pointsPerEuro
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CameraQRView(
                    onCodeScanned: handleCodeScanned,
                    isScanning: $isScanning
                )
                .ignoresSafeArea()
                .opacity(isChoiceVisible ? 0.3 : 1)

                overlayView

                if isLookupInProgress {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    ProgressView("Vérification du client…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .foregroundStyle(.white)
                }

                if isChoiceVisible {
                    clientChoiceCard
                }

                if isCreditInProgress {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    ProgressView("Enregistrement…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                        .foregroundStyle(.white)
                }
            }
            .navigationTitle("Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Erreur", isPresented: .constant(showError != nil)) {
                Button("OK") { showError = nil }
            } message: {
                if let msg = showError { Text(msg) }
            }
            .overlay {
                if showSuccess {
                    SuccessOverlay(
                        clientName: scannedClientName ?? "Client",
                        pointsAdded: scannedPointsAdded,
                        title: lastActionWasRedeem ? "Récompense utilisée !" : "Passage enregistré !"
                    )
                        .transition(.scale.combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showSuccess = false
                                    scannedPointsAdded = nil
                                    lastActionWasRedeem = false
                                    pendingBarcode = nil
                                    lookedUpMemberName = nil
                                    lookedUpMemberPoints = nil
                                    amountText = ""
                                    pointsToRedeemText = ""
                                }
                            }
                        }
                }
            }
            .fullScreenCover(item: $receiptCoordinator.session) { session in
                ReceiptTicketValidationView(session: session) { token in
                    receiptCoordinator.complete(with: token)
                }
            }
        }
    }

    private var overlayView: some View {
        VStack {
            Spacer()
            Text("Placez le QR code de la carte dans le cadre")
                .font(AppTheme.Fonts.callout())
                .foregroundStyle(.white)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.xl)
        }
    }

    private var clientChoiceCard: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: AppTheme.Spacing.lg) {
                HStack {
                    Text("Client reconnu")
                        .font(AppTheme.Fonts.headline())
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Button {
                        withAnimation {
                            pendingBarcode = nil
                            lookedUpMemberName = nil
                            lookedUpMemberPoints = nil
                            amountText = ""
                            pointsToRedeemText = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                Text(lookedUpMemberName ?? "Client")
                    .font(AppTheme.Fonts.title3())
                    .foregroundStyle(AppTheme.Colors.primary)
                if let pts = lookedUpMemberPoints {
                    Text("\(pts) pt\(pts > 1 ? "s" : "") actuels")
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                if programType == "stamps" {
                    Text("Ajoutez 1 tampon ou utilisez une récompense.")
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Montant du panier (€) = points. Ou 1 passage.")
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Divider()
                    .padding(.vertical, 4)

                if programType == "stamps" {
                    Button {
                        creditVisitOnly()
                    } label: {
                        Label("Ajouter 1 tampon", systemImage: "plus.circle.fill")
                            .font(AppTheme.Fonts.headline())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.md)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.primary)
                    .disabled(isCreditInProgress)
                } else {
                    VStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                        Text("Montant du panier")
                            .font(AppTheme.Fonts.callout())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Button {
                            amountFocused = true
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(amountText.isEmpty ? "0" : amountText)
                                    .font(.system(size: 48, weight: .bold, design: .default))
                                    .foregroundStyle(amountText.isEmpty ? AppTheme.Colors.textSecondary.opacity(0.5) : AppTheme.Colors.primary)
                                Text("€")
                                    .font(.system(size: 28, weight: .semibold, design: .default))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        TextField("Montant", text: $amountText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.plain)
                            .focused($amountFocused)
                            .frame(width: 1, height: 1)
                            .opacity(0.01)
                        if pointsFromAmount > 0 {
                            Text("= \(pointsFromAmount) point\(pointsFromAmount > 1 ? "s" : "")")
                                .font(AppTheme.Fonts.headline())
                                .foregroundStyle(AppTheme.Colors.accent)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        Button {
                            creditAmount()
                        } label: {
                            Text("Enregistrer")
                                .font(AppTheme.Fonts.headline())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.md)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.accent)
                        .disabled(isCreditInProgress || amountText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .animation(.easeOut(duration: 0.25), value: amountText)
                    .animation(.easeOut(duration: 0.25), value: pointsFromAmount)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            amountFocused = true
                        }
                    }
                    if pointsPerVisit > 0 {
                        Button {
                            creditVisitOnly()
                        } label: {
                            Label("1 passage (+\(pointsPerVisit) pt)", systemImage: "person.fill.checkmark")
                                .font(AppTheme.Fonts.callout())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.sm)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.Colors.primary)
                        .disabled(isCreditInProgress)
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                Group {
                    let requiredStamps = Int(dataService.createOrGetCurrentCardTemplate().requiredStamps)
                    let hasEnoughStamps = (lookedUpMemberPoints ?? 0) >= requiredStamps
                    if hasEnoughStamps {
                        Button {
                            redeemStamps()
                        } label: {
                            Label("Utiliser la récompense (tampons)", systemImage: "gift.fill")
                                .font(AppTheme.Fonts.headline())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.sm)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.success)
                        .disabled(isRedeemInProgress || isCreditInProgress)
                    }
                    HStack(spacing: AppTheme.Spacing.sm) {
                        TextField("Points à déduire", text: $pointsToRedeemText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                        Button {
                            redeemPoints()
                        } label: {
                            Text("Utiliser points")
                                .font(AppTheme.Fonts.caption())
                                .padding(.horizontal, AppTheme.Spacing.md)
                                .padding(.vertical, AppTheme.Spacing.sm)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.Colors.primary)
                        .disabled(isRedeemInProgress || isCreditInProgress || pointsToRedeemText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .shadow(radius: 16)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func handleCodeScanned(_ code: String) {
        guard let slug = AuthStorage.currentBusinessSlug else {
            appState.showError("Aucun commerce. Reconnectez-vous.")
            return
        }
        guard pendingBarcode == nil else { return }
        Task {
            await MainActor.run { isLookupInProgress = true }
            defer { Task { @MainActor in isLookupInProgress = false } }
            do {
                let response: ScanLookupResponse = try await APIClient.shared.request(.scanLookup(slug: slug, barcode: code))
                let settings: BusinessSettingsResponse? = try? await APIClient.shared.request(.businessSettings(slug: slug)) as BusinessSettingsResponse
                await MainActor.run {
                    pendingBarcode = code
                    lookedUpMemberName = response.member.name ?? "Client"
                    lookedUpMemberPoints = response.member.points
                    amountText = ""
                    programType = (settings?.programType ?? "points").lowercased()
                    if programType != "points" && programType != "stamps" { programType = "points" }
                    pointsPerEuro = settings?.pointsPerEuro ?? 1
                    pointsPerVisit = settings?.pointsPerVisit ?? 0
                    withAnimation(.spring(response: 0.3)) {}
                }
            } catch let e as APIError where e.isHTTPResourceMissing {
                await MainActor.run {
                    showError = "Code non reconnu pour ce commerce."
                    appState.showError("Code non reconnu.")
                }
            } catch {
                let msg = (error as? APIError)?.errorDescription ?? "Erreur lors de la vérification."
                await MainActor.run {
                    showError = msg
                    appState.showError(msg)
                }
            }
        }
    }

    private func creditVisitOnly() {
        performCredit(visit: true, amountEur: nil)
    }

    private func creditAmount() {
        let value = amountText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(value), amount > 0 else {
            showError = "Saisissez un montant valide (ex. 12.50)."
            return
        }
        performCredit(visit: false, amountEur: amount)
    }

    private func performCredit(visit: Bool, amountEur: Double?) {
        guard let slug = AuthStorage.currentBusinessSlug, let barcode = pendingBarcode else { return }
        Task {
            await MainActor.run { isCreditInProgress = true }
            defer { Task { @MainActor in isCreditInProgress = false } }
            do {
                var receiptTok: String?
                if !visit, let amt = amountEur, amt > 0 {
                    let settings: BusinessSettingsResponse
                    if let c = ScanFlowSettingsCache.cached(for: slug) {
                        settings = c
                    } else {
                        settings = try await APIClient.shared.request(.businessSettings(slug: slug)) as BusinessSettingsResponse
                        ScanFlowSettingsCache.store(settings, for: slug)
                    }
                    if (settings.requireReceiptQrValidation ?? 0) == 1 {
                        guard let t = try await receiptCoordinator.requestValidatedToken(slug: slug, amountEur: amt) else {
                            await MainActor.run {
                                showError = "Scan du ticket de caisse annulé."
                                appState.showError(showError ?? "")
                            }
                            return
                        }
                        receiptTok = t
                    }
                }
                let response: ScanResponse = try await APIClient.shared.request(.scan(
                    slug: slug,
                    barcode: barcode,
                    visit: visit,
                    points: nil,
                    amountEur: amountEur,
                    receiptValidationToken: receiptTok
                ))
                await MainActor.run {
                    scannedClientName = response.member?.name ?? lookedUpMemberName ?? "Client"
                    scannedPointsAdded = response.pointsAdded
                    withAnimation(.spring(response: 0.3)) { showSuccess = true }
                }
                await syncService.syncAfterServerMutation()
            } catch let e as APIError where e.isHTTPResourceMissing {
                await MainActor.run {
                    showError = "Code non reconnu."
                    pendingBarcode = nil
                    lookedUpMemberName = nil
                    lookedUpMemberPoints = nil
                }
            } catch {
                let msg = (error as? APIError)?.errorDescription ?? "Erreur lors de l'enregistrement."
                await MainActor.run {
                    showError = msg
                    appState.showError(msg)
                }
            }
        }
    }

    private func redeemStamps() {
        guard let slug = AuthStorage.currentBusinessSlug, let memberId = pendingBarcode else { return }
        Task {
            await MainActor.run { isRedeemInProgress = true }
            defer { Task { @MainActor in isRedeemInProgress = false } }
            do {
                let response = try await APIClient.shared.request(.redeemReward(slug: slug, memberId: memberId, type: .stamps)) as RedeemResponse
                await MainActor.run {
                    lookedUpMemberPoints = response.newPoints ?? 0
                    scannedClientName = lookedUpMemberName
                    scannedPointsAdded = nil
                    lastActionWasRedeem = true
                    withAnimation(.spring(response: 0.3)) { showSuccess = true }
                }
                await syncService.syncAfterServerMutation()
            } catch {
                let msg = (error as? APIError)?.errorDescription ?? "Impossible d'utiliser la récompense."
                await MainActor.run { showError = msg; appState.showError(msg) }
            }
        }
    }

    private func redeemPoints() {
        let value = pointsToRedeemText.trimmingCharacters(in: .whitespaces)
        guard let points = Int(value), points > 0 else {
            showError = "Saisissez un nombre de points à déduire."
            return
        }
        guard let slug = AuthStorage.currentBusinessSlug, let memberId = pendingBarcode else { return }
        Task {
            await MainActor.run { isRedeemInProgress = true }
            defer { Task { @MainActor in isRedeemInProgress = false } }
            do {
                let response = try await APIClient.shared.request(.redeemReward(slug: slug, memberId: memberId, type: .points(pointsToDeduct: points))) as RedeemResponse
                await MainActor.run {
                    lookedUpMemberPoints = response.newPoints
                    pointsToRedeemText = ""
                    scannedClientName = lookedUpMemberName
                    scannedPointsAdded = nil
                    lastActionWasRedeem = true
                    withAnimation(.spring(response: 0.3)) { showSuccess = true }
                }
                await syncService.syncAfterServerMutation()
            } catch {
                let msg = (error as? APIError)?.errorDescription ?? "Impossible d'utiliser les points."
                await MainActor.run { showError = msg; appState.showError(msg) }
            }
        }
    }
}

private struct SuccessOverlay: View {
    let clientName: String
    var pointsAdded: Int?
    var title: String = "Passage enregistré !"
    @State private var scale: CGFloat = 0.5

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.Colors.success)
            Text(title)
                .font(AppTheme.Fonts.title3())
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text(clientName)
                .font(AppTheme.Fonts.body())
                .foregroundStyle(AppTheme.Colors.textSecondary)
            if let pts = pointsAdded, pts > 0 {
                Text("+\(pts) point\(pts > 1 ? "s" : "")")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.accent)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
        .shadow(radius: 20)
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { scale = 1 }
        }
    }
}

// MARK: - Camera QR

struct CameraQRView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    @Binding var isScanning: Bool

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onCodeScanned = onCodeScanned
        vc.isScanningBinding = $isScanning
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    var isScanningBinding: Binding<Bool>?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastScannedTime: Date = .distantPast
    private let throttleInterval: TimeInterval = 1.5

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
        isScanningBinding?.wrappedValue = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
        isScanningBinding?.wrappedValue = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupCaptureSession() }
                }
            }
            return
        }
        setupCaptureSession()
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        guard let device = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.sessionPreset = .high
        session.addInput(input)
        try? device.lockForConfiguration()
        if device.maxAvailableVideoZoomFactor > 1.0 {
            device.videoZoomFactor = min(1.35, device.maxAvailableVideoZoomFactor)
        }
        device.unlockForConfiguration()

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
        captureSession = session
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let string = obj.stringValue,
              !string.isEmpty else { return }
        let now = Date()
        guard now.timeIntervalSince(lastScannedTime) >= throttleInterval else { return }
        lastScannedTime = now
        onCodeScanned?(string)
    }
}

#Preview {
    ScannerView(context: PersistenceController.preview.container.viewContext)
        .environmentObject(SyncService(container: PersistenceController.preview.container))
        .environmentObject(AppState.shared)
}
