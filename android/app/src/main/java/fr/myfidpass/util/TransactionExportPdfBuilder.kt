package fr.myfidpass.util

import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import fr.myfidpass.data.dto.TransactionExportJsonResponse
import fr.myfidpass.data.dto.TransactionExportRow

/** PDF local — aligné iOS `TransactionExportPDFBuilder`. */
object TransactionExportPdfBuilder {

    fun buildPdf(report: TransactionExportJsonResponse): ByteArray {
        val doc = PdfDocument()
        val pageWidth = 595
        val pageHeight = 842
        val margin = 40f
        var y = margin
        var pageNumber = 1
        var page = doc.startPage(PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create())
        var canvas = page.canvas
        val titlePaint = Paint().apply {
            textSize = 18f
            isFakeBoldText = true
        }
        val headerPaint = Paint().apply {
            textSize = 12f
            isFakeBoldText = true
        }
        val bodyPaint = Paint().apply { textSize = 10f }

        fun newPageIfNeeded(extra: Float = 14f) {
            if (y + extra > pageHeight - margin) {
                doc.finishPage(page)
                pageNumber++
                page = doc.startPage(PdfDocument.PageInfo.Builder(pageWidth, pageHeight, pageNumber).create())
                canvas = page.canvas
                y = margin
            }
        }

        fun drawLine(text: String, paint: Paint = bodyPaint) {
            newPageIfNeeded(16f)
            canvas.drawText(text.take(110), margin, y, paint)
            y += 14f
        }

        drawLine(report.businessName ?: "MyFidpass", titlePaint)
        drawLine("Période : ${report.periodLabel ?: "—"}", headerPaint)
        drawLine("Généré : ${report.generatedAt ?: "—"}")
        report.summary?.let { s ->
            drawLine(
                "Lignes : ${s.rowCount ?: report.transactions.size} · " +
                    "+${s.pointsCreditedTotal ?: 0} pts · -${s.pointsDebitedTotal ?: 0} pts",
            )
        }
        y += 8f
        drawLine("Date · Client · Type · Points · Détail", headerPaint)

        report.transactions.forEach { row ->
            drawLine(formatRow(row))
        }

        doc.finishPage(page)
        val out = java.io.ByteArrayOutputStream()
        doc.writeTo(out)
        doc.close()
        return out.toByteArray()
    }

    private fun formatRow(row: TransactionExportRow): String {
        val date = row.createdAt?.take(16)?.replace('T', ' ') ?: "—"
        val client = row.memberName?.ifBlank { row.memberEmail } ?: row.memberEmail ?: "—"
        val type = row.typeLabel ?: row.type ?: "—"
        val pts = row.points?.let { if (it >= 0) "+$it" else it.toString() } ?: "—"
        val detail = row.detail?.take(40).orEmpty()
        return "$date · ${client.take(22)} · ${type.take(16)} · $pts · $detail"
    }
}
