//
//  JwtAccessExpiry.swift
//  myfidpass — aligné Android JwtAccessExpiry.kt
//

import Foundation

enum JwtAccessExpiry {
    static func expirationEpochSeconds(_ jwt: String) -> TimeInterval? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        let rem = payload.count % 4
        if rem > 0 { payload += String(repeating: "=", count: 4 - rem) }
        guard let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval, exp > 0 else {
            return nil
        }
        return exp
    }

    static func stillWithinValidityWindow(_ token: String?, marginSeconds: TimeInterval = 30) -> Bool {
        guard let jwt = token?.trimmingCharacters(in: .whitespacesAndNewlines), !jwt.isEmpty,
              let exp = expirationEpochSeconds(jwt) else { return false }
        let now = Date().timeIntervalSince1970
        return exp - now > marginSeconds
    }

    static func shouldProactivelyRefresh(_ token: String?, withinSeconds: TimeInterval = 120) -> Bool {
        guard let jwt = token?.trimmingCharacters(in: .whitespacesAndNewlines), !jwt.isEmpty,
              let exp = expirationEpochSeconds(jwt) else { return false }
        let now = Date().timeIntervalSince1970
        return exp - now <= withinSeconds
    }
}
