// Generated using Sourcery 0.13.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import XCTest
@testable import ManagedPoolTests

extension ManagedPoolTests {
  static var allTests = [
    ("testBasicUsage", testBasicUsage),
    ("testTimeout", testTimeout),
    ("testCheckInNotOK ", testCheckInNotOK ),
    ("testPrune", testPrune),
    ("testCacheCapacity", testCacheCapacity),
    ("testStatusReport", testStatusReport),
  ]
}


XCTMain([
  testCase(ManagedPoolTests.allTests),
])
