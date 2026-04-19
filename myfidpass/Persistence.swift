//
//  Persistence.swift
//  myfidpass
//
//  Core Data : chargement du store. **Aucun** observateur global sur `NSManagedObjectContextDidSave` :
//  les fusions via `mergeChanges(fromRemoteContextSave:)` + notifications concurrentes au `viewContext.save()`
//  étaient une piste majeure pour les crashs malloc (`freed pointer was not the last allocation`).
//  La sync utilise un contexte **enfant** (`parent = viewContext`) — pas de merge manuel nécessaire.
//

import CoreData
import os.log

private let persistenceLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "myfidpass", category: "CoreData")

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        let business = Business(context: viewContext)
        business.id = UUID()
        business.name = "Café Fidelity"
        business.email = "contact@cafe.fr"
        business.createdAt = Date()
        business.updatedAt = Date()
        let template = CardTemplate(context: viewContext)
        template.id = UUID()
        template.business = business
        template.displayName = "Carte Café"
        template.requiredStamps = 10
        template.primaryColorHex = AppTheme.WalletCardAppearanceDefaults.backgroundHex
        template.accentColorHex = AppTheme.WalletCardAppearanceDefaults.bodyTextHex
        template.createdAt = Date()
        template.updatedAt = Date()
        do {
            try viewContext.save()
        } catch {
            persistenceLog.error("Preview Core Data save failed: \(String(describing: error))")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let loaded = Self.makeLoadedContainer(inMemory: inMemory)
        container = loaded
        loaded.viewContext.automaticallyMergesChangesFromParent = true
        loaded.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        loaded.viewContext.shouldDeleteInaccessibleFaults = true
    }

    /// Crée un conteneur dont les magasins sont chargés. Après reset disque (!DEBUG), on **recrée** une nouvelle
    /// instance `NSPersistentContainer` : recharger sur un conteneur déjà en échec est indéfini.
    private static func makeLoadedContainer(inMemory: Bool) -> NSPersistentContainer {
        func configureURL(_ c: NSPersistentContainer) {
            if inMemory {
                c.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
            }
        }

        func loadAndReturnError(_ c: NSPersistentContainer) -> NSError? {
            var captured: NSError?
            c.loadPersistentStores { _, error in
                if let e = error as NSError? { captured = e }
            }
            return captured
        }

        let first = NSPersistentContainer(name: "myfidpass")
        configureURL(first)
        if let error = loadAndReturnError(first) {
            persistenceLog.error("Core Data load error domain=\(error.domain, privacy: .public) code=\(error.code) \(error.localizedDescription, privacy: .public)")

            #if DEBUG
            fatalError("Unresolved error \(error), \(error.userInfo)")
            #else
            if !inMemory,
               isRecoverableMigrationOrStoreLayoutError(error),
               let url = first.persistentStoreDescriptions.first?.url {
                persistenceLog.warning("One-time Core Data store reset after migration failure (local data only)")
                removeSQLiteStoreFiles(at: url)
                let second = NSPersistentContainer(name: "myfidpass")
                configureURL(second)
                if let secondErr = loadAndReturnError(second) {
                    fatalError("Unresolved error after store reset \(secondErr), \(secondErr.userInfo)")
                }
                return second
            }
            fatalError("Unresolved error \(error), \(error.userInfo)")
            #endif
        }
        return first
    }

    /// Erreurs Core Data liées à un modèle / migration : en production, on tente **une** reconstruction du store
    /// (perte données **locales** uniquement) plutôt qu’un plantage au lancement pour tous les utilisateurs.
    private static func isRecoverableMigrationOrStoreLayoutError(_ error: NSError) -> Bool {
        guard error.domain == NSCocoaErrorDomain else { return false }
        switch error.code {
        case NSMigrationError,
             NSMigrationMissingSourceModelError,
             NSMigrationCancelledError,
             NSPersistentStoreIncompatibleVersionHashError:
            return true
        default:
            return false
        }
    }

    /// Supprime le fichier store SQLite et ses compagnons `-wal` / `-shm` si présents.
    private static func removeSQLiteStoreFiles(at storeURL: URL) {
        let path = storeURL.path
        let companionSuffixes = ["", "-shm", "-wal", "-journal"]
        for suffix in companionSuffixes {
            let p = suffix.isEmpty ? path : path + suffix
            if FileManager.default.fileExists(atPath: p) {
                do {
                    try FileManager.default.removeItem(atPath: p)
                    persistenceLog.warning("Removed Core Data file at path suffix …\(suffix, privacy: .public)")
                } catch {
                    persistenceLog.error("Failed to remove \(p, privacy: .public): \(String(describing: error))")
                }
            }
        }
    }
}
