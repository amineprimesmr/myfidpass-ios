package fr.myfidpass.util

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File

fun shareFiles(context: Context, files: List<File>, mimeType: String = "*/*") {
    if (files.isEmpty()) return
    val uris = files.map { file ->
        FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    }
    val intent = if (uris.size == 1) {
        Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uris.first())
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    } else {
        Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = mimeType
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }
    context.startActivity(Intent.createChooser(intent, "Partager"))
}

fun writeTempExport(context: Context, subdir: String, filename: String, bytes: ByteArray): File {
    val dir = File(context.cacheDir, subdir).apply { mkdirs() }
    val file = File(dir, filename)
    file.writeBytes(bytes)
    return file
}
