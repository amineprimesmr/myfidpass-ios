package fr.myfidpass.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp

@Composable
fun MiniSparklineChart(
    values: List<Float>,
    modifier: Modifier = Modifier,
    lineColor: Color = Color(0xFF2563EB),
    fillColor: Color = lineColor.copy(alpha = 0.15f),
) {
    if (values.isEmpty()) return
    Canvas(
        modifier
            .fillMaxWidth()
            .height(48.dp),
    ) {
        val max = values.maxOrNull()?.coerceAtLeast(1f) ?: 1f
        val stepX = size.width / (values.size - 1).coerceAtLeast(1)
        val path = Path()
        val fill = Path()
        values.forEachIndexed { i, v ->
            val x = i * stepX
            val y = size.height - (v / max) * size.height * 0.9f - size.height * 0.05f
            if (i == 0) {
                path.moveTo(x, y)
                fill.moveTo(x, size.height)
                fill.lineTo(x, y)
            } else {
                path.lineTo(x, y)
                fill.lineTo(x, y)
            }
        }
        fill.lineTo(size.width, size.height)
        fill.close()
        drawPath(fill, fillColor)
        drawPath(path, lineColor, style = Stroke(width = 3f))
        val last = values.last()
        val lx = (values.size - 1) * stepX
        val ly = size.height - (last / max) * size.height * 0.9f - size.height * 0.05f
        drawCircle(lineColor, radius = 5f, center = Offset(lx, ly))
    }
}

@Composable
fun MiniBarChart(
    values: List<Float>,
    modifier: Modifier = Modifier,
    barColor: Color = Color(0xFF2563EB),
) {
    if (values.isEmpty()) return
    Canvas(
        modifier
            .fillMaxWidth()
            .height(56.dp),
    ) {
        val max = values.maxOrNull()?.coerceAtLeast(1f) ?: 1f
        val barW = size.width / values.size * 0.65f
        val gap = size.width / values.size
        values.forEachIndexed { i, v ->
            val h = (v / max) * size.height * 0.85f
            drawRect(
                color = barColor,
                topLeft = Offset(i * gap + (gap - barW) / 2f, size.height - h),
                size = androidx.compose.ui.geometry.Size(barW, h),
            )
        }
    }
}
