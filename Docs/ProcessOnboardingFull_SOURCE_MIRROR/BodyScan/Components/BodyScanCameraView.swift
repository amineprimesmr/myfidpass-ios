//
//  BodyScanCameraView.swift
//  Process
//
//  Vue caméra pour le scan corporel avec preview et overlay
//

import SwiftUI
import AVFoundation
import UIKit

struct BodyScanCameraView: View {
    @ObservedObject var cameraManager: BodyScanCameraManager
    @Binding var isBodyDetected: Bool
    @Binding var showSilhouette: Bool
    let onCapture: () -> Void

    @State private var previewLayer: AVCaptureVideoPreviewLayer?

    var body: some View {
        ZStack {
            // Preview caméra
            BodyScanCameraPreviewLayer(cameraManager: cameraManager)
                .ignoresSafeArea()

            // Overlay silhouette guidage
            if showSilhouette {
                BodyScanSilhouetteOverlay(isBodyDetected: isBodyDetected)
                    .transition(.opacity)
            }

            // Indicateur de détection
            if isBodyDetected {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .padding(.trailing, 20)
                            .padding(.bottom, 100)
                    }
                }
            }
        }
        .onChange(of: cameraManager.isBodyDetected) { _, newValue in
            isBodyDetected = newValue
        }
    }
}

// MARK: - Preview Layer
struct BodyScanCameraPreviewLayer: UIViewControllerRepresentable {
    @ObservedObject var cameraManager: BodyScanCameraManager

    func makeUIViewController(context: Context) -> BodyScanCameraPreviewViewController {
        let controller = BodyScanCameraPreviewViewController()
        controller.cameraManager = cameraManager
        return controller
    }

    func updateUIViewController(_ uiViewController: BodyScanCameraPreviewViewController, context: Context) {}
}

class BodyScanCameraPreviewViewController: UIViewController {
    var cameraManager: BodyScanCameraManager?
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPreview()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupPreview() {
        guard let session = cameraManager?.captureSession else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.setupPreview()
            }
            return
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds

        view.layer.addSublayer(layer)
        previewLayer = layer
    }
}

// MARK: - Silhouette Overlay
struct BodyScanSilhouetteOverlay: View {
    let isBodyDetected: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Masque sombre autour
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                // Zone de scan (silhouette)
                Path { path in
                    let centerX = geometry.size.width / 2
                    let topY = geometry.size.height * 0.15
                    let bottomY = geometry.size.height * 0.85
                    let width = geometry.size.width * 0.6

                    // Silhouette simplifiée (forme ovale/haute)
                    let rect = CGRect(
                        x: centerX - width / 2,
                        y: topY,
                        width: width,
                        height: bottomY - topY
                    )
                    path.addEllipse(in: rect)
                }
                .fill(Color.clear)
                .overlay(
                    Path { path in
                        let centerX = geometry.size.width / 2
                        let topY = geometry.size.height * 0.15
                        let bottomY = geometry.size.height * 0.85
                        let width = geometry.size.width * 0.6

                        let rect = CGRect(
                            x: centerX - width / 2,
                            y: topY,
                            width: width,
                            height: bottomY - topY
                        )
                        path.addEllipse(in: rect)
                    }
                    .stroke(
                        isBodyDetected ? Color.green : Color.white.opacity(0.7),
                        lineWidth: 3
                    )
                )
                .blendMode(.destinationOut)
            }
        }
    }
}
