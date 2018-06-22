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
    ("testPruneImmortal", testPruneImmortal),
    ("testPruneWithMinimumCacheSize", testPruneWithMinimumCacheSize),
    ("testPruneWithMinimumCacheSizeImmortal", testPruneWithMinimumCacheSizeImmortal),
    ("testActivateDeactivate", testActivateDeactivate),
    ("testInitError", testInitError),
    ("testActivationError", testActivationError),
    ("testDeactivationError", testDeactivationError),
    ("testCacheCapacity", testCacheCapacity),
    ("testStatusReport", testStatusReport),
    ("testIsCached", testIsCached),
  ]
}


XCTMain([
  testCase(ManagedPoolTests.allTests),
])
