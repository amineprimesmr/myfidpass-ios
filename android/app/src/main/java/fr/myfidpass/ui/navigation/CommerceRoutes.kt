package fr.myfidpass.ui.navigation

object CommerceRoutes {
    const val HUB = "commerce_hub"
    const val SETTINGS = "commerce_settings"
    const val SETTINGS_HUB = "commerce_settings_hub"
    const val SETTINGS_APP = "commerce_settings_app"
    const val ACCOUNT = "commerce_account"
    const val ADD_COMMERCE = "commerce_add"
    const val STATS = "commerce_stats"
    const val ACCOUNTING = "commerce_accounting"
    const val TRACEABILITY = "commerce_traceability"
    const val ADMIN = "commerce_admin"
    const val PROGRAM = "commerce_program"
    const val GAMES = "commerce_games"
    const val FLYER = "commerce_flyer"
    const val SOCIAL = "commerce_social"
    const val SOCIAL_MISSIONS = "commerce_social_missions"
    const val TOOLS = "commerce_tools"
    const val ESTABLISHMENT = "commerce_establishment"
    const val TEAM = "commerce_team"
    const val TEAM_MEMBER = "commerce_team_member/{memberId}"

    fun teamMember(memberId: String) = "commerce_team_member/$memberId"
    const val MATCH_PREDICTIONS = "commerce_match_predictions"
    const val STATS_TRANSACTIONS = "commerce_stats_transactions"
    const val MEMBERS = "commerce_members"
    const val MEMBER_DETAIL = "commerce_member/{memberId}"

    fun memberDetail(memberId: String) = "commerce_member/$memberId"
    const val SCAN_SECURITY = "commerce_scan_security"
    const val LOYALTY_NETWORK = "commerce_loyalty_network"
    const val GOOGLE_BUSINESS = "commerce_google_business"
}
