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

    @State private var overlayImage: UIImage?
    @State private var renderTask: Task<Void, Never>?

    private var renderRequest: FlyerNativeRenderRequest {
        FlyerNativeRenderRequest(
            state: state,
            shareURL: shareURL,
            logoImage: logoImage,
            underlayImage: underlayImage,
            canvasSize: FlyerCanvasPreset.preview,
            overlayOnly: underlayImage != nil
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let underlayImage {
                    FlyerNativeUnderlayStack(state: state, image: underlayImage)
                }
                if let overlayImage {
                    Image(uiImage: overlayImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
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
        isLoading = true
        renderTask = Task {
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled else { return }
            let scale = UIScreen.main.scale
            let image: UIImage? = await Task.detached(priority: .userInitiated) {
                if request.overlayOnly {
                    return FlyerNativeCanvasRenderer.renderOverlay(request, scale: scale)
                }
                return FlyerNativeCanvasRenderer.renderFullComposite(request, scale: scale)
            }.value
            guard !Task.isCancelled else { return }
            await MainActor.run {
                overlayImage = image
                isLoading = false
                if let image {
                    onRenderedImage?(image)
                }
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
