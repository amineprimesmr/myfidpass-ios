package fr.myfidpass.services.sync

import android.content.Context
import androidx.room.Room
import fr.myfidpass.data.dto.MemberDto
import fr.myfidpass.data.dto.TransactionDto
import fr.myfidpass.data.local.db.MyfidpassDatabase
import fr.myfidpass.data.local.db.entities.MemberEntity
import fr.myfidpass.util.MerchantTechnicalMember
import fr.myfidpass.data.local.db.entities.SyncMetaEntity
import fr.myfidpass.data.local.db.entities.TransactionEntity
import fr.myfidpass.data.repo.DashboardRepository
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.atomic.AtomicLong

/** Sync paginée members + transactions — aligné iOS `SyncService`. */
class SyncService(
    context: Context,
    private val repository: DashboardRepository,
) {
    private val appContext = context.applicationContext
    private val db = Room.databaseBuilder(
        appContext,
        MyfidpassDatabase::class.java,
        "myfidpass.db",
    ).fallbackToDestructiveMigration().build()

    private val mutex = Mutex()
    private val lastSyncBySlug = AtomicLong(0)
    private val throttleMs = 45_000L

    /** Dernière synchro réussie (ms) — affichage Réglages. */
    var lastSyncAtMillis: Long? = null
        private set

    var lastSyncError: String? = null
        private set

    var isSyncing: Boolean = false
        private set

    /** Slug pour lequel l’hydratation flyer a été tentée durant la session courante. */
    var flyerHydrationCompletedForSlug: String? = null
        private set

    val memberDao get() = db.memberDao()
    val transactionDao get() = db.transactionDao()
    val syncMetaDao get() = db.syncMetaDao()

    suspend fun getSyncMeta(slug: String) = db.syncMetaDao().get(slug)

    suspend fun syncIfNeeded(slug: String, force: Boolean = false) {
        if (slug.isBlank()) return
        val now = System.currentTimeMillis()
        if (!force && now - lastSyncBySlug.get() < throttleMs) return
        mutex.withLock {
            if (!force && now - lastSyncBySlug.get() < throttleMs) return
            isSyncing = true
            runCatching { pull(slug) }
                .onSuccess {
                    lastSyncAtMillis = System.currentTimeMillis()
                    lastSyncError = null
                }
                .onFailure { lastSyncError = it.message ?: "Erreur de synchro" }
            isSyncing = false
            lastSyncBySlug.set(System.currentTimeMillis())
        }
    }

    suspend fun invalidateThrottle() {
        lastSyncBySlug.set(0)
    }

    fun resetFlyerHydrationState() {
        flyerHydrationCompletedForSlug = null
    }

    fun hasCompletedFlyerHydration(slug: String): Boolean {
        val key = slug.trim()
        if (key.isEmpty()) return false
        return flyerHydrationCompletedForSlug?.trim()?.equals(key, ignoreCase = true) == true
    }

    suspend fun clearForSlug(slug: String) {
        db.memberDao().deleteForSlug(slug)
        db.transactionDao().deleteForSlug(slug)
    }

    private suspend fun pull(slug: String) {
        val ts = System.currentTimeMillis()
        try {
            val members = mutableListOf<MemberEntity>()
            var memberOffset = 0
            val memberPageSize = 200
            while (memberOffset < 20_000) {
                val page = repository.businessMembers(slug, limit = memberPageSize, offset = memberOffset)
                members += page.members
                    .filter { !MerchantTechnicalMember.shouldExcludeFromMerchantActivity(it.email) }
                    .mapNotNull { it.toEntity(slug, ts) }
                if (page.members.size < memberPageSize) break
                memberOffset += memberPageSize
            }
            db.memberDao().deleteForSlug(slug)
            if (members.isNotEmpty()) {
                members.chunked(500).forEach { db.memberDao().upsertAll(it) }
            }

            val txs = mutableListOf<TransactionEntity>()
            var txOffset = 0
            val txPageSize = 100
            while (txOffset < 50_000) {
                val page = repository.businessTransactions(slug, limit = txPageSize, offset = txOffset, sort = "desc")
                txs += page.transactions.mapNotNull { it.toEntity(slug, ts) }
                if (page.transactions.size < txPageSize) break
                txOffset += txPageSize
            }
            if (txs.isNotEmpty()) {
                txs.chunked(500).forEach { db.transactionDao().upsertAll(it) }
            }

            db.syncMetaDao().upsert(
                SyncMetaEntity(
                    businessSlug = slug,
                    lastSyncAt = ts,
                    membersTotal = members.size,
                    transactionsTotal = txs.size,
                ),
            )
        } finally {
            val settings = runCatching { repository.businessSettings(slug) }.getOrNull()
            FlyerSyncHydrator.hydrate(appContext, repository, slug, settings)
            flyerHydrationCompletedForSlug = slug.trim()
        }
    }

    private fun MemberDto.toEntity(slug: String, ts: Long): MemberEntity? {
        val id = id?.trim().orEmpty()
        if (id.isEmpty()) return null
        return MemberEntity(
            id = id,
            businessSlug = slug,
            name = name,
            email = email,
            points = points,
            syncedAt = ts,
        )
    }

    private fun TransactionDto.toEntity(slug: String, ts: Long): TransactionEntity? {
        val id = id?.trim().orEmpty()
        if (id.isEmpty()) return null
        return TransactionEntity(
            id = id,
            businessSlug = slug,
            memberId = memberId,
            memberName = memberName,
            memberEmail = memberEmail,
            type = type,
            points = points,
            detail = metadata,
            createdAt = createdAt,
            syncedAt = ts,
        )
    }
}
