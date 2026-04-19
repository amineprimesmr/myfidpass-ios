//
//  LogoCarouselCameraSupport.swift
//  myfidpass
//
//  Prévisualisation caméra dans la tuile gauche du carrousel + capture plein écran.
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

// MARK: - Session (aperçu seul, sans sortie métadonnées)

private final class LogoCarouselSessionRunner: @unchecked Sendable {
    let session: AVCaptureSession
    init(_ session: AVCaptureSession) { self.session = session }
    func start() { session.startRunning() }
    func stop() { session.stopRunning() }
}

final class LogoCarouselInlineCamera: ObservableObject {
    let session = AVCaptureSession()
    @Published private(set) var canShowLivePreview = false

    private var didConfigure = false
    private var isBootstrapScheduled = false

    func bootstrapIfNeeded() {
        guard !didConfigure else {
            restartRunningIfNeeded()
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Pas d’attente async : démarrage immédiat quand l’utilisateur a déjà accepté la caméra.
            performConfigure()
        case .notDetermined:
            guard !isBootstrapScheduled else { return }
            isBootstrapScheduled = true
            Task(priority: .userInitiated) {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                await MainActor.run {
                    self.isBootstrapScheduled = false
                    guard granted else {
                        self.canShowLivePreview = false
                        return
                    }
                    guard !self.didConfigure else {
                        self.restartRunningIfNeeded()
                        return
                    }
                    self.performConfigure()
                }
            }
        default:
            canShowLivePreview = false
        }
    }

    private func performConfigure() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        // Après les entrées : preset plus léger que `.photo` pour un démarrage plus rapide de l’aperçu.
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        } else if session.canSetSessionPreset(.medium) {
            session.sessionPreset = .medium
        } else {
            session.sessionPreset = .photo
        }
        session.commitConfiguration()

        guard !session.inputs.isEmpty else {
            canShowLivePreview = false
            isBootstrapScheduled = false
            return
        }

        didConfigure = true
        isBootstrapScheduled = false
        canShowLivePreview = true
        let runner = LogoCarouselSessionRunner(session)
        DispatchQueue.global(qos: .userInteractive).async {
            runner.start()
        }
    }

    func restartRunningIfNeeded() {
        guard didConfigure, !session.isRunning else { return }
        let runner = LogoCarouselSessionRunner(session)
        DispatchQueue.global(qos: .userInteractive).async {
            runner.start()
        }
    }

    func stopRunning() {
        let runner = LogoCarouselSessionRunner(session)
        DispatchQueue.global(qos: .userInitiated).async {
            runner.stop()
        }
    }
}

// MARK: - Calque d’aperçu

final class LogoPreviewHostView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

struct LogoInlineCameraPreviewRepresentable: UIViewRepresentable {
    @ObservedObject var camera: LogoCarouselInlineCamera

    func makeUIView(context: Context) -> LogoPreviewHostView {
        let v = LogoPreviewHostView()
        v.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: camera.session)
        layer.videoGravity = .resizeAspectFill
        v.layer.addSublayer(layer)
        v.previewLayer = layer
        return v
    }

    func updateUIView(_ uiView: LogoPreviewHostView, context: Context) {
        uiView.previewLayer?.session = camera.session
        uiView.previewLayer?.frame = uiView.bounds
    }
}

// MARK: - UIImagePickerController (prise de vue)

struct CameraPhotoPickerRepresentable: UIViewControllerRepresentable {
    var onImage: (UIImage?) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coord {
        Coord(onImage: onImage, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.cameraCaptureMode = .photo
        c.allowsEditing = false
        c.delegate = context.coordinator
        c.modalPresentationStyle = .fullScreen
        return c
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage?) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // Présenté via `fullScreenCover` : pas de `dismiss` sur le picker, SwiftUI retire la vue.
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let img = (info[.originalImage] as? UIImage)
                ?? (info[.editedImage] as? UIImage)
            onImage(img)
        }
    }
}
