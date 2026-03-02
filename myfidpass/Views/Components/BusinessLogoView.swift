//
//  BusinessLogoView.swift
//  myfidpass
//
//  Affiche le logo du commerce (fichier local, URL API authentifiée, ou URL externe).
//

import SwiftUI

struct BusinessLogoView: View {
    var logoURL: String?
    var size: CGFloat = 80
    var cornerRadius: CGFloat = 20

    var body: some View {
        Group {
            if let urlString = logoURL?.trimmingCharacters(in: .whitespaces), !urlString.isEmpty {
                logoImage(from: urlString)
            } else {
                Image(systemName: "building.2.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(AppTheme.Colors.primary.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func logoImage(from urlString: String) -> some View {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        let filePath: String? = if trimmed.hasPrefix("/") || trimmed.hasPrefix("file:") {
            trimmed.hasPrefix("file:") ? URL(string: trimmed)?.path : trimmed
        } else if trimmed.contains("CardLogos"), let full = CardLogoStorage.fullPath(forRelative: trimmed) {
            full
        } else {
            nil
        }
        if let path = filePath {
            let url = URL(fileURLWithPath: path)
            if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                logoPlaceholder
            }
        } else if let url = URL(string: trimmed), isAPILogoURL(url) {
            ProfileAuthenticatedLogoView(url: url, size: size)
        } else if let url = URL(string: trimmed) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    logoPlaceholder
                @unknown default:
                    logoPlaceholder
                }
            }
        } else {
            logoPlaceholder
        }
    }

    private func isAPILogoURL(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https" else { return false }
        return url.host() == APIConfig.baseURL.host() && url.path.contains("/logo")
    }

    private var logoPlaceholder: some View {
        Image(systemName: "photo.circle.fill")
            .font(.system(size: size * 0.5))
            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.6))
    }
}

// Chargement du logo depuis l’API (Bearer).
private struct ProfileAuthenticatedLogoView: View {
    let url: URL
    let size: CGFloat
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if failed {
                Image(systemName: "photo.circle.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.6))
            } else {
                ProgressView()
                    .tint(AppTheme.Colors.primary)
            }
        }
        .task(id: url.absoluteString) {
            guard image == nil, !failed else { return }
            guard let token = AuthStorage.authToken, !token.isEmpty else { failed = true; return }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.cachePolicy = .reloadIgnoringLocalCacheData
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                      let img = UIImage(data: data) else {
                    await MainActor.run { failed = true }
                    return
                }
                await MainActor.run { image = img }
            } catch {
                await MainActor.run { failed = true }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BusinessLogoView(logoURL: nil)
        BusinessLogoView(logoURL: "https://via.placeholder.com/100", size: 60)
    }
    .padding()
}
