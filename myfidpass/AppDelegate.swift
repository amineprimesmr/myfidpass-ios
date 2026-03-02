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
        let darkText = UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1)
        let lightBg = UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)
        let primaryBlue = UIColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = lightBg
        navAppearance.titleTextAttributes = [.foregroundColor: darkText]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: darkText]
        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = navAppearance
        navBar.scrollEdgeAppearance = navAppearance
        navBar.compactAppearance = navAppearance
        navBar.tintColor = primaryBlue

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .white
        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarAppearance
        tabBar.unselectedItemTintColor = UIColor.darkGray
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

    // Afficher la notification même quand l’app est au premier plan
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Navigation selon le userInfo si besoin (ex. ouvrir le scanner)
        completionHandler()
    }
}
