//
//  DIQRScannerView.swift
//  myfidpass
//
//  Aligné sur `Desktop/Swift/DIQRScanner` : expansion îlot → cadre (ressort interpolé),
//  flou + fondu, ligne laser `phaseAnimator`. Aucune animation pilotée par le scroll :
//  le tirage accueil ouvre seulement la feuille (`isScanning`), l’animation est toujours la même.
//

import SwiftUI
import UIKit
import AVFoundation
import AudioToolbox

// MARK: - Animation (identique à `Desktop/Swift/DIQRScanner`)

private let kScannerExpandCollapseAnimation = Animation.interpolatingSpring(duration: 0.35, bounce: 0, initialVelocity: 0)
private let kScannerRevealDelayNanoseconds: UInt64 = 50_000_000
private let kScannerLaserSweepDuration: Double = 0.85
private let kScannerLaserSweepDelay: Double = 0.1
private let kScannerRevealBlurRadius: CGFloat = 15

fileprivate struct CameraProperties {
    var session: AVCaptureSession = .init()
    var output: AVCaptureMetadataOutput = .init()
    var scannedCode: String?
    var permissionState: Permission?

    enum Permission: String {
        case idle = "Not Determined"
        case approved = "Access Granted"
        case denied = "Access Denied"
    }

    static func checkAndAskCameraPermission() async -> Permission? {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return Permission.approved
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) {
                return Permission.approved
            } else {
                return Permission.denied
            }
        case .denied, .restricted: return Permission.denied
        default: return nil
        }
    }
}

extension View {
    @ViewBuilder
    func qrScanner(isScanning: Binding<Bool>, onScan: @escaping (String) -> Void) -> some View {
        self.modifier(QRScannerViewModifier(isScanning: isScanning, onScan: onScan))
    }
}

fileprivate struct QRScannerViewModifier: ViewModifier {
    @Binding var isScanning: Bool
    var onScan: (String) -> Void

    @State private var showFullScreenCover: Bool = false

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showFullScreenCover) {
                DIQRScannerView {
                    isScanning = false
                    Task { @MainActor in
                        showFullScreenCoverWithoutAnimation(false)
                    }
                } onScan: { code in
                    onScan(code)
                }
                .presentationBackground(.clear)
            }
            .onChange(of: isScanning) { _, newValue in
                if newValue {
                    showFullScreenCoverWithoutAnimation(true)
                }
            }
    }

    private func showFullScreenCoverWithoutAnimation(_ status: Bool) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showFullScreenCover = status
        }
    }
}

fileprivate struct DIQRScannerView: View {
    var onClose: () -> Void
    var onScan: (String) -> Void

    @State private var isInitialized: Bool = false
    @State private var showContent: Bool = false
    @State private var isExpanding: Bool = false
    @State private var camera: CameraProperties = .init()
    @Environment(\.openURL) private var openURL

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let safeArea = geo.safeAreaInsets

            let haveDynamicIsland: Bool = safeArea.top >= 59
            let dynamicIslandWidth: CGFloat = 120
            let dynamicIslandHeight: CGFloat = 36
            let topOffset: CGFloat = haveDynamicIsland
                ? (11 + max((safeArea.top - 59), 0))
                : (isExpanding ? (nonDynamicIslandHaveSpacing ? safeArea.top : -20) : -50)

            let expandedWidth: CGFloat = size.width - 30
            let expandedHeight: CGFloat = expandedWidth

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .contentShape(.rect)
                    .opacity(isExpanding ? 1 : 0)
                    .onTapGesture {
                        toggle(false)
                    }

                if showContent {
                    MFConcentricShapeFallback(minimumCorner: 30)
                        .fill(.black)
                        .overlay {
                            GeometryReader { camGeo in
                                let cameraSize = camGeo.size
                                ScannerView(cameraSize)
                            }
                            .overlay(alignment: .bottom) {
                                Text("Scannez le code QR")
                                    .font(.caption2)
                                    .foregroundStyle(.white.secondary)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .offset(y: 25)
                            }
                            .padding(80)
                            .compositingGroup()
                            .blur(radius: isExpanding ? 0 : kScannerRevealBlurRadius)
                            .opacity(isExpanding ? 1 : 0)
                            .geometryGroup()
                            .offset(y: nonDynamicIslandHaveSpacing || haveDynamicIsland ? 0 : 10)
                        }
                        .overlay {
                            PermissionDeniedView()
                        }
                        .frame(
                            width: isExpanding ? expandedWidth : dynamicIslandWidth,
                            height: isExpanding ? expandedHeight : dynamicIslandHeight
                        )
                        .offset(y: topOffset)
                        .background {
                            if isExpanding {
                                Rectangle()
                                    .fill(.clear)
                                    .onDisappear {
                                        showContent = false
                                    }
                            }
                        }
                        .transition(.identity)
                        .onDisappear {
                            onClose()
                        }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .task {
                guard !isInitialized else { return }
                isInitialized = true
                showContent = true
                try? await Task.sleep(nanoseconds: kScannerRevealDelayNanoseconds)
                toggle(true)
                camera.permissionState = await CameraProperties.checkAndAskCameraPermission()
            }
            .onChange(of: camera.scannedCode) { _, newValue in
                if let newValue {
                    onScan(newValue)
                    toggle(false)
                }
            }
        }
        .statusBarHidden()
    }

    @ViewBuilder
    private func ScannerView(_ size: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

        ZStack {
            if let permissionState = camera.permissionState {
                if permissionState == .approved {
                    CameraLayerView(size: size, camera: $camera)
                        .overlay(alignment: .top) {
                            ScannerAnimation(size.height)
                        }
                }
            }

            shape
                .stroke(.white, lineWidth: 2)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
    }

    @ViewBuilder
    private func PermissionDeniedView() -> some View {
        VStack(spacing: 4) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 45))
                .foregroundStyle(.white)

            Text("Permission refusée")
                .font(.caption)
                .foregroundStyle(.red)

            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Button("Réglages") {
                    openURL(settingsURL)
                }
                .font(.caption)
                .foregroundStyle(.white)
                .underline()
            }
        }
        .fixedSize()
        .compositingGroup()
        .opacity(camera.permissionState == .denied ? 1 : 0)
        .blur(radius: isExpanding ? 0 : kScannerRevealBlurRadius)
        .opacity(isExpanding ? 1 : 0)
    }

    @ViewBuilder
    private func ScannerAnimation(_ height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white)
            .frame(height: 2.5)
            .phaseAnimator([false, true], content: { content, isScanning in
                content
                    .shadow(color: .black.opacity(0.8), radius: 8, x: 0, y: isScanning ? 15 : -15)
                    .offset(y: isScanning ? height : 0)
            }, animation: { _ in
                .easeInOut(duration: kScannerLaserSweepDuration).delay(kScannerLaserSweepDelay)
            })
    }

    private func toggle(_ status: Bool) {
        withAnimation(kScannerExpandCollapseAnimation) {
            isExpanding = status
        }

        if !status {
            DispatchQueue.global(qos: .background).async {
                camera.session.stopRunning()
            }
        }
    }

    private var nonDynamicIslandHaveSpacing: Bool { true }
}

fileprivate struct CameraLayerView: UIViewRepresentable {
    var size: CGSize
    @Binding var camera: CameraProperties

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .init(origin: .zero, size: size))
        view.backgroundColor = .clear

        let layer = AVCaptureVideoPreviewLayer(session: camera.session)
        layer.frame = .init(origin: .zero, size: size)
        layer.videoGravity = .resizeAspectFill
        layer.masksToBounds = true
        view.layer.addSublayer(layer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: CameraLayerView

        init(parent: CameraLayerView) {
            self.parent = parent
            super.init()
            Task {
                setupCamera()
            }
        }

        func setupCamera() {
            do {
                let session = parent.camera.session
                let output = parent.camera.output

                guard !session.isRunning else { return }
                guard let device = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera],
                    mediaType: .video,
                    position: .back
                ).devices.first else {
                    return
                }

                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input), session.canAddOutput(output) else {
                    return
                }

                session.beginConfiguration()
                session.addInput(input)
                session.addOutput(output)
                output.metadataObjectTypes = [.qr]
                output.setMetadataObjectsDelegate(self, queue: .main)
                session.commitConfiguration()

                DispatchQueue.global(qos: .background).async {
                    session.startRunning()
                }
            } catch {}
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            if let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let code = object.stringValue {
                guard parent.camera.scannedCode == nil else { return }
                parent.camera.scannedCode = code
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
}
