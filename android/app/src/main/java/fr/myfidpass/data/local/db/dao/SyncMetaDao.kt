package fr.myfidpass.data.local.db.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import fr.myfidpass.data.local.db.entities.SyncMetaEntity

@Dao
interface SyncMetaDao {
    @Query("SELECT * FROM sync_meta WHERE businessSlug = :slug LIMIT 1")
    suspend fun get(slug: String): SyncMetaEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(meta: SyncMetaEntity)
}
