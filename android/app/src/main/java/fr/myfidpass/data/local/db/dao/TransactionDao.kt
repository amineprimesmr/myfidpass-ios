package fr.myfidpass.data.local.db.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import fr.myfidpass.data.local.db.entities.TransactionEntity
import kotlinx.coroutines.flow.Flow

@Dao
interface TransactionDao {
    @Query("SELECT * FROM transactions WHERE businessSlug = :slug ORDER BY createdAt DESC LIMIT :limit")
    fun observeRecent(slug: String, limit: Int = 30): Flow<List<TransactionEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(items: List<TransactionEntity>)

    @Query("DELETE FROM transactions WHERE businessSlug = :slug")
    suspend fun deleteForSlug(slug: String)
}
