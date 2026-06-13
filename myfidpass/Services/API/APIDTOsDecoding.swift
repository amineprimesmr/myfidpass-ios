//
//  APIDTOsDecoding.swift
//  myfidpass — helpers de décodage partagés (APIDTOs+*.swift)
//

import Foundation

/// Décode un booléen optionnel même si l’API envoie 0/1 ou une chaîne.
func decodeFlexibleOptionalBool<Key: CodingKey>(
    container: KeyedDecodingContainer<Key>,
    key: Key
) -> Bool? {
    guard container.contains(key) else { return nil }
    if let b = try? container.decode(Bool.self, forKey: key) { return b }
    if let i = try? container.decode(Int.self, forKey: key) { return i != 0 }
    if let s = try? container.decode(String.self, forKey: key) {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t == "1" || t == "true" || t == "yes"
    }
    return nil
}
