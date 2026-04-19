//
//  GoogleBusinessReplySheet.swift
//  myfidpass
//
//  Composition et publication de la réponse à un avis Google Business. Intègre la génération IA
//  (ton chaleureux / pro / empathique / décontracté / formel) et la suppression de réponse.
//

import SwiftUI
import Combine

@MainActor
final class GoogleBusinessReplyVM: ObservableObject {
    @Published var text: String
    @Published var tone: Tone = .warm
    @Published var extraContext: String = ""
    @Published var isGenerating: Bool = false
    @Published var isSending: Bool = false
    @Published var isDeleting: Bool = false
    @Published var errorMessage: String?
    @Published var aiSource: String?

    enum Tone: String, CaseIterable, Identifiable {
        case warm, professional, empathetic, playful, formal
        var id: String { rawValue }
        var apiValue: String { rawValue }
        var title: String {
            switch self {
            case .warm: return "Chaleureux"
            case .professional: return "Pro"
            case .empathetic: return "Empathique"
            case .playful: return "Décontracté"
            case .formal: return "Formel"
            }
        }
        var icon: String {
            switch self {
            case .warm: return "heart.fill"
            case .professional: return "briefcase.fill"
            case .empathetic: return "hand.raised.fill"
            case .playful: return "face.smiling.fill"
            case .formal: return "graduationcap.fill"
            }
        }
    }

    let slug: String
    let review: GoogleBusinessReview

    init(slug: String, review: GoogleBusinessReview) {
        self.slug = slug
        self.review = review
        self.text = review.replyComment ?? ""
    }

    func generateAI() async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let r = try await GoogleBusinessAPI.shared.generateReplyAI(
                slug: slug,
                reviewId: review.reviewId,
                tone: tone.apiValue,
                extraContext: extraContext.isEmpty ? nil : extraContext
            )
            self.text = r.reply
            self.aiSource = r.source
            self.errorMessage = nil
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func publish() async -> GoogleBusinessReview? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "La réponse est vide."
            return nil
        }
        guard !isSending else { return nil }
        isSending = true
        defer { isSending = false }
        do {
            let updated = try await GoogleBusinessAPI.shared.replyToReview(slug: slug, reviewId: review.reviewId, comment: trimmed)
            errorMessage = nil
            return updated
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    func delete() async -> GoogleBusinessReview? {
        guard !isDeleting else { return nil }
        isDeleting = true
        defer { isDeleting = false }
        do {
            let updated = try await GoogleBusinessAPI.shared.deleteReviewReply(slug: slug, reviewId: review.reviewId)
            errorMessage = nil
            return updated
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }
}

struct GoogleBusinessReplySheet: View {
    let slug: String
    let review: GoogleBusinessReview
    var onChange: (GoogleBusinessReview?) -> Void

    @StateObject private var vm: GoogleBusinessReplyVM
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var showDeleteConfirm = false

    init(slug: String, review: GoogleBusinessReview, onChange: @escaping (GoogleBusinessReview?) -> Void) {
        self.slug = slug
        self.review = review
        self.onChange = onChange
        _vm = StateObject(wrappedValue: GoogleBusinessReplyVM(slug: slug, review: review))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    reviewRecap
                    aiToolbar
                    editor
                    if let err = vm.errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    if review.hasReply {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Supprimer ma réponse", systemImage: "trash")
                                .font(.footnote.weight(.semibold))
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Répondre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            if let updated = await vm.publish() {
                                onChange(updated)
                                dismiss()
                            }
                        }
                    } label: {
                        if vm.isSending { ProgressView().controlSize(.small) }
                        else {
                            Text(review.hasReply ? "Mettre à jour" : "Publier")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .disabled(vm.isSending || vm.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Supprimer la réponse publiée sur Google ?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    Task {
                        if let updated = await vm.delete() {
                            onChange(updated)
                            dismiss()
                        }
                    }
                }
                Button("Annuler", role: .cancel) {}
            }
            .onAppear { focused = true }
        }
    }

    // MARK: - Recap

    private var reviewRecap: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Image(systemName: i < review.rating ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "F5B301"))
                }
                Text(review.authorName ?? "Client")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            } else {
                Text("(Note seule, sans commentaire)")
                    .font(.footnote.italic())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.shadow, radius: 2, x: 0, y: 1)
        )
    }

    // MARK: - AI

    private var aiToolbar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(AppTheme.Colors.primary)
                Text("Générer une réponse avec IA")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GoogleBusinessReplyVM.Tone.allCases) { t in
                        Button {
                            vm.tone = t
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: t.icon)
                                Text(t.title)
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(vm.tone == t ? AppTheme.Colors.primary : AppTheme.Colors.primary.opacity(0.12))
                            )
                            .foregroundStyle(vm.tone == t ? .white : AppTheme.Colors.primary)
                        }
                    }
                }
            }
            TextField("Consignes optionnelles (ex. 'proposer de revenir')", text: $vm.extraContext)
                .font(.footnote)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await vm.generateAI() }
            } label: {
                HStack(spacing: 8) {
                    if vm.isGenerating { ProgressView().controlSize(.small) }
                    else { Image(systemName: "wand.and.stars") }
                    Text(vm.isGenerating ? "Génération…" : "Générer avec IA")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.primary.opacity(0.14))
                )
                .foregroundStyle(AppTheme.Colors.primary)
            }
            .disabled(vm.isGenerating)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.shadow, radius: 2, x: 0, y: 1)
        )
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ma réponse")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            TextEditor(text: $vm.text)
                .focused($focused)
                .frame(minHeight: 160)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.Colors.cardBackground)
                        .shadow(color: AppTheme.Colors.shadow, radius: 2, x: 0, y: 1)
                )
            HStack {
                Text("\(vm.text.count) / 4000 caractères")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Spacer()
                if let src = vm.aiSource {
                    Text(src == "openai" ? "IA — OpenAI" : "IA locale")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }
}
