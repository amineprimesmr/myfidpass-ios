package fr.myfidpass.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class RewardsRedeemedBreakdownRow(
    val label: String,
    val count: Int = 0,
)

@Serializable
data class SocialFollowsClaimedDto(
    val instagram: Int? = null,
    val tiktok: Int? = null,
    val facebook: Int? = null,
    val twitter: Int? = null,
)

@Serializable
data class NotificationCampaignInsightDto(
    @SerialName("batch_id") val batchId: String,
    @SerialName("trigger_name") val triggerName: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("sent_total") val sentTotal: Int? = null,
    @SerialName("recipients_distinct") val recipientsDistinct: Int? = null,
    @SerialName("returned_within_48h") val returnedWithin48h: Int? = null,
    @SerialName("notification_title") val notificationTitle: String? = null,
    val title: String? = null,
    val message: String? = null,
    @SerialName("sent_passkit") val sentPasskit: Int? = null,
    @SerialName("sent_web_push") val sentWebPush: Int? = null,
    @SerialName("delivery_status") val deliveryStatus: String? = null,
    @SerialName("expected_devices") val expectedDevices: Int? = null,
) {
    val isDeliveryPending: Boolean
        get() {
            val s = deliveryStatus?.trim()?.lowercase().orEmpty()
            return s == "queued" || s == "sending" || s == "pending"
        }

    val confirmedRecipientsCount: Int
        get() = if (isDeliveryPending) 0 else maxOf(recipientsDistinct ?: 0, sentTotal ?: 0)
}

@Serializable
data class BusinessStatsResponse(
    val period: String? = null,
    @SerialName("period_key") val periodKey: String? = null,
    @SerialName("members_count") val membersCount: Int? = null,
    @SerialName("points_this_month") val pointsThisMonth: Int? = null,
    @SerialName("transactions_this_month") val transactionsThisMonth: Int? = null,
    @SerialName("new_members_last_7_days") val newMembersLast7Days: Int? = null,
    @SerialName("new_members_last_30_days") val newMembersLast30Days: Int? = null,
    @SerialName("new_members_in_period") val newMembersInPeriod: Int? = null,
    @SerialName("inactive_members_30_days") val inactiveMembers30Days: Int? = null,
    @SerialName("inactive_members_90_days") val inactiveMembers90Days: Int? = null,
    @SerialName("points_average_per_member") val pointsAveragePerMember: Double? = null,
    @SerialName("active_members_in_period") val activeMembersInPeriod: Int? = null,
    @SerialName("retention_pct") val retentionPct: Double? = null,
    @SerialName("recurrent_members_in_period") val recurrentMembersInPeriod: Int? = null,
    @SerialName("visits_in_period") val visitsInPeriod: Int? = null,
    @SerialName("avg_visits_per_active_member") val avgVisitsPerActiveMember: Double? = null,
    @SerialName("avg_basket_eur") val avgBasketEur: Double? = null,
    @SerialName("baseline_avg_basket_eur") val baselineAvgBasketEur: Double? = null,
    @SerialName("rewards_redeemed_count") val rewardsRedeemedCount: Int? = null,
    @SerialName("rewards_redeemed_breakdown")
    val rewardsRedeemedBreakdown: List<RewardsRedeemedBreakdownRow>? = null,
    @SerialName("points_redeemed_in_period") val pointsRedeemedInPeriod: Int? = null,
    @SerialName("google_reviews_new_in_period") val googleReviewsNewInPeriod: Int? = null,
    @SerialName("social_follows_claimed") val socialFollowsClaimed: SocialFollowsClaimedDto? = null,
    @SerialName("notification_campaigns") val notificationCampaigns: List<NotificationCampaignInsightDto>? = null,
    @SerialName("business_name") val businessName: String? = null,
)

@Serializable
data class DashboardTrafficHourBucket(
    val hour: Int = 0,
    val count: Int = 0,
)

@Serializable
data class DashboardTrafficWeekdayBucket(
    val weekday: Int = 0,
    val label: String? = null,
    val count: Int = 0,
)

@Serializable
data class DashboardTrafficPeakHour(
    val hour: Int = 0,
    val count: Int = 0,
    @SerialName("pct_of_total") val pctOfTotal: Double? = null,
)

@Serializable
data class DashboardTrafficPeakWeekday(
    val weekday: Int = 0,
    val label: String? = null,
    val count: Int = 0,
    @SerialName("pct_of_total") val pctOfTotal: Double? = null,
)

@Serializable
data class DashboardTrafficPatternsResponse(
    val period: String? = null,
    @SerialName("period_key") val periodKey: String? = null,
    @SerialName("timezone_note") val timezoneNote: String? = null,
    val basis: String? = null,
    @SerialName("total_events") val totalEvents: Int? = null,
    @SerialName("by_hour") val byHour: List<DashboardTrafficHourBucket> = emptyList(),
    @SerialName("by_weekday") val byWeekday: List<DashboardTrafficWeekdayBucket> = emptyList(),
    @SerialName("peak_hour") val peakHour: DashboardTrafficPeakHour? = null,
    @SerialName("peak_weekday") val peakWeekday: DashboardTrafficPeakWeekday? = null,
)

@Serializable
data class BusinessMembersResponse(
    val members: List<MemberDto> = emptyList(),
    val total: Int? = null,
)

@Serializable
data class MemberDto(
    val id: String,
    val name: String? = null,
    val email: String? = null,
    val points: Int? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("last_visit_at") val lastVisitAt: String? = null,
)

/** Membre renvoyé par scan / lookup (champs souples, `id` parfois optionnel selon erreurs partielles). */
@Serializable
data class ScanMemberDto(
    val id: String? = null,
    val name: String? = null,
    val email: String? = null,
    val points: Int? = null,
    @SerialName("last_visit_at") val lastVisitAt: String? = null,
)

@Serializable
data class PointsRewardTierDto(
    val points: Int = 0,
    val label: String? = null,
    @SerialName("min_purchase_eur") val minPurchaseEur: Double? = null,
)

@Serializable
data class GoogleReviewEngagementDto(
    @SerialName("place_id") val placeId: String? = null,
)

@Serializable
data class EngagementRewardsDto(
    @SerialName("google_review") val googleReview: GoogleReviewEngagementDto? = null,
)

@Serializable
data class BusinessSettingsResponse(
    @SerialName("organization_name") val organizationName: String? = null,
    @SerialName("background_color") val backgroundColor: String? = null,
    @SerialName("foreground_color") val foregroundColor: String? = null,
    @SerialName("label_color") val labelColor: String? = null,
    @SerialName("logo_url") val logoUrl: String? = null,
    @SerialName("logo_updated_at") val logoUpdatedAt: String? = null,
    @SerialName("logo_icon_url") val logoIconUrl: String? = null,
    @SerialName("notification_icon_url") val notificationIconUrl: String? = null,
    @SerialName("notification_title_override") val notificationTitleOverride: String? = null,
    @SerialName("notification_change_message") val notificationChangeMessage: String? = null,
    @SerialName("program_type") val programType: String? = null,
    @SerialName("loyalty_mode") val loyaltyMode: String? = null,
    @SerialName("points_per_euro") val pointsPerEuro: Int? = null,
    @SerialName("points_per_visit") val pointsPerVisit: Int? = null,
    @SerialName("points_min_amount_eur") val pointsMinAmountEur: Double? = null,
    @SerialName("points_reward_tiers") val pointsRewardTiers: List<PointsRewardTierDto>? = null,
    @SerialName("required_stamps") val requiredStamps: Int? = null,
    @SerialName("stamp_emoji") val stampEmoji: String? = null,
    @SerialName("stamp_reward_label") val stampRewardLabel: String? = null,
    @SerialName("stamp_mid_reward_label") val stampMidRewardLabel: String? = null,
    @SerialName("start_game_reward_label") val startGameRewardLabel: String? = null,
    @SerialName("back_terms") val backTerms: String? = null,
    @SerialName("back_contact") val backContact: String? = null,
    @SerialName("strip_display_mode") val stripDisplayMode: String? = null,
    @SerialName("strip_text") val stripText: String? = null,
    @SerialName("label_restants") val labelRestants: String? = null,
    @SerialName("label_member") val labelMember: String? = null,
    @SerialName("header_right_text") val headerRightText: String? = null,
    @SerialName("scan_max_passes_per_member_per_day") val scanMaxPassesPerMemberPerDay: Int? = null,
    @SerialName("scan_max_points_per_transaction") val scanMaxPointsPerTransaction: Int? = null,
    /** 1 = exiger QR ticket pour crédits € (API renvoie 0/1, pas bool JSON). */
    @SerialName("require_receipt_qr_validation") val requireReceiptQrValidation: Int? = null,
    @SerialName("receipt_qr_tolerance_cents") val receiptQrToleranceCents: Int? = null,
    @SerialName("welcome_bonus_enabled") val welcomeBonusEnabled: Int? = null,
    @SerialName("welcome_bonus_amount") val welcomeBonusAmount: Int? = null,
    @SerialName("wallet_pass_include_locations") val walletPassIncludeLocations: Int? = null,
    @SerialName("has_card_background") val hasCardBackground: Boolean? = null,
    @SerialName("has_flyer_prefs") val hasFlyerPrefs: Boolean? = null,
    @SerialName("flyer_prefs_updated_at") val flyerPrefsUpdatedAt: String? = null,
    @SerialName("card_background_updated_at") val cardBackgroundUpdatedAt: String? = null,
    @SerialName("has_stamp_icon") val hasStampIcon: Boolean? = null,
    @SerialName("campaign_automation") val campaignAutomation: CampaignAutomationConfigDto? = null,
    @SerialName("location_lat") val locationLat: Double? = null,
    @SerialName("location_lng") val locationLng: Double? = null,
    @SerialName("location_radius_meters") val locationRadiusMeters: Int? = null,
    @SerialName("location_relevant_text") val locationRelevantText: String? = null,
    @SerialName("location_address") val locationAddress: String? = null,
    @SerialName("engagement_rewards") val engagementRewards: EngagementRewardsDto? = null,
)

@Serializable
data class ScanRewardRedeemPreviewDto(
    val mode: String? = null,
    val label: String? = null,
    @SerialName("tier_index") val tierIndex: Int? = null,
    @SerialName("points_required") val pointsRequired: Int? = null,
    @SerialName("points_balance") val pointsBalance: Int? = null,
    val eligible: Boolean? = null,
)

@Serializable
data class ScanLookupEnvelope(
    val member: ScanMemberDto? = null,
    val found: Boolean? = null,
    @SerialName("reward_redeem") val rewardRedeem: ScanRewardRedeemPreviewDto? = null,
)

@Serializable
data class RewardRedeemScanRequest(
    val barcode: String,
)

@Serializable
data class RewardRedeemScanResponse(
    val ok: Boolean? = null,
    val type: String? = null,
    @SerialName("reward_label") val rewardLabel: String? = null,
    @SerialName("points_deducted") val pointsDeducted: Int? = null,
    @SerialName("new_points") val newPoints: Int? = null,
    val message: String? = null,
    val member: ScanMemberDto? = null,
)

@Serializable
data class ScanRequest(
    val barcode: String,
    val visit: Boolean = false,
    val points: Int? = null,
    @SerialName("amount_eur") val amountEur: Double? = null,
    @SerialName("receipt_validation_token") val receiptValidationToken: String? = null,
)

@Serializable
data class ScanResponse(
    val ok: Boolean? = null,
    val message: String? = null,
    val member: ScanMemberDto? = null,
    @SerialName("points_added") val pointsAdded: Int? = null,
    @SerialName("new_balance") val newBalance: Int? = null,
)

@Serializable
data class MemberPublicDetailDto(
    val id: String? = null,
    val email: String? = null,
    val name: String? = null,
    val points: Int? = null,
    @SerialName("last_visit_at") val lastVisitAt: String? = null,
    val phone: String? = null,
    val city: String? = null,
    @SerialName("birth_date") val birthDate: String? = null,
)

@Serializable
data class GoogleWalletUrlResponse(
    val url: String? = null,
)

@Serializable
data class CreditMemberRequest(
    val points: Int? = null,
    @SerialName("amount_eur") val amountEur: Double? = null,
    val visit: Boolean? = null,
    @SerialName("receipt_validation_token") val receiptValidationToken: String? = null,
)

@Serializable
data class CreditPointsResponse(
    val ok: Boolean? = null,
    val message: String? = null,
    @SerialName("new_balance") val newBalance: Int? = null,
    val member: ScanMemberDto? = null,
)

@Serializable
data class NotificationSendRequest(
    val message: String,
    val title: String? = null,
    val segment: String? = null,
    @SerialName("business_slugs") val businessSlugs: List<String>? = null,
)

@Serializable
data class NotificationBusinessReadinessDto(
    val slug: String? = null,
    @SerialName("business_id") val businessId: String? = null,
    val name: String? = null,
    @SerialName("organization_name") val organizationName: String? = null,
    @SerialName("loyalty_group_id") val loyaltyGroupId: String? = null,
    @SerialName("has_notification_icon") val hasNotificationIcon: Boolean? = null,
    @SerialName("passkit_device_count") val passkitDeviceCount: Int? = null,
    @SerialName("web_push_count") val webPushCount: Int? = null,
    @SerialName("total_devices") val totalDevices: Int? = null,
    /** Vrais clients que la campagne touchera (filtre technique appliqué côté backend, = dispatch). */
    @SerialName("deliverable_devices") val deliverableDevices: Int? = null,
    /** Carte d'aperçu du commerçant : testable via auto-test, hors campagne réelle. */
    @SerialName("preview_devices") val previewDevices: Int? = null,
    /** `true` : seule la carte d'aperçu est enregistrée (0 vrai client). */
    @SerialName("preview_only") val previewOnly: Boolean? = null,
    @SerialName("delivery_hint") val deliveryHint: String? = null,
    @SerialName("members_count") val membersCount: Int? = null,
    @SerialName("subscription_ok") val subscriptionOk: Boolean? = null,
    val ready: Boolean? = null,
    @SerialName("block_code") val blockCode: String? = null,
    @SerialName("block_message") val blockMessage: String? = null,
) {
    val displayName: String
        get() = (name ?: organizationName ?: slug ?: "Commerce").trim()

    /** Nombre de vrais clients destinataires (priorité au champ backend réconcilié, repli sur le total). */
    val realClientDeviceCount: Int
        get() = deliverableDevices ?: totalDevices ?: 0
}

@Serializable
data class NotificationReadinessResponse(
    val ok: Boolean? = null,
    val businesses: List<NotificationBusinessReadinessDto>? = null,
)
