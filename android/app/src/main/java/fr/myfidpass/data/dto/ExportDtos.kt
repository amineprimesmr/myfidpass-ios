package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class MerchantAccountingPackResponse(
    @SerialName("business_slug") val businessSlug: String? = null,
    @SerialName("business_name") val businessName: String? = null,
    @SerialName("generated_at") val generatedAt: String? = null,
    @SerialName("period_label") val periodLabel: String? = null,
    val filters: MerchantAccountingPackFilters? = null,
    val summary: MerchantAccountingPackSummary? = null,
    val files: List<MerchantAccountingPackFile> = emptyList(),
)

@Serializable
data class MerchantAccountingPackFilters(
    val days: Int? = null,
    @SerialName("date_from") val dateFrom: String? = null,
    @SerialName("date_to") val dateTo: String? = null,
    val limit: Int? = null,
)

@Serializable
data class MerchantAccountingPackSummary(
    @SerialName("row_count") val rowCount: Int? = null,
    @SerialName("points_credited_total") val pointsCreditedTotal: Int? = null,
    @SerialName("points_debited_total") val pointsDebitedTotal: Int? = null,
)

@Serializable
data class MerchantAccountingPackFile(
    val filename: String? = null,
    @SerialName("content_utf8") val contentUtf8: String? = null,
    val description: String? = null,
)

@Serializable
data class TransactionExportJsonResponse(
    @SerialName("business_name") val businessName: String? = null,
    val slug: String? = null,
    @SerialName("generated_at") val generatedAt: String? = null,
    @SerialName("period_label") val periodLabel: String? = null,
    @SerialName("total_matching") val totalMatching: Int? = null,
    @SerialName("returned_count") val returnedCount: Int? = null,
    val truncated: Boolean? = null,
    val filters: TransactionExportFilters? = null,
    val summary: TransactionExportSummary? = null,
    val transactions: List<TransactionExportRow> = emptyList(),
)

@Serializable
data class TransactionExportFilters(
    val days: Int? = null,
    val from: String? = null,
    val to: String? = null,
    val types: String? = null,
    @SerialName("member_id") val memberId: String? = null,
)

@Serializable
data class TransactionExportSummary(
    @SerialName("row_count") val rowCount: Int? = null,
    @SerialName("points_credited_total") val pointsCreditedTotal: Int? = null,
    @SerialName("points_debited_total") val pointsDebitedTotal: Int? = null,
)

@Serializable
data class TransactionExportRow(
    val id: String? = null,
    @SerialName("member_id") val memberId: String? = null,
    @SerialName("member_name") val memberName: String? = null,
    @SerialName("member_email") val memberEmail: String? = null,
    val type: String? = null,
    @SerialName("type_label") val typeLabel: String? = null,
    val detail: String? = null,
    val points: Int? = null,
    @SerialName("created_at") val createdAt: String? = null,
)
