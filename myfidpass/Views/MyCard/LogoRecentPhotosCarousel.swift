//
//  LogoRecentPhotosCarousel.swift
//  myfidpass
//
//  Bandeau horizontal : tuile caméra + miniatures récentes (même taille, tout défile ensemble).
//

import AVFoundation
import Photos
import SwiftUI
import UIKit

struct LogoRecentPhotosCarousel: View {
    /// Sélection d’une image existante dans la photothèque.
    let onSelectAsset: (PHAsset) -> Void
    /// Photo capturée avec l’appareil (après l’écran de prise de vue).
    let onCameraImage: (UIImage) -> Void

    /// Côté affiché des vignettes et de la tuile caméra (carrousel modificateurs logo / fond).
    private let thumb: CGFloat = 84
    private let maxGalleryFetch = 200

    @StateObject private var inlineCamera = LogoCarouselInlineCamera()
    @State private var recents: [PHAsset] = []
    @State private var showCameraCapture = false
    @State private var showCameraUnavailableAlert = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                cameraTileInCarousel
                ForEach(recents, id: \.localIdentifier) { asset in
                    Button {
                        onSelectAsset(asset)
                    } label: {
                        LogoAssetThumbView(asset: asset, side: thumb)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: thumb + 12)
        .task(priority: .userInitiated) {
            await loadRecents()
        }
        .onAppear {
            inlineCamera.bootstrapIfNeeded()
        }
        .onDisappear {
            inlineCamera.stopRunning()
            LogoCarouselPhotoThumbnails.stopCachingAll()
        }
        .onChange(of: showCameraCapture) { _, open in
            if open {
                inlineCamera.stopRunning()
            } else {
                inlineCamera.restartRunningIfNeeded()
            }
        }
        .fullScreenCover(isPresented: $showCameraCapture) {
            CameraPhotoPickerRepresentable(
                onImage: { image in
                    showCameraCapture = false
                    if let image {
                        onCameraImage(image)
                    }
                },
                onCancel: {
                    showCameraCapture = false
                }
            )
            .ignoresSafeArea()
        }
        .alert("Appareil photo indisponible", isPresented: $showCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Ce dispositif n’a pas d’appareil photo accessible (ex. simulateur). Utilisez « Choisir depuis la galerie » ou une miniature ci-dessus.")
        }
    }

    /// Icône seulement si l’accès caméra est définitivement refusé ; sinon aperçu (noir → flux dès que la session tourne).
    private var isCameraAccessHardDenied: Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    /// Même gabarit que les vignettes galerie : fait partie du défilement horizontal.
    private var cameraTileInCarousel: some View {
        Button {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                showCameraCapture = true
            } else {
                showCameraUnavailableAlert = true
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))

                if isCameraAccessHardDenied {
                    Image(systemName: "camera.fill")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                } else {
                    LogoInlineCameraPreviewRepresentable(camera: inlineCamera)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)

                Image(systemName: "viewfinder")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 2, x: 0, y: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(8)
            }
            .frame(width: thumb, height: thumb)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Prendre une photo avec l’appareil photo"))
    }

    private func loadRecents() async {
        guard await ensurePhotoLibraryAccess() else { return }

        let limit = maxGalleryFetch
        let thumbSide = thumb
        let list = await Task.detached(priority: .userInitiated) { () -> [PHAsset] in
            let opts = PHFetchOptions()
            opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            opts.fetchLimit = limit
            let result = PHAsset.fetchAssets(with: .image, options: opts)
            var arr: [PHAsset] = []
            arr.reserveCapacity(min(limit, 64))
            result.enumerateObjects { asset, _, stop in
                arr.append(asset)
                if arr.count >= limit { stop.pointee = true }
            }
            return arr
        }.value

        await MainActor.run {
            recents = list
            LogoCarouselPhotoThumbnails.startCachingFirstPage(assets: list, side: thumbSide, limit: 40)
        }
    }

    private func ensurePhotoLibraryAccess() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            return newStatus == .authorized || newStatus == .limited
        default:
            return false
        }
    }
}

struct LogoAssetThumbView: View {
    let asset: PHAsset
    let side: CGFloat
    @State private var ui: UIImage?
    /// Ignore les callbacks PHImageManager arrivés après recyclage / changement d’asset.
    @State private var thumbLoadGeneration = 0

    var body: some View {
        Group {
            if let ui {
                Image(uiImage: ui)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                Color(uiColor: .tertiarySystemFill)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            thumbLoadGeneration += 1
            requestThumb(generation: thumbLoadGeneration)
        }
        .onChange(of: asset.localIdentifier) { _, _ in
            ui = nil
            thumbLoadGeneration += 1
            requestThumb(generation: thumbLoadGeneration)
        }
    }

    private func requestThumb(generation: Int) {
        let target = LogoCarouselPhotoThumbnails.thumbnailPointSize(side: side)
        let opts = LogoCarouselPhotoThumbnails.requestOptionsCarouselThumbnail()
        let requestedAsset = asset
        LogoCarouselPhotoThumbnails.sharedManager.requestImage(
            for: requestedAsset,
            targetSize: target,
            contentMode: .aspectFill,
            options: opts
        ) { image, info in
            if (info?[PHImageCancelledKey] as? Bool) == true { return }
            guard let image else { return }
            Task { @MainActor in
                guard generation == thumbLoadGeneration else { return }
                guard requestedAsset.localIdentifier == asset.localIdentifier else { return }
                ui = image
            }
        }
    }
}

extension PHAsset {
    /// Image pleine qualité pour enregistrer le logo localement.
    func myfid_exportUIImage() async -> UIImage? {
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.isNetworkAccessAllowed = true
            opts.version = .current
            PHImageManager.default().requestImageDataAndOrientation(for: self, options: opts) { data, _, _, _ in
                if let data, let img = UIImage(data: data) {
                    cont.resume(returning: img)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
