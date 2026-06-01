package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class GoogleBusinessStatusResponse(
    val connected: Boolean? = null,
    @SerialName("location_pending") val locationPending: Boolean? = null,
    @SerialName("location_title") val locationTitle: String? = null,
    @SerialName("matched_place_id") val matchedPlaceId: String? = null,
    @SerialName("pubsub_live_notifications") val pubsubLiveNotifications: Boolean? = null,
    val counts: GoogleBusinessReviewCounts? = null,
)

@Serializable
data class GoogleBusinessReviewCounts(
    val total: Int? = null,
    @SerialName("unreplied") val unreplied: Int? = null,
    @SerialName("starred") val starred: Int? = null,
)

@Serializable
data class GoogleBusinessReviewRow(
    @SerialName("review_id") val reviewId: String? = null,
    val rating: Int? = null,
    @SerialName("author_name") val authorName: String? = null,
    val comment: String? = null,
    @SerialName("reply_comment") val replyComment: String? = null,
    @SerialName("create_time") val createTime: String? = null,
    @SerialName("update_time") val updateTime: String? = null,
    val starred: Boolean? = null,
    val archived: Boolean? = null,
    @SerialName("seen_by_merchant") val seenByMerchant: Boolean? = null,
)

@Serializable
data class GoogleBusinessReviewsResponse(
    val reviews: List<GoogleBusinessReviewRow> = emptyList(),
    val counts: GoogleBusinessReviewCounts? = null,
)

@Serializable
data class GoogleBusinessPostRow(
    @SerialName("post_id") val postId: String? = null,
    val summary: String? = null,
    @SerialName("topic_type") val topicType: String? = null,
    val state: String? = null,
    @SerialName("create_time") val createTime: String? = null,
    @SerialName("update_time") val updateTime: String? = null,
)

@Serializable
data class GoogleBusinessPostsResponse(
    val posts: List<GoogleBusinessPostRow> = emptyList(),
)

@Serializable
data class GoogleBusinessReviewReplyRequest(
    @SerialName("reply_comment") val replyComment: String,
)

@Serializable
data class GoogleBusinessCreatePostRequest(
    val summary: String,
    @SerialName("topic_type") val topicType: String = "STANDARD",
    @SerialName("language_code") val languageCode: String = "fr",
    @SerialName("media_url") val mediaUrl: String? = null,
)
