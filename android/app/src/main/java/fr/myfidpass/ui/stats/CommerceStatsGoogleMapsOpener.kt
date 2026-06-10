package fr.myfidpass.ui.stats

import android.content.Context
import android.content.Intent
import android.net.Uri
import fr.myfidpass.data.local.FirstLaunchPreferences
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

private data class PlaceCandidate(
    val placeId: String,
    val label: String?,
    val priority: Int,
)

private data class ResolvedPlaceDetails(
    val label: String?,
    val reviewsUri: String?,
)

object CommerceStatsGoogleMapsOpener {

    private const val PREFS = "myfidpass_stats_google_maps"
    private fun cacheKey(slug: String) =
        "google_maps_reviews_uri.${slug.trim().lowercase()}"

    private fun readCachedUri(context: Context, slug: String): Uri? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(cacheKey(slug), null)
            ?.trim()
            .orEmpty()
        if (raw.isEmpty()) return null
        return runCatching { Uri.parse(raw) }.getOrNull()
    }

    private fun storeCachedUri(context: Context, slug: String, uri: Uri) {
        val businessSlug = slug.trim()
        if (businessSlug.isEmpty()) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(cacheKey(businessSlug), uri.toString())
            .apply()
    }

    /**
     * Lecture avis Google — priorité à l’URI officielle API, sinon `search.google.com/local/reviews`
     * (ne pas fabriquer `data=!…!1sChIJ…` : Maps affiche « invalid coord »).
     */
    fun mapsReviewsUri(
        placeId: String,
        query: String? = null,
        reviewsUri: String? = null,
    ): Uri {
        reviewsUri?.trim()?.takeIf { it.isNotEmpty() }?.let { raw ->
            runCatching { Uri.parse(raw) }.getOrNull()?.let { return it }
        }
        val trimmed = placeId.trim()
        val builder = Uri.parse("https://search.google.com/local/reviews").buildUpon()
            .appendQueryParameter("placeid", trimmed)
            .appendQueryParameter("hl", "fr")
        query?.trim()?.takeIf { it.isNotEmpty() }?.let { builder.appendQueryParameter("q", it) }
        return builder.build()
    }

    /** Format Google Maps documenté — ouvre la fiche lieu (aperçu). */
    fun mapsPlaceUri(placeId: String, query: String? = null): Uri {
        val builder = Uri.parse("https://www.google.com/maps/search/").buildUpon()
            .appendQueryParameter("api", "1")
            .appendQueryParameter("query_place_id", placeId.trim())
        query?.trim()?.takeIf { it.isNotEmpty() }?.let { builder.appendQueryParameter("query", it) }
        return builder.build()
    }

    fun mapsSearchUri(query: String): Uri =
        Uri.parse("https://www.google.com/maps/search/").buildUpon()
            .appendQueryParameter("api", "1")
            .appendQueryParameter("query", query.trim())
            .build()

    fun placeIdFromGoogleReviewWriteUrl(url: String?): String? {
        val raw = url?.trim().orEmpty()
        if (raw.isEmpty()) return null
        val uri = runCatching { Uri.parse(raw) }.getOrNull() ?: return null
        return uri.getQueryParameter("placeid")?.trim()?.takeIf { it.isNotEmpty() }
            ?: uri.getQueryParameter("place_id")?.trim()?.takeIf { it.isNotEmpty() }
    }

    private suspend fun resolvePlaceDetails(
        repository: DashboardRepository,
        placeId: String,
        fallback: String?,
    ): ResolvedPlaceDetails? {
        val details = runCatching { repository.placesPlaceDetails(placeId) }.getOrNull()
            ?: return ResolvedPlaceDetails(label = fallback, reviewsUri = null)
        val name = details.name?.trim().orEmpty()
        val addr = details.formattedAddress?.trim().orEmpty()
        val label = when {
            name.isNotEmpty() && addr.isNotEmpty() -> "$name, $addr"
            name.isNotEmpty() -> name
            addr.isNotEmpty() -> addr
            else -> fallback
        }
        return ResolvedPlaceDetails(
            label = label,
            reviewsUri = details.googleMapsReviewsUri?.trim()?.takeIf { it.isNotEmpty() },
        )
    }

    private fun instantUriForCandidate(candidate: PlaceCandidate): Uri =
        mapsReviewsUri(placeId = candidate.placeId, query = candidate.label)

    private fun collectCandidates(
        settingsPlaceId: String?,
        matchedPlaceId: String?,
        publicWriteUrl: String?,
        pendingPlaceId: String?,
        pendingDescription: String?,
        defaultLabel: String?,
    ): List<PlaceCandidate> {
        val candidates = mutableListOf<PlaceCandidate>()
        settingsPlaceId?.trim()?.takeIf { it.isNotEmpty() }?.let { pid ->
            candidates += PlaceCandidate(pid, defaultLabel, priority = 0)
        }
        matchedPlaceId?.trim()?.takeIf { it.isNotEmpty() }?.let { pid ->
            candidates += PlaceCandidate(pid, defaultLabel, priority = 1)
        }
        publicWriteUrl?.let { writeUrl ->
            placeIdFromGoogleReviewWriteUrl(writeUrl)?.let { pid ->
                candidates += PlaceCandidate(pid, defaultLabel, priority = 2)
            }
        }
        pendingPlaceId?.trim()?.takeIf { it.isNotEmpty() }?.let { pid ->
            val label = pendingDescription?.trim()?.takeIf { it.isNotEmpty() } ?: defaultLabel
            candidates += PlaceCandidate(pid, label, priority = 3)
        }
        return candidates
    }

    /** Sources locales — ouverture immédiate sans réseau. */
    fun resolveInstantUri(
        context: Context,
        slug: String,
        firstLaunch: FirstLaunchPreferences,
        organizationName: String? = null,
        locationAddress: String? = null,
        cachedSettingsPlaceId: String? = null,
    ): Uri? {
        val businessSlug = slug.trim()
        if (businessSlug.isEmpty()) return null
        readCachedUri(context, businessSlug)?.let { return it }

        val pending = firstLaunch.readPendingEstablishment()
        val defaultLabel = listOfNotNull(
            organizationName?.trim()?.takeIf { it.isNotEmpty() },
            locationAddress?.trim()?.takeIf { it.isNotEmpty() },
            pending.description?.trim()?.takeIf { it.isNotEmpty() },
        ).firstOrNull()

        val candidates = collectCandidates(
            settingsPlaceId = cachedSettingsPlaceId,
            matchedPlaceId = null,
            publicWriteUrl = null,
            pendingPlaceId = pending.placeId,
            pendingDescription = pending.description,
            defaultLabel = defaultLabel,
        )

        val seen = mutableSetOf<String>()
        for (candidate in candidates.sortedBy { it.priority }) {
            if (!seen.add(candidate.placeId)) continue
            return instantUriForCandidate(candidate)
        }

        val searchCandidates = listOfNotNull(
            pending.description?.trim()?.takeIf { it.isNotEmpty() },
            organizationName?.trim()?.takeIf { it.isNotEmpty() },
            locationAddress?.trim()?.takeIf { it.isNotEmpty() },
        )
        for (query in searchCandidates) {
            return mapsSearchUri(query)
        }
        return null
    }

    suspend fun resolveOpenUri(
        repository: DashboardRepository,
        slug: String,
        firstLaunch: FirstLaunchPreferences,
        organizationName: String? = null,
        locationAddress: String? = null,
        context: Context? = null,
    ): Uri? = coroutineScope {
        val businessSlug = slug.trim()
        if (businessSlug.isEmpty()) return@coroutineScope null

        context?.let { readCachedUri(it, businessSlug) }?.let { return@coroutineScope it }

        val pending = firstLaunch.readPendingEstablishment()
        val settingsDeferred = async { runCatching { repository.businessSettings(businessSlug) }.getOrNull() }
        val publicInfoDeferred = async { runCatching { repository.publicBusinessInfo(businessSlug) }.getOrNull() }
        val matchedDeferred = async {
            runCatching { repository.googleBusinessStatus(businessSlug).matchedPlaceId?.trim() }
                .getOrNull()
                ?.takeIf { it.isNotEmpty() }
        }

        val settings = settingsDeferred.await()
        val publicInfo = publicInfoDeferred.await()
        val matchedPlaceId = matchedDeferred.await()

        val defaultLabel = listOfNotNull(
            organizationName?.trim()?.takeIf { it.isNotEmpty() },
            settings?.organizationName?.trim()?.takeIf { it.isNotEmpty() },
            locationAddress?.trim()?.takeIf { it.isNotEmpty() },
            publicInfo?.organizationName?.trim()?.takeIf { it.isNotEmpty() },
            publicInfo?.name?.trim()?.takeIf { it.isNotEmpty() },
        ).firstOrNull()

        val candidates = collectCandidates(
            settingsPlaceId = settings?.engagementRewards?.googleReview?.placeId,
            matchedPlaceId = matchedPlaceId,
            publicWriteUrl = publicInfo?.googleReviewWriteUrl,
            pendingPlaceId = pending.placeId,
            pendingDescription = pending.description,
            defaultLabel = defaultLabel,
        )

        val seen = mutableSetOf<String>()
        var best: PlaceCandidate? = null
        for (candidate in candidates.sortedBy { it.priority }) {
            if (!seen.add(candidate.placeId)) continue
            best = candidate
            break
        }

        best?.let { candidate ->
            val details = resolvePlaceDetails(repository, candidate.placeId, candidate.label)
            val uri = mapsReviewsUri(
                placeId = candidate.placeId,
                query = details?.label,
                reviewsUri = details?.reviewsUri,
            )
            context?.let { storeCachedUri(it, businessSlug, uri) }
            return@coroutineScope uri
        }

        val searchCandidates = listOfNotNull(
            pending.description?.trim()?.takeIf { it.isNotEmpty() },
            organizationName?.trim()?.takeIf { it.isNotEmpty() },
            settings?.organizationName?.trim()?.takeIf { it.isNotEmpty() },
            publicInfo?.organizationName?.trim()?.takeIf { it.isNotEmpty() },
            publicInfo?.name?.trim()?.takeIf { it.isNotEmpty() },
            locationAddress?.trim()?.takeIf { it.isNotEmpty() },
        )
        for (query in searchCandidates) {
            val uri = mapsSearchUri(query)
            context?.let { storeCachedUri(it, businessSlug, uri) }
            return@coroutineScope uri
        }

        publicInfo?.googleReviewWriteUrl?.trim()?.takeIf { it.isNotEmpty() }?.let { writeUrl ->
            val uri = Uri.parse(writeUrl)
            context?.let { storeCachedUri(it, businessSlug, uri) }
            return@coroutineScope uri
        }

        null
    }

    suspend fun prefetchOpenUri(
        repository: DashboardRepository,
        slug: String,
        firstLaunch: FirstLaunchPreferences,
        organizationName: String? = null,
        locationAddress: String? = null,
        context: Context,
    ) {
        resolveOpenUri(
            repository = repository,
            slug = slug,
            firstLaunch = firstLaunch,
            organizationName = organizationName,
            locationAddress = locationAddress,
            context = context,
        )
    }

    fun openUri(context: Context, uri: Uri?): Boolean {
        if (uri == null) return false
        return runCatching {
            context.startActivity(Intent(Intent.ACTION_VIEW, uri))
            true
        }.getOrDefault(false)
    }
}
