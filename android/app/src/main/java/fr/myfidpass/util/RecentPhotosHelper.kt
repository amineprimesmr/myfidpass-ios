package fr.myfidpass.util

import android.content.ContentUris
import android.content.Context
import android.net.Uri
import android.provider.MediaStore

/** Photos récentes pour carrousel logo — aligné iOS `LogoRecentPhotosCarousel`. */
object RecentPhotosHelper {

    fun recentImageUris(context: Context, limit: Int = 12): List<Uri> {
        val collection = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(MediaStore.Images.Media._ID)
        val sort = "${MediaStore.Images.Media.DATE_ADDED} DESC"
        val result = mutableListOf<Uri>()
        context.contentResolver.query(collection, projection, null, null, sort)?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
            while (cursor.moveToNext() && result.size < limit) {
                val id = cursor.getLong(idCol)
                result += ContentUris.withAppendedId(collection, id)
            }
        }
        return result
    }
}
