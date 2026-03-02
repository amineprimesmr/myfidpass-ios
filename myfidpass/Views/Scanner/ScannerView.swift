//
//  ScannerView.swift
//  myfidpass
//
//  Scan des cartes de fidélité (QR) et ajout de tampon.
//

import SwiftUI
import AVFoundation
import CoreData

struct ScannerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var appState: AppState
    @StateObject private var dataService: DataService
    @State private var isScanning = false
    @State private var isScanRequestInProgress = false
    @State private var lastScannedCode: String?
    @State private var showSuccess = false
    @State private var showError: String?
    @State private var scannedClientName: String?
    @State private var scannedPointsAdded: Int?

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CameraQRView(
                    onCodeScanned: handleCodeScanned,
                    isScanning: $isScanning
                )
                .ignoresSafeArea()

                overlayView
                if isScanRequestInProgress {
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
                    SuccessOverlay(clientName: scannedClientName ?? "Client", pointsAdded: scannedPointsAdded)
                        .transition(.scale.combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { showSuccess = false; scannedPointsAdded = nil }
                            }
                        }
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

    private func handleCodeScanned(_ code: String) {
        guard let slug = AuthStorage.currentBusinessSlug else {
            appState.showError("Aucun commerce. Reconnectez-vous.")
            return
        }
        Task {
            await MainActor.run { isScanRequestInProgress = true }
            defer { Task { @MainActor in isScanRequestInProgress = false } }
            do {
                let response: ScanResponse = try await APIClient.shared.request(.scan(slug: slug, barcode: code, visit: true, points: nil, amountEur: nil))
                await MainActor.run {
                    scannedClientName = response.member.name ?? "Client"
                    if let added = response.pointsAdded, added > 0 {
                        scannedPointsAdded = added
                    }
                    withAnimation(.spring(response: 0.3)) { showSuccess = true }
                    lastScannedCode = code
                }
                await syncService.syncIfNeeded()
            } catch APIError.notFound {
                await MainActor.run {
                    showError = "Code non reconnu pour ce commerce."
                    appState.showError("Code non reconnu.")
                }
            } catch {
                let msg = (error as? APIError)?.errorDescription ?? "Erreur lors du scan."
                await MainActor.run {
                    showError = msg
                    appState.showError(msg)
                }
            }
        }
    }
}

private struct SuccessOverlay: View {
    let clientName: String
    var pointsAdded: Int?
    @State private var scale: CGFloat = 0.5

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.Colors.success)
            Text("Passage enregistré !")
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
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

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
        .environmentObject(SyncService(context: PersistenceController.preview.container.viewContext))
        .environmentObject(AppState.shared)
}
