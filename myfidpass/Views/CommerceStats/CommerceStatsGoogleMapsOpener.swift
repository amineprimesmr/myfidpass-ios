//
//  CommerceStatsGoogleMapsOpener.swift
//  myfidpass
//
//  Ouvre la fiche Google Maps du commerce (avis publics) — pas l’écran de sync in-app.
//  Deep-link onglet Avis : `google_maps_reviews_uri` (API) ou search.google.com/local/reviews.
//

import UIKit

enum CommerceStatsGoogleMapsOpenResult: Equatable {
    case opened
    case missingPlace
    case systemOpenFailed
}

/// Contexte commerce pour les recherches de repli (nom affiché, adresse…).
struct CommerceStatsGoogleMapsContext {
    var businessName: String?
    var organizationName: String?
    var locationAddress: String?

    static func fromAuth(businesses: [BusinessDTO], slug: String, cachedSettings: BusinessSettingsResponse?) -> Self {
        let normSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let match = businesses.first {
            $0.slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normSlug
        }
        return Self(
            businessName: match?.name,
            organizationName: cachedSettings?.organizationName,
            locationAddress: cachedSettings?.locationAddress
        )
    }
}

/// GET /api/businesses/:slug — même contrat que la page jeu QR.
private struct PublicBusinessInfo: Decodable {
    let name: String?
    let organizationName: String?
    let googleReviewWriteUrl: String?
}

private struct PlaceCandidate {
    let placeId: String
    let label: String?
    let priority: Int
}

/// URL Maps avis mise en cache par commerce — ouverture instantanée au tap KPI.
private enum CommerceStatsGoogleMapsURLCache {
    private static func key(_ slug: String) -> String {
        "myfidpass.stats.googleMapsReviewsURL.\(slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    static func read(for slug: String) -> URL? {
        let raw = UserDefaults.standard.string(forKey: key(slug))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    static func store(_ url: URL, for slug: String) {
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSlug.isEmpty else { return }
        UserDefaults.standard.set(url.absoluteString, forKey: key(trimmedSlug))
    }
}

enum CommerceStatsGoogleMapsOpener {
    /// Lien lecture avis Google — compatible place_id `ChIJ…` (ne pas fabriquer `data=!…!1sChIJ` → « invalid coord »).
    static func mapsReviewsURL(placeId: String, query: String? = nil, reviewsUri: String? = nil) -> URL? {
        if let raw = reviewsUri?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        let trimmed = placeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "search.google.com"
        components.path = "/local/reviews"
        var items = [
            URLQueryItem(name: "placeid", value: trimmed),
            URLQueryItem(name: "hl", value: "fr"),
        ]
        if let q = normalizedText(query) {
            items.append(URLQueryItem(name: "q", value: q))
        }
        components.queryItems = items
        return components.url
    }

    /// Format Google Maps documenté — ouvre la fiche lieu (aperçu).
    static func mapsPlaceURL(placeId: String, query: String? = nil) -> URL? {
        let trimmed = placeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/maps/search/"
        var items = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query_place_id", value: trimmed),
        ]
        if let q = normalizedText(query) {
            items.append(URLQueryItem(name: "query", value: q))
        }
        components.queryItems = items
        return components.url
    }

    static func mapsSearchURL(query: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/maps/search/"
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: trimmed),
        ]
        return components.url
    }

    static func placeIdFromGoogleReviewWriteURL(_ urlString: String?) -> String? {
        let raw = urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty, let url = URL(string: raw),
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return nil }
        for item in items {
            let key = item.name.lowercased()
            guard key == "placeid" || key == "place_id" else { continue }
            let value = item.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty { return value }
        }
        return nil
    }

    private static func normalizedPlaceId(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedText(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func placeIdFromEngagementJSON(_ root: [String: Any]) -> String? {
        guard let er = root["engagement_rewards"] as? [String: Any],
              let gr = er["google_review"] as? [String: Any]
        else { return nil }
        return normalizedPlaceId(gr["place_id"] as? String)
    }

    private static func placeIdFromSettingsData(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return placeIdFromEngagementJSON(obj)
    }

    private static func cachedPlaceId(for slug: String) -> String? {
        normalizedPlaceId(
            ScanFlowSettingsCache.cached(for: slug)?
                .engagementRewards?.googleReview?.placeId
        )
    }

    private static func placeId(from settings: BusinessSettingsResponse?) -> String? {
        normalizedPlaceId(settings?.engagementRewards?.googleReview?.placeId)
    }

    private static func defaultSearchLabel(context: CommerceStatsGoogleMapsContext, publicInfo: PublicBusinessInfo?) -> String? {
        let candidates: [String?] = [
            context.organizationName,
            context.businessName,
            context.locationAddress,
            publicInfo?.organizationName,
            publicInfo?.name,
        ]
        for c in candidates {
            if let t = normalizedText(c) { return t }
        }
        return nil
    }

    private struct ResolvedPlaceDetails {
        let label: String?
        let reviewsUri: String?
    }

    private static func resolvePlaceDetails(placeId: String, fallback: String?) async -> ResolvedPlaceDetails? {
        do {
            let res: PlacesPlaceDetailsResponse = try await APIClient.shared.request(.placesPlaceDetails(placeId: placeId))
            let name = normalizedText(res.name)
            let addr = normalizedText(res.formattedAddress)
            let label: String? = {
                if let name, let addr { return "\(name), \(addr)" }
                if let name { return name }
                if let addr { return addr }
                return fallback
            }()
            return ResolvedPlaceDetails(
                label: label,
                reviewsUri: normalizedText(res.googleMapsReviewsUri)
            )
        } catch let error as APIError {
            switch error {
            case .notFound: return nil
            case .server(let code, _) where code == 404: return nil
            default: return ResolvedPlaceDetails(label: fallback, reviewsUri: nil)
            }
        } catch {
            return ResolvedPlaceDetails(label: fallback, reviewsUri: nil)
        }
    }

    private static func instantURLForCandidate(_ candidate: PlaceCandidate) -> URL? {
        mapsReviewsURL(placeId: candidate.placeId, query: candidate.label)
    }

    private static func collectPlaceCandidates(
        slug: String,
        context: CommerceStatsGoogleMapsContext,
        publicInfo: PublicBusinessInfo?,
        settingsPlaceId: String?,
        matchedPlaceId: String?
    ) -> (candidates: [PlaceCandidate], writeReviewURL: String?) {
        let defaultLabel = defaultSearchLabel(context: context, publicInfo: publicInfo)
        var candidates: [PlaceCandidate] = []
        var writeReviewURL: String?

        if let pid = normalizedPlaceId(settingsPlaceId) {
            candidates.append(PlaceCandidate(placeId: pid, label: defaultLabel, priority: 0))
        }
        if let pid = normalizedPlaceId(matchedPlaceId) {
            candidates.append(PlaceCandidate(placeId: pid, label: defaultLabel, priority: 1))
        }
        if let publicInfo {
            writeReviewURL = publicInfo.googleReviewWriteUrl
            if let pid = placeIdFromGoogleReviewWriteURL(publicInfo.googleReviewWriteUrl) {
                candidates.append(PlaceCandidate(placeId: pid, label: defaultLabel, priority: 2))
            }
        }
        let linked = MerchantLinkedPlaceCache.read()
        if let pid = normalizedPlaceId(linked.placeId) {
            candidates.append(PlaceCandidate(placeId: pid, label: normalizedText(linked.description) ?? defaultLabel, priority: 3))
        }
        let pending = FirstLaunchOnboarding.readPendingEstablishment()
        if let pid = normalizedPlaceId(pending.placeId) {
            candidates.append(PlaceCandidate(placeId: pid, label: normalizedText(pending.description) ?? defaultLabel, priority: 4))
        }
        return (candidates, writeReviewURL)
    }

    /// Sources locales uniquement — ouverture immédiate sans réseau.
    static func instantMapsReviewsURL(
        for slug: String,
        context: CommerceStatsGoogleMapsContext = .init()
    ) -> URL? {
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSlug.isEmpty else { return nil }

        if let cached = CommerceStatsGoogleMapsURLCache.read(for: trimmedSlug) {
            return cached
        }

        let settingsPid = cachedPlaceId(for: trimmedSlug)
        let (candidates, _) = collectPlaceCandidates(
            slug: trimmedSlug,
            context: context,
            publicInfo: nil,
            settingsPlaceId: settingsPid,
            matchedPlaceId: nil
        )

        var seen = Set<String>()
        for candidate in candidates.sorted(by: { $0.priority < $1.priority }) {
            guard seen.insert(candidate.placeId).inserted else { continue }
            if let url = instantURLForCandidate(candidate) { return url }
        }

        let linked = MerchantLinkedPlaceCache.read()
        let searchCandidates: [String?] = [
            normalizedText(linked.description),
            context.organizationName,
            context.businessName,
            context.locationAddress,
        ]
        for candidate in searchCandidates {
            if let q = normalizedText(candidate), let url = mapsSearchURL(query: q) {
                return url
            }
        }
        return nil
    }

    /// Précharge l’URL optimale (API) en arrière-plan pour les prochains taps.
    static func prefetchMapsReviewsURL(
        for slug: String,
        context: CommerceStatsGoogleMapsContext = .init()
    ) {
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSlug.isEmpty else { return }
        Task {
            if let url = await resolveMapsTarget(for: trimmedSlug, context: context) {
                CommerceStatsGoogleMapsURLCache.store(url, for: trimmedSlug)
            }
        }
    }

    private static func fetchPublicBusinessInfo(slug: String) async -> PublicBusinessInfo? {
        try? await APIClient.shared.request(.businessPublicInfo(slug: slug)) as PublicBusinessInfo
    }

    private static func fetchMatchedPlaceId(slug: String) async -> String? {
        guard let status = try? await GoogleBusinessAPI.shared.status(slug: slug) else { return nil }
        return normalizedPlaceId(status.matchedPlaceId)
    }

    private static func fetchSettingsPlaceId(slug: String) async -> String? {
        if let cached = cachedPlaceId(for: slug) { return cached }
        guard let data = try? await APIClient.shared.requestData(.businessSettings(slug: slug)) else { return nil }
        if let fromJSON = placeIdFromSettingsData(data) { return fromJSON }
        if let settings = try? JSONDecoder.apiClient.decode(BusinessSettingsResponse.self, from: data) {
            ScanFlowSettingsCache.store(settings, for: slug)
            return placeId(from: settings)
        }
        return nil
    }

    private static func resolveMapsTarget(
        for slug: String,
        context: CommerceStatsGoogleMapsContext
    ) async -> URL? {
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSlug.isEmpty else { return nil }

        async let publicInfoTask = fetchPublicBusinessInfo(slug: trimmedSlug)
        async let settingsPidTask = fetchSettingsPlaceId(slug: trimmedSlug)
        async let matchedPlaceIdTask = fetchMatchedPlaceId(slug: trimmedSlug)

        let publicInfo = await publicInfoTask
        let settingsPid = await settingsPidTask
        let matchedPlaceId = await matchedPlaceIdTask
        let (candidates, writeReviewURL) = collectPlaceCandidates(
            slug: trimmedSlug,
            context: context,
            publicInfo: publicInfo,
            settingsPlaceId: settingsPid,
            matchedPlaceId: matchedPlaceId
        )

        var seen = Set<String>()
        var bestCandidate: PlaceCandidate?
        for candidate in candidates.sorted(by: { $0.priority < $1.priority }) {
            guard seen.insert(candidate.placeId).inserted else { continue }
            bestCandidate = candidate
            break
        }

        if let bestCandidate {
            if let details = await resolvePlaceDetails(placeId: bestCandidate.placeId, fallback: bestCandidate.label),
               let url = mapsReviewsURL(
                   placeId: bestCandidate.placeId,
                   query: details.label,
                   reviewsUri: details.reviewsUri
               ) {
                return url
            }
            if let url = instantURLForCandidate(bestCandidate) { return url }
        }

        let linked = MerchantLinkedPlaceCache.read()
        let searchCandidates: [String?] = [
            normalizedText(linked.description),
            context.organizationName,
            context.businessName,
            context.locationAddress,
            publicInfo?.organizationName,
            publicInfo?.name,
        ]
        for candidate in searchCandidates {
            if let q = normalizedText(candidate), let url = mapsSearchURL(query: q) {
                return url
            }
        }

        if let raw = writeReviewURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }

        return nil
    }

    @MainActor
    private static func openURLNow(_ url: URL) -> Bool {
        guard UIApplication.shared.canOpenURL(url) else { return false }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
    }

    @MainActor
    static func openMapsReviews(
        for slug: String,
        context: CommerceStatsGoogleMapsContext = .init()
    ) -> CommerceStatsGoogleMapsOpenResult {
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSlug.isEmpty else { return .missingPlace }

        if let url = instantMapsReviewsURL(for: trimmedSlug, context: context) {
            CommerceStatsGoogleMapsURLCache.store(url, for: trimmedSlug)
            prefetchMapsReviewsURL(for: trimmedSlug, context: context)
            return openURLNow(url) ? .opened : .systemOpenFailed
        }

        return .missingPlace
    }

    /// Réseau uniquement si aucune source locale — évite le délai quand le cache est vide au premier tap.
    @MainActor
    static func openMapsReviewsResolvingIfNeeded(
        for slug: String,
        context: CommerceStatsGoogleMapsContext = .init()
    ) async -> CommerceStatsGoogleMapsOpenResult {
        if let instant = instantMapsReviewsURL(for: slug, context: context) {
            CommerceStatsGoogleMapsURLCache.store(instant, for: slug)
            prefetchMapsReviewsURL(for: slug, context: context)
            return openURLNow(instant) ? .opened : .systemOpenFailed
        }
        guard let url = await resolveMapsTarget(for: slug, context: context) else {
            return .missingPlace
        }
        CommerceStatsGoogleMapsURLCache.store(url, for: slug)
        return openURLNow(url) ? .opened : .systemOpenFailed
    }
}

private extension JSONDecoder {
    static var apiClient: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }
}
