//
//  ImageCropEditorView.swift
//  myfidpass
//

import SwiftUI

/// Plein écran : fond clair, cadrage géré par `ImageCropScrollView` (voile hors zone + fenêtre centrée).
struct ImageCropEditorView: View {
    let spec: ImageCropSpec
    let sourceImage: UIImage
    var onCancel: () -> Void
    var onComplete: (UIImage) -> Void

    @State private var exportHandle = ImageCropExportHandle()
    /// Dernière confirmation avant enregistrement (icône notification uniquement).
    @State private var showNotificationIconConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                instructionHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                GeometryReader { geo in
                    let side = max(0, geo.size.width - 24)
                    ImageCropScrollView(
                        image: sourceImage,
                        aspectRatio: spec.aspectWidthOverHeight,
                        exportHandle: exportHandle
                    )
                    .frame(width: side, height: geo.size.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(spec.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Définir") {
                        switch spec {
                        case .squareIcon:
                            showNotificationIconConfirm = true
                        default:
                            validateCrop()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
            .alert("Êtes-vous sûr ?", isPresented: $showNotificationIconConfirm) {
                Button("Annuler", role: .cancel) {}
                Button("Enregistrer") { validateCrop() }
            } message: {
                Text(
                    "Une dernière confirmation avant enregistrement : cette icône ne pourra plus être modifiée (iOS conserve la première image). Souhaitez-vous continuer ?"
                )
            }
        }
        .preferredColorScheme(.light)
        .tint(Color(uiColor: .label))
        // Feuille « verre » en dessous (ex. personnalisation carte) : sans fond opaque, l’aperçu carte transparaît et gêne le cadrage.
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - En-tête (UX lisible : pas de micro-texte gris illisible)

    @ViewBuilder
    private var instructionHeader: some View {
        switch spec {
        case .squareIcon:
            notificationIconInstructionCard
        default:
            Text(spec.hint)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .label))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
        }
    }

    /// Information contractuelle : pas de conditionnel « peut » — limitation iOS réelle et définitive.
    private var notificationIconInstructionCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(uiColor: .systemOrange))
                .padding(.top, 2)
                .accessibilityHidden(true)

            (
                Text("Cette icône ne pourra ")
                + Text("plus être modifiée")
                    .fontWeight(.bold)
                + Text(" : ")
                + Text("iOS conserve définitivement")
                    .fontWeight(.semibold)
                + Text(" la ")
                + Text("première image")
                    .fontWeight(.bold)
                + Text(" enregistrée.")
            )
            .font(.body)
            .foregroundStyle(Color(uiColor: .label))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(
                "Cette icône ne pourra plus être modifiée : iOS conserve définitivement la première image enregistrée."
            )
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private func validateCrop() {
        let cropped = exportHandle.makeCroppedUIImage()
            ?? ImageCropExport.centeredAspectFillCrop(source: sourceImage, aspectRatio: spec.aspectWidthOverHeight)
        guard let base = cropped,
              let resized = base.myfid_resized(to: spec.exportPixelSize) else {
            onCancel()
            return
        }
        onComplete(resized)
    }
}

// MARK: - Secours (sans coordinateur UIKit)

enum ImageCropExport {
    /// Cadrage centré si l’export depuis le scroll a échoué.
    static func centeredAspectFillCrop(source: UIImage, aspectRatio: CGFloat) -> UIImage? {
        let iw = source.size.width
        let ih = source.size.height
        guard iw > 0, ih > 0 else { return nil }
        let cropAspect = aspectRatio
        var cropW = iw
        var cropH = cropW / cropAspect
        if cropH > ih {
            cropH = ih
            cropW = cropH * cropAspect
        }
        let origin = CGPoint(
            x: max(0, (iw - cropW) * 0.5),
            y: max(0, (ih - cropH) * 0.5)
        )
        let rect = CGRect(origin: origin, size: CGSize(width: cropW, height: cropH))
        return source.myfid_crop(to: rect)
    }
}
