import CryptoKit
import MobileCoreServices
import UniformTypeIdentifiers
import UserNotifications
import os.log

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
 *
 * ANTI-CACHE : après un changement d'icône côté commerçant, l'app backend bumpe `notification_icon_updated_at`
 * et place l'URL `…/notification-icon?v=<ts>~<batchId>` dans le payload APNs. Le `batchId` est UUID unique par envoi,
 * donc deux pushs successifs n'utilisent jamais exactement la même URL.
 *
 * **PROTECTION ADDITIONNELLE** : on force le bypass total du URLCache + on ajoute un nonce local
 * (`nse-nonce=<uuid>`) au query string pour GARANTIR que même un réseau défaillant, un proxy iOS ou
 * un Foundation-level cache ne puissent jamais servir une image obsolète. Ceci couvre le bug où, après
 * changement d'image de notification, les clients voyaient encore l'ancienne image.
 */
class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    /// Session dédiée avec URLCache nil + cache policy reload-ignoring — évite tout partage d'état avec `URLSession.shared`.
    private lazy var freshSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpAdditionalHeaders = [
            "Cache-Control": "no-cache, no-store",
            "Pragma": "no-cache",
        ]
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        return URLSession(configuration: config)
    }()

    private let log = OSLog(subsystem: "com.myfidpass.nse", category: "icon")

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

        // Purge toute attachment préexistante pour ne laisser aucune trace d'état précédent.
        content.attachments = []

        if let iconURL {
            let bustedURL = addUniqueNonce(to: iconURL)
            os_log("[NSE] Téléchargement icône notif %{public}@", log: log, type: .info, bustedURL.absoluteString)
            downloadAndAttach(iconURL: bustedURL, to: content, contentHandler: contentHandler)
        } else {
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

    /// Ajoute `nse-nonce=<UUID>` à l'URL pour garantir l'unicité côté client — même si APNs ou Foundation
    /// réutilisait un cache interne, aucune réponse antérieure ne peut matcher cette URL.
    private func addUniqueNonce(to url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = comps.queryItems ?? []
        items.append(URLQueryItem(name: "nse-nonce", value: UUID().uuidString))
        comps.queryItems = items
        return comps.url ?? url
    }

    private func downloadAndAttach(
        iconURL: URL,
        to content: UNMutableNotificationContent,
        contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        var req = URLRequest(url: iconURL)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        req.setValue("no-cache", forHTTPHeaderField: "Pragma")

        let task = freshSession.downloadTask(with: req) { [weak self] tempURL, response, error in
            defer { contentHandler(content) }
            guard let self else { return }

            if let error {
                os_log("[NSE] Échec téléchargement icône : %{public}@", log: self.log, type: .error, error.localizedDescription)
            } else if let httpResp = response as? HTTPURLResponse {
                // Log SHA256 court des octets téléchargés pour comparer d'un push à l'autre.
                // Si deux pushs consécutifs renvoient le même hash → serveur, sinon → côté client.
                var hashPreview = "-"
                var byteCount: Int64 = 0
                if let tempURL, let data = try? Data(contentsOf: tempURL) {
                    byteCount = Int64(data.count)
                    let digest = SHA256.hash(data: data)
                    hashPreview = digest.prefix(6).map { String(format: "%02x", $0) }.joined()
                }
                os_log("[NSE] Réponse HTTP %{public}d — bytes=%{public}lld sha256[0..6]=%{public}@",
                       log: self.log, type: .info,
                       httpResp.statusCode, byteCount, hashPreview)
            }

            // Identifier unique : évite qu'iOS dédoublonne/cacher l'attachement par identifier constant.
            // `UNNotificationAttachment` garde le fichier à la même URL sandbox si l'identifier est réutilisé
            // sur un push « collabsable » ; un UUID frais force iOS à traiter chaque attachement comme nouveau.
            let uniqueId = "notif-icon-\(UUID().uuidString)"
            if let tempURL, self.attach(from: tempURL, to: content, identifier: uniqueId) == true {
                return
            }
            self.attachBundledLogonotif(to: content)
        }
        task.resume()
    }

    /// Copie `tempURL` en `.png` et attache à `content`. Retourne `true` si succès.
    @discardableResult
    private func attach(from tempURL: URL, to content: UNMutableNotificationContent, identifier: String) -> Bool {
        // Destination : dossier temp système avec nom UUID + .png — iOS copie le fichier dans la sandbox
        // de la notification. On met une extension explicite et un type hint pour éviter toute heuristique.
        let destURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        do {
            try FileManager.default.moveItem(at: tempURL, to: destURL)
            let options: [String: Any] = [
                UNNotificationAttachmentOptionsTypeHintKey: UTType.png.identifier,
                UNNotificationAttachmentOptionsThumbnailHiddenKey: false,
            ]
            let attachment = try UNNotificationAttachment(identifier: identifier, url: destURL, options: options)
            content.attachments = [attachment]
            return true
        } catch {
            os_log("[NSE] Attach fichier attachment échoué : %{public}@", log: log, type: .error, error.localizedDescription)
            return false
        }
    }

    /// Attache `logonotif.png` depuis le bundle de l'extension comme icône de notification par défaut.
    private func attachBundledLogonotif(to content: UNMutableNotificationContent) {
        guard let bundleURL = Bundle.main.url(forResource: "logonotif", withExtension: "png") else {
            return
        }
        let destURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        do {
            try FileManager.default.copyItem(at: bundleURL, to: destURL)
            let options: [String: Any] = [
                UNNotificationAttachmentOptionsTypeHintKey: UTType.png.identifier,
                UNNotificationAttachmentOptionsThumbnailHiddenKey: false,
            ]
            // Identifier unique ici aussi : évite tout partage de cache entre fallback et icône custom.
            let uniqueId = "notif-icon-default-\(UUID().uuidString)"
            let attachment = try UNNotificationAttachment(identifier: uniqueId, url: destURL, options: options)
            content.attachments = [attachment]
        } catch {
            // Impossible d'attacher → notification sans image (non bloquant).
        }
    }
}
