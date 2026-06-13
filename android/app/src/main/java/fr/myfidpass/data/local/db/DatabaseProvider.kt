package fr.myfidpass.data.local.db

import android.content.Context
import androidx.room.Room

object DatabaseProvider {
    private const val DB_NAME = "myfidpass.db"

    @Volatile
    private var instance: MyfidpassDatabase? = null

    fun get(context: Context): MyfidpassDatabase {
        return instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(
                context.applicationContext,
                MyfidpassDatabase::class.java,
                DB_NAME,
            ).build().also { instance = it }
        }
    }
}
