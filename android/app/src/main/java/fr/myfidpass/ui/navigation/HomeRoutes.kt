package fr.myfidpass.ui.navigation

object HomeRoutes {
    const val DASHBOARD = "dashboard"
    const val MEMBERS = "members"
    const val MEMBER_DETAIL = "member/{memberId}"
    const val SCAN = "scan"
    const val MYCARD = "mycard"

    fun memberDetail(memberId: String) = "member/$memberId"
}
