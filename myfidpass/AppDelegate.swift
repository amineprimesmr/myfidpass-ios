//
//  AppDelegate.swift
//  myfidpass
//
//  Délégation pour les notifications push (enregistrement du device token).
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        configureAppearance()
        return true
    }

    private func configureAppearance() {
        let primaryBlue = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.backgroundColor = .systemGroupedBackground
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = navAppearance
        navBar.scrollEdgeAppearance = navAppearance
        navBar.compactAppearance = navAppearance
        navBar.tintColor = primaryBlue

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        let tabBarScrollEdge = UITabBarAppearance()
        tabBarScrollEdge.configureWithTransparentBackground()
        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarScrollEdge
        tabBar.isTranslucent = true
        tabBar.unselectedItemTintColor = UIColor.secondaryLabel
        tabBar.tintColor = primaryBlue
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            NotificationsService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Simulateur ou erreur config : on ignore
    }

    /// Push silencieux (`content-available`) : sync tableau de bord sans bannière.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if let action = userInfo["myfidpass_action"] as? String, action == "dashboard_sync" {
            SyncService.handleSilentDashboardPush(completion: completionHandler)
            return
        }
        if let aps = userInfo["aps"] as? [String: Any] {
            let contentAvailable =
                (aps["content-available"] as? Int) == 1 || (aps["content-available"] as? Bool) == true
            let hasAlert = aps["alert"] != nil
            if contentAvailable && !hasAlert {
                SyncService.handleSilentDashboardPush(completion: completionHandler)
                return
            }
        }
        completionHandler(.noData)
    }

    // Afficher la notification même quand l’app est au premier plan
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        if let action = userInfo["myfidpass_action"] as? String, action == "dashboard_sync" {
            completionHandler([])
            return
        }
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let action = userInfo["myfidpass_action"] as? String {
            switch action {
            case "campaign_receipt":
                NotificationCenter.default.post(name: .myfidpassOpenCampaignsTab, object: nil)
            case "google_business_review":
                var info: [AnyHashable: Any] = [:]
                if let reviewId = userInfo["review_id"] as? String { info["review_id"] = reviewId }
                if let rating = userInfo["rating"] as? String { info["rating"] = rating }
                if let author = userInfo["author"] as? String { info["author"] = author }
                NotificationCenter.default.post(
                    name: .googleBusinessNewReviewReceived,
                    object: nil,
                    userInfo: info
                )
                NotificationCenter.default.post(
                    name: Notification.Name("myfidpass.openGoogleBusinessHub"),
                    object: nil,
                    userInfo: info
                )
            default:
                break
            }
        }
        completionHandler()
    }
}
