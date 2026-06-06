//
//  FlyerNativePreviewView.swift
//  myfidpass
//
//  Aperçu flyer 100 % natif (CoreGraphics) — remplace `FlyerPreviewWebView` pour le canvas flyer.
//

import SwiftUI

struct FlyerNativePreviewView: View {
    let state: FlyerStateDTO
    let shareURL: String
    var underlayImage: UIImage?
    var logoImage: UIImage?
    /// Change quand logo / couleurs / textes changent (UIImage non observable seul).
    var renderFingerprint: String = ""
    @Binding var isLoading: Bool
    /// Image composite rendue (preview) — pour partage sans WebView.
    var onRenderedImage: ((UIImage) -> Void)?

    @State private var compositeImage: UIImage?
    @State private var renderTask: Task<Void, Never>?

    private var renderRequest: FlyerNativeRenderRequest {
        FlyerNativeRenderRequest(
            state: state,
            shareURL: shareURL,
            logoImage: logoImage,
            underlayImage: underlayImage,
            canvasSize: FlyerCanvasPreset.preview,
            overlayOnly: false
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let compositeImage {
                    Image(uiImage: compositeImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                } else if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear { scheduleRender() }
        .onChange(of: renderFingerprint) { _, _ in scheduleRender() }
        .onDisappear {
            renderTask?.cancel()
        }
    }

    private func scheduleRender() {
        renderTask?.cancel()
        let request = renderRequest
        let fingerprint = renderFingerprint

        if let cached = CommerceFlyerRasterCache.image(forNativePreviewFingerprint: fingerprint) {
            compositeImage = cached
            isLoading = false
            onRenderedImage?(cached)
            return
        }

        let spinnerDelayNs: UInt64 = compositeImage == nil ? 120_000_000 : 0
        isLoading = false

        renderTask = Task {
            if spinnerDelayNs > 0 {
                try? await Task.sleep(nanoseconds: spinnerDelayNs)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if compositeImage == nil { isLoading = true }
                }
            }
            guard !Task.isCancelled else { return }
            let scale = min(UIScreen.main.scale, 2.0)
            let image: UIImage? = await Task.detached(priority: .userInitiated) {
                FlyerNativeCanvasRenderer.renderFullComposite(request, scale: scale)
            }.value
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if let image {
                    CommerceFlyerRasterCache.setNativePreviewImage(image, fingerprint: fingerprint)
                    compositeImage = image
                    onRenderedImage?(image)
                }
                isLoading = false
            }
        }
    }
}

enum FlyerNativeExport {
    @MainActor
    static func renderShareImage(
        state: FlyerStateDTO,
        shareURL: String,
        logoImage: UIImage?,
        underlayImage: UIImage?
    ) -> UIImage? {
        let request = FlyerNativeRenderRequest(
            state: state,
            shareURL: shareURL,
            logoImage: logoImage,
            underlayImage: underlayImage,
            canvasSize: FlyerCanvasPreset.export,
            overlayOnly: false
        )
        return FlyerNativeCanvasRenderer.renderFullComposite(request, scale: 1)
    }
}
