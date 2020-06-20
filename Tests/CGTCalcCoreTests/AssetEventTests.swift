//
//  AssetEventTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 20/06/2020.
//

import XCTest
@testable import CGTCalcCore

class AssetEventTests: XCTestCase {

  func testEquality() throws {
    let a = ModelCreation.assetEvent(.Dividend(Decimal(1), Decimal(1)), "01/01/2020", "Foo")
    let b = ModelCreation.assetEvent(.Dividend(Decimal(1), Decimal(1)), "01/01/2020", "Foo")
    let c = a
    XCTAssertNotEqual(a, b)
    XCTAssertNotEqual(b, c)
    XCTAssertEqual(a, c)
  }

}
