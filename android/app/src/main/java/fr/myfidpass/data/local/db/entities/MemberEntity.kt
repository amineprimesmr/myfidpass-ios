package fr.myfidpass.data.local.db.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "members")
data class MemberEntity(
    @PrimaryKey val id: String,
    val businessSlug: String,
    val name: String?,
    val email: String?,
    val points: Int?,
    val syncedAt: Long,
)
