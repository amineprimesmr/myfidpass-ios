//
//  GoogleBusinessReviewsListView.swift
//  myfidpass
//
//  Liste complète des avis Google Business avec réponse (+ IA), starred, archivé,
//  filtres (note, non-répondus, starred). Deep-link possible depuis un push.
//

import SwiftUI
import Combine

@MainActor
final class GoogleBusinessReviewsListVM: ObservableObject {
    @Published var reviews: [GoogleBusinessReview] = []
    @Published var counts: GoogleBusinessStatusCounts?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var filter: Filter = .all
    @Published var sort: Sort = .recent

    enum Filter: String, CaseIterable, Identifiable {
        case all, unreplied, starred, negatives
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: return "Tous"
            case .unreplied: return "Non répondus"
            case .starred: return "Mis en favori"
            case .negatives: return "≤ 3 étoiles"
            }
        }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case recent, oldest, ratingAsc, ratingDesc
        var id: String { rawValue }
        var title: String {
            switch self {
            case .recent: return "Récents"
            case .oldest: return "Anciens"
            case .ratingAsc: return "Note ↑"
            case .ratingDesc: return "Note ↓"
            }
        }
        var apiValue: String {
            switch self {
            case .recent: return "recent"
            case .oldest: return "oldest"
            case .ratingAsc: return "rating_asc"
            case .ratingDesc: return "rating_desc"
            }
        }
    }

    private let slug: String

    init(slug: String) { self.slug = slug }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        var query = GoogleBusinessAPI.ReviewsQuery()
        query.limit = 100
        switch filter {
        case .all: break
        case .unreplied: query.sort = "unreplied"
        case .starred: query.sort = "starred"
        case .negatives: query.maxRating = 3
        }
        if filter == .all { query.sort = sort.apiValue }
        do {
            let resp = try await GoogleBusinessAPI.shared.reviews(slug: slug, query: query)
            self.reviews = resp.reviews
            self.counts = resp.counts
            self.errorMessage = nil
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func syncNow() async {
        do {
            _ = try await GoogleBusinessAPI.shared.syncReviews(slug: slug)
            await load()
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func markSeen(_ r: GoogleBusinessReview) {
        Task {
            try? await GoogleBusinessAPI.shared.markReviewSeen(slug: slug, reviewId: r.reviewId)
        }
    }

    func toggleStar(_ r: GoogleBusinessReview) {
        guard let idx = reviews.firstIndex(where: { $0.reviewId == r.reviewId }) else { return }
        let newStarred = !r.starred
        let updated = GoogleBusinessReview(
            reviewId: r.reviewId, locationName: r.locationName, rating: r.rating,
            authorName: r.authorName, authorPhotoUrl: r.authorPhotoUrl, comment: r.comment,
            replyComment: r.replyComment, replyUpdateTime: r.replyUpdateTime,
            createTime: r.createTime, updateTime: r.updateTime, firstSeenAt: r.firstSeenAt,
            starred: newStarred, archived: r.archived, seenByMerchant: r.seenByMerchant
        )
        reviews[idx] = updated
        Task {
            do {
                try await GoogleBusinessAPI.shared.starReview(slug: slug, reviewId: r.reviewId, starred: newStarred)
            } catch {
                reviews[idx] = r
            }
        }
    }

    func toggleArchive(_ r: GoogleBusinessReview) {
        Task {
            do {
                try await GoogleBusinessAPI.shared.archiveReview(slug: slug, reviewId: r.reviewId, archived: !r.archived)
                await load()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription
            }
        }
    }

    func reloadAfterReplyChange(_ updated: GoogleBusinessReview?) {
        guard let updated else { return }
        if let idx = reviews.firstIndex(where: { $0.reviewId == updated.reviewId }) {
            reviews[idx] = updated
        }
    }
}

struct GoogleBusinessReviewsListView: View {
    let slug: String
    var focusedReviewId: String?

    @StateObject private var vm: GoogleBusinessReviewsListVM
    @State private var replyTarget: GoogleBusinessReview?

    init(slug: String, focusedReviewId: String? = nil) {
        self.slug = slug
        self.focusedReviewId = focusedReviewId
        _vm = StateObject(wrappedValue: GoogleBusinessReviewsListVM(slug: slug))
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if vm.isLoading && vm.reviews.isEmpty {
                ProgressView().padding(40)
                Spacer()
            } else if vm.reviews.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Avis clients")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await vm.syncNow() }
                    } label: {
                        Label("Actualiser depuis Google", systemImage: "arrow.clockwise")
                    }
                    Section("Trier") {
                        ForEach(GoogleBusinessReviewsListVM.Sort.allCases) { s in
                            Button {
                                vm.sort = s
                                Task { await vm.load() }
                            } label: {
                                HStack {
                                    Text(s.title)
                                    if vm.sort == s { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.title3)
                }
            }
        }
        .task {
            await vm.load()
            if let id = focusedReviewId, let r = vm.reviews.first(where: { $0.reviewId == id }) {
                replyTarget = r
            }
        }
        .refreshable { await vm.load() }
        .sheet(item: $replyTarget) { r in
            GoogleBusinessReplySheet(slug: slug, review: r) { updated in
                vm.reloadAfterReplyChange(updated)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GoogleBusinessReviewsListVM.Filter.allCases) { f in
                    let isActive = vm.filter == f
                    Button {
                        vm.filter = f
                        Task { await vm.load() }
                    } label: {
                        Text(f.title)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(isActive ? AppTheme.Colors.primary : AppTheme.Colors.primary.opacity(0.10))
                            )
                            .foregroundStyle(isActive ? .white : AppTheme.Colors.primary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.reviews) { r in
                    GoogleBusinessReviewCard(
                        review: r,
                        onReplyTap: {
                            replyTarget = r
                            vm.markSeen(r)
                        },
                        onStarTap: { vm.toggleStar(r) },
                        onArchiveTap: { vm.toggleArchive(r) }
                    )
                    .onAppear {
                        if !r.seenByMerchant { vm.markSeen(r) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "star.bubble")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))
            Text(vm.filter == .all ? "Aucun avis encore" : "Aucun avis dans ce filtre")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Button {
                Task { await vm.syncNow() }
            } label: {
                Label("Importer depuis Google", systemImage: "arrow.clockwise")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AppTheme.Colors.primary.opacity(0.14)))
                    .foregroundStyle(AppTheme.Colors.primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Review card

struct GoogleBusinessReviewCard: View {
    let review: GoogleBusinessReview
    let onReplyTap: () -> Void
    let onStarTap: () -> Void
    let onArchiveTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(review.authorName ?? "Client Google")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        if !review.seenByMerchant {
                            Circle()
                                .fill(AppTheme.Colors.primary)
                                .frame(width: 6, height: 6)
                        }
                    }
                    HStack(spacing: 4) {
                        stars
                        if let ts = review.updatedDate {
                            Text("·  \(Self.relativeFormatter.localizedString(for: ts, relativeTo: Date()))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 2) {
                    Button(action: onStarTap) {
                        Image(systemName: review.starred ? "star.fill" : "star")
                            .font(.body)
                            .foregroundStyle(review.starred ? Color(hex: "F5B301") : AppTheme.Colors.textSecondary)
                            .padding(6)
                    }
                    Menu {
                        Button(role: .destructive) {
                            onArchiveTap()
                        } label: {
                            Label(review.archived ? "Désarchiver" : "Archiver", systemImage: "archivebox")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .padding(6)
                    }
                }
            }

            if let c = review.comment, !c.isEmpty {
                Text(c)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("(Aucun commentaire — juste une note)")
                    .font(.subheadline.italic())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            if review.hasReply, let reply = review.replyComment {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Votre réponse", systemImage: "arrowshape.turn.up.left.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                    Text(reply)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.Colors.primary.opacity(0.06))
                )
            }

            HStack {
                Button(action: onReplyTap) {
                    HStack(spacing: 6) {
                        Image(systemName: review.hasReply ? "pencil.circle.fill" : "arrowshape.turn.up.left.circle.fill")
                        Text(review.hasReply ? "Modifier la réponse" : "Répondre")
                            .font(.footnote.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(AppTheme.Colors.primary))
                    .foregroundStyle(.white)
                }
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.shadow, radius: 4, x: 0, y: 1.5)
        )
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(AppTheme.Colors.primary.opacity(0.15))
                .frame(width: 38, height: 38)
            if let url = review.authorPhotoUrl.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Text((review.authorName?.first).map(String.init) ?? "?")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                .frame(width: 38, height: 38)
                .clipShape(Circle())
            } else {
                Text((review.authorName?.first).map(String.init) ?? "?")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.primary)
            }
        }
    }

    private var stars: some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < review.rating ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "F5B301"))
            }
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .short
        return f
    }()
}
