package fr.myfidpass.ui.navigation

object HomeRoutes {
    const val DASHBOARD = "dashboard"
    const val MEMBERS = "members"
    const val MEMBER_DETAIL = "member/{memberId}"
    const val ACTIVITY_FULL = "activity_full"
    const val SCAN = "scan"
    const val SCAN_CREDIT = "scan_credit/{memberId}/{memberName}/{barcode}/{memberPoints}"
    const val SCAN_REWARD_REDEEM =
        "scan_reward_redeem/{memberName}/{barcode}/{rewardLabel}/{pointsRequired}/{pointsBalance}/{eligible}/{mode}"
    const val MYCARD = "mycard"

    fun memberDetail(memberId: String) = "member/$memberId"

    fun scanCredit(
        memberId: String,
        memberName: String,
        barcode: String,
        memberPoints: Int?,
    ): String {
        val nameEnc = java.net.URLEncoder.encode(memberName, Charsets.UTF_8.name())
        val barcodeEnc = java.net.URLEncoder.encode(barcode, Charsets.UTF_8.name())
        val pts = memberPoints?.toString() ?: "null"
        return "scan_credit/$memberId/$nameEnc/$barcodeEnc/$pts"
    }

    fun scanRewardRedeem(
        memberName: String,
        barcode: String,
        rewardLabel: String,
        pointsRequired: Int,
        pointsBalance: Int,
        eligible: Boolean,
        mode: String,
    ): String {
        val nameEnc = java.net.URLEncoder.encode(memberName, Charsets.UTF_8.name())
        val barcodeEnc = java.net.URLEncoder.encode(barcode, Charsets.UTF_8.name())
        val labelEnc = java.net.URLEncoder.encode(rewardLabel, Charsets.UTF_8.name())
        val elig = if (eligible) "1" else "0"
        return "scan_reward_redeem/$nameEnc/$barcodeEnc/$labelEnc/$pointsRequired/$pointsBalance/$elig/$mode"
    }
}
