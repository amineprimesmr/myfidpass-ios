package fr.myfidpass.data.local.db.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "transactions")
data class TransactionEntity(
    @PrimaryKey val id: String,
    val businessSlug: String,
    val memberId: String?,
    val memberName: String?,
    val memberEmail: String?,
    val type: String?,
    val points: Int?,
    val detail: String?,
    val createdAt: String?,
    val syncedAt: Long,
)
