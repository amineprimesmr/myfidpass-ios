package fr.myfidpass.ui.navigation

/**
 * Routes de navigation — alignement avec l’app iOS (`RootView`, `MainTabView`, navigation interne).
 * Les sous-écrans sont branchés progressivement pour parité fonctionnelle.
 */
object AppRoutes {
    const val Bootstrap = "bootstrap"
    const val Welcome = "welcome"
    const val Login = "login"
    const val SignUp = "signup"
    const val MainTabs = "main"
    const val MembersList = "members"
    const val MemberDetail = "member/{id}"
    const val Scanner = "scanner"
    const val MyCard = "my_card"
    const val CommerceStats = "commerce_stats"
    const val Categories = "categories"
    const val SettingsRoot = "settings"
    const val SettingsNotifications = "settings_notifications"
    const val SettingsScan = "settings_scan"
    const val SettingsLocation = "settings_location"
    const val EstablishmentEditor = "establishment"
    const val CampaignCompose = "campaign_compose"
    const val FlyerHub = "flyer_hub"
    const val AdminRoot = "admin_root"
}
