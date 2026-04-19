//
//  CommercePublicQRSheet.swift
//  myfidpass
//
//  Feuille QR page fidélité — partagée Commerce / paywall.
//

import SwiftUI
import UIKit

struct CommercePublicQRSheet: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss

    private var qrLogicalSide: CGFloat { min(UIScreen.main.bounds.width - 48, 340) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Clients : ils scannent et arrivent sur votre page fidélité.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if urlString.isEmpty {
                        ContentUnavailableView(
                            "Lien indisponible",
                            systemImage: "link.badge.plus",
                            description: Text("Connectez un commerce ou réessayez dans un instant.")
                        )
                    } else if let img = QRCodeGenerator.generateQR(from: urlString, size: qrLogicalSide * UIScreen.main.scale) {
                        Image(uiImage: img)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: qrLogicalSide, height: qrLogicalSide)
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 20).fill(.white))
                            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)

                        Text(urlString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            UIPasteboard.general.string = urlString
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Label("Copier le lien", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        ContentUnavailableView(
                            "QR indisponible",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Réessayez dans un instant.")
                        )
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("QR code fidélité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}
