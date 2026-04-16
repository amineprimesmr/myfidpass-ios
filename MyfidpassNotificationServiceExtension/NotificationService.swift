import UserNotifications

/**
 * Notification Service Extension — myfidpass
 *
 * Intercepte les notifications APNs avec `mutable-content: 1` et remplace l'icône
 * par le logo du commerçant téléchargé depuis `notification_icon_url`.
 *
 * Fallback : si `notification_icon_url` est absent ou si le téléchargement échoue,
 * utilise l'icône app `logonotif` incluse dans le bundle de l'extension.
 *
 * IMPORTANT : s'assurer que `logonotif.png` est bien incluse dans les ressources
 * de la target `MyfidpassNotificationServiceExtension` dans Xcode (Build Phases → Copy Bundle Resources).
 */
class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let iconURLString = request.content.userInfo["notification_icon_url"] as? String
        let iconURL = iconURLString.flatMap { URL(string: $0) }

        if let iconURL {
            downloadAndAttach(iconURL: iconURL, to: content, contentHandler: contentHandler)
        } else {
            // Pas d'URL dans le payload → fallback immédiat sur logonotif
            attachBundledLogonotif(to: content)
            contentHandler(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            // Temps écoulé : essayer le fallback local avant de rendre la main
            attachBundledLogonotif(to: bestAttemptContent)
            contentHandler(bestAttemptContent)
        }
    }

    // MARK: - Private

    private func downloadAndAttach(
        iconURL: URL,
        to content: UNMutableNotificationContent,
        contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        let task = URLSession.shared.downloadTask(with: iconURL) { [weak self] tempURL, _, _ in
            defer { contentHandler(content) }

            if let tempURL, self?.attach(from: tempURL, to: content, identifier: "notification_icon") == true {
                return
            }
            // Téléchargement raté → fallback sur logonotif bundlé
            self?.attachBundledLogonotif(to: content)
        }
        task.resume()
    }

    /// Copie `tempURL` en `.png` et attache à `content`. Retourne `true` si succès.
    @discardableResult
    private func attach(from tempURL: URL, to content: UNMutableNotificationContent, identifier: String) -> Bool {
        let destURL = tempURL.deletingLastPathComponent()
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        do {
            try FileManager.default.moveItem(at: tempURL, to: destURL)
            let attachment = try UNNotificationAttachment(identifier: identifier, url: destURL, options: nil)
            content.attachments = [attachment]
            return true
        } catch {
            return false
        }
    }

    /// Attache `logonotif.png` depuis le bundle de l'extension comme icône de notification par défaut.
    private func attachBundledLogonotif(to content: UNMutableNotificationContent) {
        // Cherche dans le bundle de l'extension (copy bundle resources dans Xcode)
        guard let bundleURL = Bundle.main.url(forResource: "logonotif", withExtension: "png") else {
            return
        }
        // Copier dans un fichier temporaire avec un nom unique (UNNotificationAttachment exige un chemin inscriptible)
        let destURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        do {
            try FileManager.default.copyItem(at: bundleURL, to: destURL)
            let attachment = try UNNotificationAttachment(identifier: "notification_icon_default", url: destURL, options: nil)
            content.attachments = [attachment]
        } catch {
            // Impossible d'attacher → notification sans image, ce n'est pas bloquant
        }
    }
}
