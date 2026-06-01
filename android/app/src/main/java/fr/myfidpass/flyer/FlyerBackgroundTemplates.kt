package fr.myfidpass.flyer

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.annotation.DrawableRes
import fr.myfidpass.R

object FlyerBackgroundTemplates {

    data class Template(val key: String, @DrawableRes val drawableId: Int)

    private val catalog: List<Template> = listOf(
        Template("template1", R.drawable.flyer_template_1),
        Template("template2", R.drawable.flyer_template_2),
        Template("template3", R.drawable.flyer_template_3),
        Template("template4", R.drawable.flyer_template_4),
        Template("template5", R.drawable.flyer_template_5),
        Template("template6", R.drawable.flyer_template_6),
        Template("template7", R.drawable.flyer_template_7),
        Template("template8", R.drawable.flyer_template_8),
        Template("template9", R.drawable.flyer_template_9),
        Template("template10", R.drawable.flyer_template_10),
        Template("template11", R.drawable.flyer_template_11),
    )

    fun keys(): List<String> = catalog.map { it.key }

    fun drawableIdForKey(key: String): Int? = catalog.firstOrNull { it.key == key }?.drawableId

    fun randomKey(): String? = catalog.randomOrNull()?.key

    fun loadBitmap(context: Context, key: String): Bitmap? {
        val id = drawableIdForKey(key) ?: return null
        return BitmapFactory.decodeResource(context.resources, id)
    }

    fun applyRandomTemplate(context: Context): Pair<String, String>? {
        val key = randomKey() ?: return null
        val bmp = loadBitmap(context, key) ?: return null
        return key to bitmapToPngDataUrl(bmp)
    }
}
