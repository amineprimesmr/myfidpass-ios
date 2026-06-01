package fr.myfidpass.ui.components

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.net.Uri
import android.util.Base64
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.exifinterface.media.ExifInterface
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.min

/** Recadrage aligné iOS `ImageCropEditorView` + `ImageCropScrollView`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImageCropDialog(
    uri: Uri,
    spec: ImageCropSpec,
    visible: Boolean,
    onDismiss: () -> Unit,
    onCropped: (String) -> Unit,
) {
    if (!visible) return
    val context = LocalContext.current
    val bitmap = remember(uri) { loadOrientedBitmap(context, uri) }
    LaunchedEffect(uri, bitmap) {
        if (bitmap == null) onDismiss()
    }
    if (bitmap == null) return

    var userScale by remember(uri, spec) { mutableFloatStateOf(1f) }
    var offsetX by remember(uri, spec) { mutableFloatStateOf(0f) }
    var offsetY by remember(uri, spec) { mutableFloatStateOf(0f) }
    var viewSize by remember { mutableStateOf(IntSize.Zero) }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(spec.title, fontWeight = FontWeight.SemiBold) },
                    navigationIcon = {
                        IconButton(onClick = onDismiss) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Annuler")
                        }
                    },
                    actions = {
                        TextButton(
                            onClick = {
                                val cropRect = computeCropFrame(
                                    viewSize.width.toFloat(),
                                    viewSize.height.toFloat(),
                                    spec.aspectWidthOverHeight,
                                )
                                val cropped = exportCroppedBitmap(
                                    source = bitmap,
                                    cropRect = cropRect,
                                    viewSize = viewSize,
                                    aspectRatio = spec.aspectWidthOverHeight,
                                    userScale = userScale,
                                    offsetX = offsetX,
                                    offsetY = offsetY,
                                ) ?: centeredAspectFillCrop(bitmap, spec.aspectWidthOverHeight)
                                val resized = resizeToCanvas(
                                    cropped,
                                    spec.exportWidth,
                                    spec.exportHeight,
                                )
                                onCropped(bitmapToDataUrl(resized))
                                if (resized !== cropped && resized !== bitmap) resized.recycle()
                                if (cropped !== bitmap) cropped.recycle()
                                onDismiss()
                            },
                        ) {
                            Text("Définir", fontWeight = FontWeight.SemiBold)
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Color(0xFFF2F2F7),
                        titleContentColor = Color.Black,
                    ),
                )
            },
            containerColor = Color(0xFFF2F2F7),
        ) { padding ->
            Column(
                Modifier
                    .fillMaxSize()
                    .padding(padding),
            ) {
                if (spec.hint.isNotBlank()) {
                    Text(
                        spec.hint,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                        color = Color.Black.copy(alpha = 0.88f),
                    )
                }
                Box(
                    Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .background(Color(0xFFF2F2F7))
                        .onSizeChanged { viewSize = it },
                ) {
                    val imageBitmap = remember(bitmap) { bitmap.asImageBitmap() }
                    val cropRect = computeCropFrame(
                        viewSize.width.toFloat(),
                        viewSize.height.toFloat(),
                        spec.aspectWidthOverHeight,
                    )
                    val fillScale = remember(cropRect, bitmap) {
                        if (cropRect.width <= 0f || cropRect.height <= 0f) 1f
                        else max(
                            cropRect.width / bitmap.width.toFloat(),
                            cropRect.height / bitmap.height.toFloat(),
                        )
                    }
                    val drawScale = fillScale * userScale
                    // Alignement haut-gauche du cadre (comme iOS `layoutScrollViewContents`).
                    val imgLeft = cropRect.left + offsetX
                    val imgTop = cropRect.top + offsetY

                    Box(
                        Modifier
                            .fillMaxSize()
                            .pointerInput(uri, spec, viewSize, userScale, offsetX, offsetY) {
                                detectTransformGestures { _, pan, zoom, _ ->
                                    val frame = computeCropFrame(
                                        viewSize.width.toFloat(),
                                        viewSize.height.toFloat(),
                                        spec.aspectWidthOverHeight,
                                    )
                                    if (frame.width <= 0f || frame.height <= 0f) return@detectTransformGestures
                                    val baseScale = max(
                                        frame.width / bitmap.width.toFloat(),
                                        frame.height / bitmap.height.toFloat(),
                                    )
                                    userScale = (userScale * zoom).coerceIn(0.35f, 6f)
                                    val scale = baseScale * userScale
                                    val w = bitmap.width * scale
                                    val h = bitmap.height * scale
                                    offsetX = clampPanOffset(offsetX + pan.x, w, frame.width)
                                    offsetY = clampPanOffset(offsetY + pan.y, h, frame.height)
                                }
                            },
                    ) {
                        Canvas(Modifier.fillMaxSize()) {
                            if (cropRect.width <= 0f || cropRect.height <= 0f) return@Canvas

                            withTransform({
                                translate(imgLeft, imgTop)
                                scale(drawScale, drawScale, pivot = Offset.Zero)
                            }) {
                                drawImage(imageBitmap, topLeft = Offset.Zero)
                            }

                            val dimPath = Path().apply {
                                fillType = PathFillType.EvenOdd
                                addRect(Rect(0f, 0f, size.width, size.height))
                                addRoundRect(
                                    RoundRect(
                                        cropRect,
                                        CornerRadius(10f, 10f),
                                    ),
                                )
                            }
                            drawPath(dimPath, Color.Black.copy(alpha = 0.34f))
                            drawRoundRect(
                                color = Color.White.copy(alpha = 0.92f),
                                topLeft = cropRect.topLeft,
                                size = cropRect.size,
                                cornerRadius = CornerRadius(10f, 10f),
                                style = Stroke(width = 2f),
                            )
                        }
                    }
                }
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

/** Limite le pan pour que le cadre reste couvert par l'image (équivalent iOS `clampScrollOffset`). */
internal fun clampPanOffset(offset: Float, drawSize: Float, cropSize: Float): Float {
    val min = cropSize - drawSize
    val max = 0f
    return if (min <= max) offset.coerceIn(min, max) else 0f
}

/** Fenêtre de cadrage centrée — même logique que iOS `computeScrollFrame`. */
internal fun computeCropFrame(viewW: Float, viewH: Float, aspectRatio: Float): Rect {
    if (viewW <= 8f || viewH <= 8f || aspectRatio <= 0.01f) return Rect.Zero
    return if (aspectRatio > 1.15f) {
        val cropW = viewW * 0.94f
        val cropH = cropW / aspectRatio
        val x = (viewW - cropW) * 0.5f
        val y = max(0f, (viewH - cropH) * 0.5f)
        Rect(x, y, x + cropW, y + cropH)
    } else {
        val widthFactor = if (aspectRatio < 0.9f) 0.92f else 0.82f
        val cropW = viewW * widthFactor
        val cropH = cropW / aspectRatio
        val x = (viewW - cropW) * 0.5f
        val y = max(0f, (viewH - cropH) * 0.5f)
        Rect(x, y, x + cropW, y + cropH)
    }
}

internal fun exportCroppedBitmap(
    source: Bitmap,
    cropRect: Rect,
    viewSize: IntSize,
    aspectRatio: Float,
    userScale: Float,
    offsetX: Float,
    offsetY: Float,
): Bitmap? {
    if (viewSize.width <= 0 || viewSize.height <= 0 || cropRect.width <= 0f) return null
    val frame = if (cropRect.width > 0f) cropRect else computeCropFrame(
        viewSize.width.toFloat(),
        viewSize.height.toFloat(),
        aspectRatio,
    )
    val fillScale = max(frame.width / source.width.toFloat(), frame.height / source.height.toFloat())
    val drawScale = fillScale * userScale
    val drawW = source.width * drawScale
    val drawH = source.height * drawScale
    val imgLeft = frame.left + offsetX
    val imgTop = frame.top + offsetY

    fun viewToBitmap(vx: Float, vy: Float): Pair<Float, Float> {
        val bx = (vx - imgLeft) / drawScale
        val by = (vy - imgTop) / drawScale
        return bx to by
    }

    val (x1, y1) = viewToBitmap(frame.left, frame.top)
    val (x2, y2) = viewToBitmap(frame.right, frame.bottom)
    val left = min(x1, x2).coerceIn(0f, source.width.toFloat())
    val top = min(y1, y2).coerceIn(0f, source.height.toFloat())
    val right = max(x1, x2).coerceIn(0f, source.width.toFloat())
    val bottom = max(y1, y2).coerceIn(0f, source.height.toFloat())
    val w = (right - left).toInt()
    val h = (bottom - top).toInt()
    if (w < 2 || h < 2) return null
    return Bitmap.createBitmap(source, left.toInt(), top.toInt(), w, h)
}

internal fun centeredAspectFillCrop(source: Bitmap, aspectRatio: Float): Bitmap {
    val iw = source.width.toFloat()
    val ih = source.height.toFloat()
    var cropW = iw
    var cropH = cropW / aspectRatio
    if (cropH > ih) {
        cropH = ih
        cropW = cropH * aspectRatio
    }
    val x = max(0f, (iw - cropW) * 0.5f)
    val y = max(0f, (ih - cropH) * 0.5f)
    return Bitmap.createBitmap(source, x.toInt(), y.toInt(), cropW.toInt(), cropH.toInt())
}

internal fun resizeToCanvas(source: Bitmap, targetW: Int, targetH: Int): Bitmap {
    if (targetW <= 0 || targetH <= 0) return source
    val scale = min(targetW.toFloat() / source.width, targetH.toFloat() / source.height)
    val newW = (source.width * scale).toInt().coerceAtLeast(1)
    val newH = (source.height * scale).toInt().coerceAtLeast(1)
    val scaled = Bitmap.createScaledBitmap(source, newW, newH, true)
    val result = Bitmap.createBitmap(targetW, targetH, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(result)
    canvas.drawBitmap(
        scaled,
        (targetW - newW) / 2f,
        (targetH - newH) / 2f,
        Paint(Paint.ANTI_ALIAS_FLAG),
    )
    if (scaled !== source) scaled.recycle()
    return result
}

internal fun loadOrientedBitmap(context: Context, uri: Uri): Bitmap? {
    val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
    if (bytes.isEmpty()) return null
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
    val maxSide = max(bounds.outWidth, bounds.outHeight).coerceAtLeast(1)
    var sampleSize = 1
    while (maxSide / sampleSize > 4096) sampleSize *= 2
    val opts = BitmapFactory.Options().apply { inSampleSize = sampleSize }
    val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts) ?: return null
    val orientation = runCatching {
        ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL,
        )
    }.getOrDefault(ExifInterface.ORIENTATION_NORMAL)
    return applyExifOrientation(decoded, orientation)
}

private fun applyExifOrientation(bitmap: Bitmap, orientation: Int): Bitmap {
    val matrix = Matrix()
    when (orientation) {
        ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
        ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
        ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
        ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.postScale(-1f, 1f)
        ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.postScale(1f, -1f)
        else -> return bitmap
    }
    val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    if (rotated !== bitmap) bitmap.recycle()
    return rotated
}

private fun bitmapToDataUrl(bitmap: Bitmap): String {
    val stream = ByteArrayOutputStream()
    val format = if (bitmap.hasAlpha()) Bitmap.CompressFormat.PNG else Bitmap.CompressFormat.JPEG
    val quality = if (format == Bitmap.CompressFormat.PNG) 100 else 88
    bitmap.compress(format, quality, stream)
    val mime = if (format == Bitmap.CompressFormat.PNG) "image/png" else "image/jpeg"
    val b64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
    return "data:$mime;base64,$b64"
}
