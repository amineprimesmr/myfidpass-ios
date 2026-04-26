//
//  ReceiptTicketValidationView.swift
//  myfidpass
//
//  Scan QR sur ticket de caisse — caméra fluide, cadre animé, aperçu du QR à imprimer.
//

import SwiftUI
import Combine
@preconcurrency import AVFoundation
import AudioToolbox

/// Boîte `@unchecked Sendable` pour lancer `startRunning()` hors thread principal sans avertissement Sendable sur `AVCaptureSession`.
private final class AVCaptureSessionStarter: @unchecked Sendable {
    let session: AVCaptureSession
    init(_ session: AVCaptureSession) { self.session = session }
    func start() { session.startRunning() }
}

// MARK: - Caméra QR (réutilise la logique DIQRScanner, isolée pour ce flux)

private final class ReceiptScanCamera: ObservableObject {
    var session = AVCaptureSession()
    var output = AVCaptureMetadataOutput()
    @Published var scannedCode: String?
    @Published var permission: CameraPermission = .unknown

    enum CameraPermission {
        case unknown
        case granted
        case denied
    }

    func requestAccess() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await MainActor.run { permission = .granted }
        case .notDetermined:
            let ok = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run { permission = ok ? .granted : .denied }
        default:
            await MainActor.run { permission = .denied }
        }
    }
}

private struct ReceiptCameraPreview: UIViewRepresentable {
    @ObservedObject var camera: ReceiptScanCamera
    let size: CGSize

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: CGRect(origin: .zero, size: size))
        v.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: camera.session)
        layer.frame = CGRect(origin: .zero, size: size)
        layer.videoGravity = .resizeAspectFill
        v.layer.addSublayer(layer)
        context.coordinator.previewLayer = layer
        context.coordinator.setupIfNeeded(camera: camera)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = CGRect(origin: .zero, size: size)
    }

    func makeCoordinator() -> Coord {
        Coord(camera: camera)
    }

    final class Coord: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let camera: ReceiptScanCamera
        weak var previewLayer: AVCaptureVideoPreviewLayer?
        private var didSetup = false

        init(camera: ReceiptScanCamera) {
            self.camera = camera
        }

        func setupIfNeeded(camera: ReceiptScanCamera) {
            guard !didSetup else { return }
            didSetup = true
            Task {
                await camera.requestAccess()
                guard camera.permission == .granted else { return }
                do {
                    let session = camera.session
                    let output = camera.output
                    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
                    let input = try AVCaptureDeviceInput(device: device)
                    guard session.canAddInput(input), session.canAddOutput(output) else { return }
                    session.beginConfiguration()
                    session.addInput(input)
                    session.addOutput(output)
                    output.metadataObjectTypes = [.qr]
                    output.setMetadataObjectsDelegate(self, queue: .main)
                    session.commitConfiguration()
                    let starter = AVCaptureSessionStarter(session)
                    DispatchQueue.global(qos: .userInitiated).async {
                        starter.start()
                    }
                } catch {
                    /* ignore */
                }
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = obj.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !code.isEmpty,
                  camera.scannedCode == nil else { return }
            camera.scannedCode = code
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
    }
}

// MARK: - Vue

struct ReceiptTicketValidationView: View {
    let session: ReceiptTicketScanSession
    let onComplete: (String?) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var camera = ReceiptScanCamera()
    @State private var appear = false
    @State private var framePulse = false
    @State private var showReferenceQR = false
    @State private var laserPhase = false

    private var amountText: String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: session.amountEur)) ?? String(format: "%.2f", session.amountEur)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.12),
                    Color(red: 0.02, green: 0.03, blue: 0.08),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { layoutGeo in
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : -12)

                    Spacer(minLength: 8)

                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.55),
                                                Color.cyan.opacity(0.35),
                                                Color.blue.opacity(0.45)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: framePulse ? 2.2 : 1.4
                                    )
                            )
                            .shadow(color: .cyan.opacity(0.22), radius: framePulse ? 22 : 12, y: 0)
                            .scaleEffect(appear ? 1 : 0.92)

                        GeometryReader { geo in
                            let s = min(geo.size.width, geo.size.height) - 8
                            ZStack {
                                ReceiptCameraPreview(camera: camera, size: CGSize(width: s, height: s))
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)

                                // Laser
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.clear, .white.opacity(0.85), .clear],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 2.5)
                                    .blur(radius: 0.5)
                                    .offset(y: laserPhase ? s * 0.38 : -s * 0.38)
                                    .animation(
                                        .easeInOut(duration: 1.85).repeatForever(autoreverses: true),
                                        value: laserPhase
                                    )
                            }
                            .frame(width: s, height: s)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        }
                        .padding(10)
                    }
                    .frame(maxWidth: 520)
                    .frame(height: min(layoutGeo.size.width - 48, 380))
                    .padding(.horizontal, 20)

                    Text("Alignez le QR imprimé sur le ticket de caisse")
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 18)

                    if camera.permission == .denied {
                        Text("Activez la caméra dans Réglages pour scanner le ticket.")
                            .font(.caption)
                            .foregroundStyle(.orange.opacity(0.95))
                            .padding(.top, 8)
                    }

                    Spacer(minLength: 12)

                    referenceSection
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            showReferenceQR.toggle()
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: showReferenceQR ? "chevron.up" : "qrcode")
                            Text(showReferenceQR ? "Masquer le QR à imprimer" : "Afficher le QR à imprimer sur le ticket")
                        }
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 18)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
                appear = true
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                framePulse = true
            }
            laserPhase = true
        }
        .onChange(of: camera.scannedCode) { _, newVal in
            guard let raw = newVal?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return }
            let expected = session.qrPayload.trimmingCharacters(in: .whitespacesAndNewlines)
            if raw == expected {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onComplete(raw)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                camera.scannedCode = nil
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
        }
        .statusBarHidden(false)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onComplete(nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.14)))
            }
            .accessibilityLabel("Annuler")

            VStack(alignment: .leading, spacing: 6) {
                Text("Ticket de caisse")
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                Text("Montant attendu : \(amountText) €")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.cyan.opacity(0.95))
                if let exp = session.expiresAt {
                    Text("QR valide jusqu’à \(formatExp(exp))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Spacer()
        }
    }

    private func formatExp(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else { return iso }
        let out = DateFormatter()
        out.locale = Locale(identifier: "fr_FR")
        out.dateStyle = .none
        out.timeStyle = .short
        return out.string(from: d)
    }

    @ViewBuilder
    private var referenceSection: some View {
        if showReferenceQR {
            VStack(spacing: 10) {
                Text("Imprimez ce QR sur le ticket (même montant que la caisse).")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                if let img = QRCodeGenerator.generateQR(from: session.qrPayload, size: 200) {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 20).fill(.white))
                        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 8)
        }
    }
}
