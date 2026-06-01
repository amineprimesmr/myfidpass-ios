package fr.myfidpass.ui.mycard

import fr.myfidpass.data.local.db.dao.MemberDao
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.data.repo.mapWalletPreviewError
import kotlinx.coroutines.flow.first

/**
 * Prépare un membre d’aperçu Wallet (aligné iOS `ensurePreviewMemberIdForWallet`) puis
 * retourne l’URL « Save to Google Wallet » pour tester la carte sur l’appareil Android.
 */
suspend fun resolveGoogleWalletPreviewUrl(
    repository: DashboardRepository,
    memberDao: MemberDao,
    slug: String,
): String {
    val memberId = firstLocalMemberId(memberDao, slug)
        ?: repository.ensurePreviewMemberIdForWallet(slug)
    return repository.googleWalletMemberUrl(slug, memberId).url
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
        ?: throw IllegalStateException("Lien Google Wallet indisponible")
}

suspend fun firstLocalMemberId(memberDao: MemberDao, slug: String): String? =
    runCatching {
        memberDao.observeBySlug(slug, limit = 1).first().firstOrNull()?.id?.trim()
    }.getOrNull()?.takeIf { it.isNotEmpty() }

suspend fun runGoogleWalletPreview(
    repository: DashboardRepository,
    memberDao: MemberDao,
    slug: String,
    onSuccess: (url: String) -> Unit,
    onFailure: (message: String) -> Unit,
) {
    runCatching {
        resolveGoogleWalletPreviewUrl(repository, memberDao, slug)
    }.fold(
        onSuccess = onSuccess,
        onFailure = { onFailure(mapWalletPreviewError(it)) },
    )
}
