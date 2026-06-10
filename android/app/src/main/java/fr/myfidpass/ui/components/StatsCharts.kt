package fr.myfidpass.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private fun sparklinePoints(
    values: List<Float>,
    width: Float,
    height: Float,
    topInset: Float = height * 0.05f,
    plotFactor: Float = 0.9f,
): List<Offset> {
    val max = values.maxOrNull()?.coerceAtLeast(1f) ?: 1f
    val plotH = (height - topInset).coerceAtLeast(1f)
    val stepX = width / (values.size - 1).coerceAtLeast(1)
    return values.mapIndexed { i, v ->
        Offset(
            x = i * stepX,
            y = height - (v / max) * plotH * plotFactor - topInset,
        )
    }
}

private fun Path.addSmoothSparkline(points: List<Offset>) {
    if (points.isEmpty()) return
    moveTo(points[0].x, points[0].y)
    if (points.size == 1) return
    if (points.size == 2) {
        lineTo(points[1].x, points[1].y)
        return
    }
    for (i in 1 until points.size - 1) {
        val cur = points[i]
        val next = points[i + 1]
        val midX = (cur.x + next.x) * 0.5f
        val midY = (cur.y + next.y) * 0.5f
        quadraticBezierTo(cur.x, cur.y, midX, midY)
    }
    val last = points.last()
    val prev = points[points.size - 2]
    quadraticBezierTo(prev.x, prev.y, last.x, last.y)
}

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
        val pts = sparklinePoints(values, size.width, size.height)
        val path = Path().apply { addSmoothSparkline(pts) }
        val fill = Path().apply {
            moveTo(0f, size.height)
            if (pts.isNotEmpty()) {
                lineTo(pts[0].x, pts[0].y)
                if (pts.size == 1) {
                    lineTo(size.width, size.height)
                } else if (pts.size == 2) {
                    lineTo(pts[1].x, pts[1].y)
                } else {
                    for (i in 1 until pts.size - 1) {
                        val cur = pts[i]
                        val next = pts[i + 1]
                        quadraticBezierTo(cur.x, cur.y, (cur.x + next.x) * 0.5f, (cur.y + next.y) * 0.5f)
                    }
                    val last = pts.last()
                    val prev = pts[pts.size - 2]
                    quadraticBezierTo(prev.x, prev.y, last.x, last.y)
                }
                lineTo(size.width, size.height)
            }
            close()
        }
        drawPath(fill, fillColor)
        drawPath(
            path,
            lineColor,
            style = Stroke(width = 3f, cap = StrokeCap.Round, join = StrokeJoin.Round),
        )
        pts.lastOrNull()?.let { end ->
            drawCircle(lineColor, radius = 5f, center = end)
        }
    }
}

@Composable
fun MembersMonthSparklineChart(
    values: List<Float>,
    monthAxisDays: List<Int>,
    lineColor: Color,
    axisLabelColor: Color,
    modifier: Modifier = Modifier,
) {
    if (values.isEmpty()) return
    val days = monthAxisDays.filter { it > 0 }.ifEmpty { List(values.size) { it + 1 } }
    val minDay = days.firstOrNull() ?: 1
    val maxDay = days.lastOrNull() ?: minDay

    BoxWithConstraints(modifier.then(Modifier.height(104.dp))) {
        Canvas(Modifier.matchParentSize()) {
            val topInset = 4f
            val labelBand = 20f
            val plotH = (size.height - topInset - labelBand).coerceAtLeast(1f)
            fun y(v: Float): Float = topInset + plotH - (v.coerceIn(0f, 1f) * plotH * 0.92f)
            fun x(index: Int): Float {
                if (days.size == values.size && maxDay > minDay && index in days.indices) {
                    return (days[index] - minDay).toFloat() / (maxDay - minDay).toFloat() * size.width
                }
                return if (values.size <= 1) size.width * 0.5f
                else index.toFloat() / (values.size - 1).coerceAtLeast(1) * size.width
            }

            val pts = values.mapIndexed { i, v -> Offset(x(i), y(v)) }
            val line = Path().apply { addSmoothSparkline(pts) }
            val fill = Path().apply {
                moveTo(0f, size.height)
                if (pts.isNotEmpty()) {
                    lineTo(pts[0].x, pts[0].y)
                    if (pts.size == 1) {
                        lineTo(size.width, size.height)
                    } else if (pts.size == 2) {
                        lineTo(pts[1].x, pts[1].y)
                    } else {
                        for (i in 1 until pts.size - 1) {
                            val cur = pts[i]
                            val next = pts[i + 1]
                            quadraticBezierTo(cur.x, cur.y, (cur.x + next.x) * 0.5f, (cur.y + next.y) * 0.5f)
                        }
                        val last = pts.last()
                        val prev = pts[pts.size - 2]
                        quadraticBezierTo(prev.x, prev.y, last.x, last.y)
                    }
                    lineTo(size.width, size.height)
                }
                close()
            }
            drawPath(
                fill,
                brush = Brush.verticalGradient(
                    colors = listOf(lineColor.copy(alpha = 0.42f), lineColor.copy(alpha = 0.10f)),
                ),
            )
            drawPath(
                line,
                lineColor,
                style = Stroke(width = 4f, cap = StrokeCap.Round, join = StrokeJoin.Round),
            )
        }

        days.forEach { day ->
            val frac = if (maxDay > minDay) (day - minDay).toFloat() / (maxDay - minDay) else 0.5f
            Text(
                text = "$day",
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                color = axisLabelColor,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .offset(x = maxWidth * frac - 10.dp, y = (-2).dp),
            )
        }
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

/** Courbe panier moyen : cumul ventes du mois — une ligne noire + point au dernier jour. */
@Composable
fun PanierEvolutionSparklineChart(
    values: List<Float>,
    dayLabels: List<Int> = emptyList(),
    modifier: Modifier = Modifier,
) {
    if (values.isEmpty()) return
    val days = dayLabels.takeIf { it.size == values.size } ?: List(values.size) { it + 1 }
    Canvas(modifier.fillMaxWidth().height(52.dp)) {
        val topInset = 10f
        val bottomInset = 12f
        val plotH = (size.height - topInset - bottomInset).coerceAtLeast(1f)
        fun y(v: Float): Float = topInset + plotH - (v.coerceIn(0f, 1f) * plotH * 0.88f)
        val trailingInset = 14.dp.toPx()
        val plotWidth = (size.width - trailingInset).coerceAtLeast(1f)
        fun x(index: Int): Float {
            if (days.size >= 2) {
                val minD = days.first()
                val maxD = days.last()
                if (maxD > minD) {
                    return (days[index] - minD).toFloat() / (maxD - minD) * plotWidth
                }
            }
            return if (values.size == 1) plotWidth * 0.5f
            else index.toFloat() / (values.size - 1).coerceAtLeast(1) * plotWidth
        }
        val pts = values.mapIndexed { i, v -> Offset(x(i), y(v)) }

        fun drawSmooth(path: Path) {
            if (pts.isEmpty()) return
            path.moveTo(pts[0].x, pts[0].y)
            if (pts.size == 1) return
            if (pts.size == 2) {
                path.lineTo(pts[1].x, pts[1].y)
                return
            }
            for (i in 1 until pts.lastIndex) {
                val cur = pts[i]
                val next = pts[i + 1]
                path.quadraticBezierTo(cur.x, cur.y, (cur.x + next.x) * 0.5f, (cur.y + next.y) * 0.5f)
            }
            val end = pts.last()
            val prev = pts[pts.lastIndex - 1]
            path.quadraticBezierTo(prev.x, prev.y, end.x, end.y)
        }

        val line = Path().apply { drawSmooth(this) }
        drawPath(
            line,
            Color.Black.copy(alpha = 0.9f),
            style = Stroke(width = 3.4f, cap = StrokeCap.Round, join = StrokeJoin.Round),
        )

        val endIndex = values.indices.lastOrNull { values[it] > 0.12f } ?: values.lastIndex
        val end = pts[endIndex]
        drawCircle(color = Color.Black, radius = 4.2f, center = end)
    }
}
