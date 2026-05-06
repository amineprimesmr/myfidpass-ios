package fr.myfidpass.ui.navigation

/**
 * Registre de parité avec les écrans Swift (référence pour itérations).
 * Chaque entrée = surface à reproduire en Compose avec le même flux API.
 */
@Suppress("unused")
object IosParityChecklist {
    val tabs = listOf(
        "MainTabView → DashboardView",
        "MainTabView → CampaignNotificationsView",
        "MainTabView → ProfileView",
    )
    val auth = listOf(
        "WelcomeFlow", "LoginView", "SignUpView", "OnboardingChoiceView",
        "MerchantSubscriptionGateView", "MerchantSubscriptionPaywallBlockingView",
    )
    val dashboard = listOf(
        "DashboardView", "DashboardFintechHomeLayout", "DashboardActivityFullView",
        "AddPointsAmountSheet", "ReceiptTicketValidationView", "SlideToConfirm",
        // Android : stats Accueil + navigation Membres / Scan / fiche (crédit + Google Wallet URL).
    )
    val myCard = listOf(
        "MyCardView", "MyCardEditView", "CardElementCustomizationSheet",
        "WalletCardPreview", "AddToWalletPresenter",
        // Android : WalletCardPreviewAndroid + QR fidélité + lien page publique ; édition couleurs/logo = à faire.
    )
    val profile = listOf(
        "ProfileView", "EstablishmentEditorView", "CommerceTopBarView",
        "CommerceStatisticsDashboardView", "MerchantProgramHubView",
        "GoogleReviewsCommerceDashboardView", "CommerceFlyerSavedBlockView",
    )
    val settings = listOf(
        "SettingsView", "AccountSettingsDetailView", "SettingsScanSecurityView",
        "MerchantAccountingPackView", "MerchantTraceabilityExportView",
    )
    val admin = listOf("PlatformAdminRootView")
    val misc = listOf(
        "DIQRScannerView", "CategoriesManagementView", "PerimeterMapView",
        "AppUpdateView", "FirstLaunchOnboardingView",
    )
}
