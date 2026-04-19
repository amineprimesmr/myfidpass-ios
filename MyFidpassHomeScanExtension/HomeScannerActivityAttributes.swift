//
//  HomeScannerActivityAttributes.swift
//  MyFidpassHomeScanExtension
//
//  DOIT rester identique à myfidpass/LiveActivity/HomeScannerActivityAttributes.swift
//

import ActivityKit
import Foundation

struct HomeScannerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var updatedAt: Date
        public init(updatedAt: Date) {
            self.updatedAt = updatedAt
        }
    }

    public init() {}
}
