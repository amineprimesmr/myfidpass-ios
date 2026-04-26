//
//  CommerceFlyerLiveSnapshot.swift
//  myfidpass
//
//  Même trio que l’onglet Commerce (`commerceFlyerBootstrapPreviewB64` + fond + partage) pour
//  initialiser l’éditeur **sans** attendre un second GET — aligné sur ce que l’utilisateur vient
//  de voir sur la fiche Commerce.
//

import Foundation

struct CommerceFlyerLiveSnapshot: Equatable {
    var bootstrapPreviewB64: String?
    var customBgDataURL: String?
    var shareURL: String?

    var hasBootstrap: Bool {
        let t = (bootstrapPreviewB64 ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty
    }
}
