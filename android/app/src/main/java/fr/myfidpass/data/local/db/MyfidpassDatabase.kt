package fr.myfidpass.data.local.db

import androidx.room.Database
import androidx.room.RoomDatabase
import fr.myfidpass.data.local.db.dao.MemberDao
import fr.myfidpass.data.local.db.dao.SyncMetaDao
import fr.myfidpass.data.local.db.dao.TransactionDao
import fr.myfidpass.data.local.db.entities.MemberEntity
import fr.myfidpass.data.local.db.entities.SyncMetaEntity
import fr.myfidpass.data.local.db.entities.TransactionEntity

@Database(
    entities = [MemberEntity::class, TransactionEntity::class, SyncMetaEntity::class],
    version = 1,
    exportSchema = false,
)
abstract class MyfidpassDatabase : RoomDatabase() {
    abstract fun memberDao(): MemberDao
    abstract fun transactionDao(): TransactionDao
    abstract fun syncMetaDao(): SyncMetaDao
}
