//
//  JwtAccessExpiryTests.swift
//  myfidpassTests
//

import XCTest
@testable import myfidpass

final class JwtAccessExpiryTests: XCTestCase {

    private func jwt(exp: TimeInterval) -> String {
        let payload = Data("{\"exp\":\(Int(exp))}".utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "header.\(payload).sig"
    }

    func testStillWithinValidityWindow_farFuture() {
        let token = jwt(exp: 4_102_444_800)
        XCTAssertTrue(JwtAccessExpiry.stillWithinValidityWindow(token))
    }

    func testShouldProactivelyRefresh_farFuture_returnsFalse() {
        let token = jwt(exp: 4_102_444_800)
        XCTAssertFalse(JwtAccessExpiry.shouldProactivelyRefresh(token))
    }
}
