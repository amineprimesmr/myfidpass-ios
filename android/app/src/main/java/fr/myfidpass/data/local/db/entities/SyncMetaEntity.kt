package fr.myfidpass.data.local.db.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "sync_meta")
data class SyncMetaEntity(
    @PrimaryKey val businessSlug: String,
    val lastSyncAt: Long,
    val membersTotal: Int?,
    val transactionsTotal: Int?,
)
