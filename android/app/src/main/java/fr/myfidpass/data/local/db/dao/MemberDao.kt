package fr.myfidpass.data.local.db.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import fr.myfidpass.data.local.db.entities.MemberEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface MemberDao {
    @Query("SELECT * FROM members WHERE businessSlug = :slug ORDER BY name COLLATE NOCASE ASC LIMIT :limit")
    fun observeBySlug(slug: String, limit: Int = 200): Flow<List<MemberEntity>>

    @Query("SELECT * FROM members WHERE businessSlug = :slug AND (name LIKE '%' || :q || '%' OR email LIKE '%' || :q || '%') ORDER BY name COLLATE NOCASE ASC LIMIT :limit")
    suspend fun search(slug: String, q: String, limit: Int = 200): List<MemberEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(items: List<MemberEntity>)

    @Query("DELETE FROM members WHERE businessSlug = :slug")
    suspend fun deleteForSlug(slug: String)

    @Query("SELECT COUNT(*) FROM members WHERE businessSlug = :slug")
    suspend fun countForSlug(slug: String): Int
}
