//
//  GoogleBusinessPostsView.swift
//  myfidpass
//
//  Publier et gérer les « Posts Google » (What's New, Event, Offer).
//

import SwiftUI
import Combine

@MainActor
final class GoogleBusinessPostsVM: ObservableObject {
    @Published var posts: [GoogleBusinessPost] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let slug: String
    init(slug: String) { self.slug = slug }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.posts = try await GoogleBusinessAPI.shared.listPosts(slug: slug)
            self.errorMessage = nil
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func delete(_ post: GoogleBusinessPost) async {
        do {
            try await GoogleBusinessAPI.shared.deletePost(slug: slug, postId: post.postId)
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct GoogleBusinessPostsView: View {
    let slug: String
    @StateObject private var vm: GoogleBusinessPostsVM
    @State private var showComposer = false

    init(slug: String) {
        self.slug = slug
        _vm = StateObject(wrappedValue: GoogleBusinessPostsVM(slug: slug))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.posts.isEmpty {
                ProgressView().padding(40)
            } else if vm.posts.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.posts) { p in
                            postCard(p)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Publications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showComposer = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $showComposer) {
            GoogleBusinessPostComposer(slug: slug) { created in
                if created { Task { await vm.load() } }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "megaphone")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))
            Text("Aucune publication pour le moment")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text("Partagez vos actualités, événements ou offres directement sur votre fiche Google.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                showComposer = true
            } label: {
                Label("Créer une publication", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(AppTheme.Colors.primary))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func postCard(_ p: GoogleBusinessPost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                topicBadge(p.topic)
                Spacer()
                if p.isLive {
                    Text("EN LIGNE")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                        .foregroundStyle(Color.green)
                } else if let s = p.state {
                    Text(s.uppercased())
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Color.gray.opacity(0.15)))
                        .foregroundStyle(Color.gray)
                }
            }
            if let media = p.mediaUrl, let url = URL(string: media) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.textSecondary.opacity(0.1))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if let title = p.eventTitle, !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            if let summary = p.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if p.topic == .offer, let coupon = p.offerCoupon, !coupon.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "ticket.fill")
                    Text("Code : \(coupon)")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.orange.opacity(0.14)))
                .foregroundStyle(Color.orange)
            }
            HStack {
                if let url = p.searchUrl.flatMap(URL.init(string:)) {
                    Link(destination: url) {
                        Label("Voir sur Google", systemImage: "safari")
                            .font(.caption.weight(.semibold))
                    }
                }
                Spacer()
                Menu {
                    Button(role: .destructive) {
                        Task { await vm.delete(p) }
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.shadow, radius: 4, x: 0, y: 1.5)
        )
    }

    private func topicBadge(_ kind: GoogleBusinessPost.TopicKind) -> some View {
        let (label, icon, color): (String, String, Color) = {
            switch kind {
            case .standard: return ("Actualité", "megaphone", .blue)
            case .event: return ("Événement", "calendar", .purple)
            case .offer: return ("Offre", "tag", .orange)
            case .alert: return ("Alerte", "exclamationmark.triangle", .red)
            }
        }()
        return HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.15)))
        .foregroundStyle(color)
    }
}

// MARK: - Composer

struct GoogleBusinessPostComposer: View {
    let slug: String
    var onCreated: (Bool) -> Void

    enum Kind: String, CaseIterable, Identifiable {
        case standard = "STANDARD"
        case event = "EVENT"
        case offer = "OFFER"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .standard: return "Actualité"
            case .event: return "Événement"
            case .offer: return "Offre"
            }
        }
    }

    @State private var kind: Kind = .standard
    @State private var summary: String = ""
    @State private var mediaUrl: String = ""
    @State private var ctaType: String = ""
    @State private var ctaUrl: String = ""
    @State private var eventTitle: String = ""
    @State private var eventStart: Date = Date()
    @State private var eventEnd: Date = Date().addingTimeInterval(3600)
    @State private var offerCoupon: String = ""
    @State private var offerRedeemUrl: String = ""
    @State private var offerTerms: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String?

    @Environment(\.dismiss) private var dismiss

    private static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(Kind.allCases) { k in Text(k.title).tag(k) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Contenu") {
                    TextField("Texte de la publication (requis)", text: $summary, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("URL image (optionnel, https://...)", text: $mediaUrl)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
                Section("Bouton d'action (optionnel)") {
                    Picker("Type", selection: $ctaType) {
                        Text("— Aucun —").tag("")
                        Text("Appeler").tag("CALL")
                        Text("Réserver").tag("BOOK")
                        Text("Commander").tag("ORDER")
                        Text("Acheter").tag("SHOP")
                        Text("En savoir plus").tag("LEARN_MORE")
                        Text("S'inscrire").tag("SIGN_UP")
                    }
                    if !ctaType.isEmpty && ctaType != "CALL" {
                        TextField("Lien (https://)", text: $ctaUrl)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                    }
                }
                if kind == .event {
                    Section("Événement") {
                        TextField("Titre", text: $eventTitle)
                        DatePicker("Début", selection: $eventStart, displayedComponents: .date)
                        DatePicker("Fin", selection: $eventEnd, displayedComponents: .date)
                    }
                }
                if kind == .offer {
                    Section("Offre promotionnelle") {
                        TextField("Code coupon (ex. AMI20)", text: $offerCoupon)
                            .autocapitalization(.allCharacters)
                        TextField("Lien de l'offre (optionnel)", text: $offerRedeemUrl)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                        TextField("Conditions d'utilisation", text: $offerTerms, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
                if let err = errorMessage {
                    Section { Text(err).font(.footnote).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Nouvelle publication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await send() }
                    } label: {
                        if isSending { ProgressView().controlSize(.small) }
                        else { Text("Publier").font(.body.weight(.semibold)) }
                    }
                    .disabled(isSending || summary.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        var payload = GoogleBusinessAPI.CreatePostPayload(summary: summary)
        payload.topicType = kind.rawValue
        if !mediaUrl.trimmingCharacters(in: .whitespaces).isEmpty {
            payload.mediaUrl = mediaUrl
        }
        if !ctaType.isEmpty {
            payload.ctaType = ctaType
            if ctaType != "CALL" {
                payload.ctaUrl = ctaUrl.isEmpty ? nil : ctaUrl
            }
        }
        if kind == .event {
            payload.eventTitle = eventTitle
            payload.eventStart = Self.isoDate.string(from: eventStart)
            payload.eventEnd = Self.isoDate.string(from: eventEnd)
        }
        if kind == .offer {
            payload.offerCoupon = offerCoupon.isEmpty ? nil : offerCoupon
            payload.offerRedeemOnlineUrl = offerRedeemUrl.isEmpty ? nil : offerRedeemUrl
            payload.offerTerms = offerTerms.isEmpty ? nil : offerTerms
        }
        do {
            _ = try await GoogleBusinessAPI.shared.createPost(slug: slug, payload: payload)
            onCreated(true)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
