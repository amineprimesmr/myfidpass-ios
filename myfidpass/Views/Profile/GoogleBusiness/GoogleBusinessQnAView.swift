//
//  GoogleBusinessQnAView.swift
//  myfidpass
//
//  Questions & réponses sur la fiche Google Business.
//

import SwiftUI
import Combine

@MainActor
final class GoogleBusinessQnAVM: ObservableObject {
    @Published var questions: [GoogleBusinessQuestion] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let slug: String
    init(slug: String) { self.slug = slug }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.questions = try await GoogleBusinessAPI.shared.listQuestions(slug: slug)
            self.errorMessage = nil
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func answer(_ q: GoogleBusinessQuestion, text: String) async -> Bool {
        do {
            try await GoogleBusinessAPI.shared.answerQuestion(slug: slug, questionId: q.questionId, text: text)
            await load()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func deleteAnswer(_ q: GoogleBusinessQuestion) async {
        do {
            try await GoogleBusinessAPI.shared.deleteAnswer(slug: slug, questionId: q.questionId)
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct GoogleBusinessQnAView: View {
    let slug: String
    @StateObject private var vm: GoogleBusinessQnAVM
    @State private var answerTarget: GoogleBusinessQuestion?

    init(slug: String) {
        self.slug = slug
        _vm = StateObject(wrappedValue: GoogleBusinessQnAVM(slug: slug))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.questions.isEmpty {
                ProgressView().padding(40)
            } else if vm.questions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.questions) { q in
                            questionCard(q)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Questions & réponses")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(item: $answerTarget) { q in
            GoogleBusinessAnswerSheet(question: q) { text in
                Task {
                    _ = await vm.answer(q, text: text)
                }
            }
        }
    }

    @ViewBuilder
    private func questionCard(_ q: GoogleBusinessQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.bubble.fill")
                    .foregroundStyle(Color(hex: "4CAF50"))
                Text(q.authorName ?? "Visiteur Google")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if q.upvoteCount > 0 {
                    Label("\(q.upvoteCount)", systemImage: "hand.thumbsup.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
            }
            Text(q.text ?? "")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if q.answeredByOwner, let ans = q.topAnswerText {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Votre réponse (propriétaire)", systemImage: "person.crop.circle.badge.checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                    Text(ans)
                        .font(.footnote)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.Colors.primary.opacity(0.08))
                )
            } else if let ans = q.topAnswerText {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Réponse communautaire — \(q.topAnswerAuthor ?? "")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text(ans)
                        .font(.footnote)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.Colors.textSecondary.opacity(0.06))
                )
            }

            HStack {
                Button {
                    answerTarget = q
                } label: {
                    Label(q.answeredByOwner ? "Modifier ma réponse" : "Répondre", systemImage: "arrowshape.turn.up.left")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(AppTheme.Colors.primary))
                        .foregroundStyle(.white)
                }
                if q.answeredByOwner {
                    Button(role: .destructive) {
                        Task { await vm.deleteAnswer(q) }
                    } label: {
                        Image(systemName: "trash")
                            .padding(7)
                    }
                }
                Spacer()
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.bubble")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))
            Text("Aucune question sur votre fiche")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text("Les nouvelles questions s'afficheront ici, et vous pourrez y répondre en tant que propriétaire.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct GoogleBusinessAnswerSheet: View {
    let question: GoogleBusinessQuestion
    var onSubmit: (String) -> Void

    @State private var text: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    init(question: GoogleBusinessQuestion, onSubmit: @escaping (String) -> Void) {
        self.question = question
        self.onSubmit = onSubmit
        _text = State(initialValue: question.answeredByOwner ? (question.topAnswerText ?? "") : "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(question.text ?? "")
                    .font(.subheadline)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.cardBackground))
                TextEditor(text: $text)
                    .focused($focused)
                    .padding(10)
                    .frame(minHeight: 180)
                    .background(RoundedRectangle(cornerRadius: 12).fill(AppTheme.Colors.cardBackground))
                Spacer()
            }
            .padding(16)
            .background(AppTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Répondre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Publier") {
                        onSubmit(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    .font(.body.weight(.semibold))
                }
            }
            .onAppear { focused = true }
        }
    }
}
