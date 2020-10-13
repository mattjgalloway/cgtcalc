//
//  AssetEventTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 20/06/2020.
//

@testable import CGTCalcCore
import XCTest

class AssetEventTests: XCTestCase {
  func testEquality() throws {
    let a = ModelCreation.assetEvent(.Dividend(Decimal(1), Decimal(1)), "01/01/2020", "Foo")
    let b = ModelCreation.assetEvent(.Dividend(Decimal(1), Decimal(1)), "01/01/2020", "Foo")
    let c = a
    XCTAssertNotEqual(a, b)
    XCTAssertNotEqual(b, c)
    XCTAssertEqual(a, c)
  }

  func testHashable() throws {
    let a = ModelCreation.assetEvent(.Dividend(Decimal(1), Decimal(1)), "01/01/2020", "Foo")
    let b = ModelCreation.assetEvent(.Dividend(Decimal(1), Decimal(1)), "01/01/2020", "Foo")
    let c = a
    let set = Set<AssetEvent>([a, b, c])
    XCTAssertEqual(set.count, 2)
    XCTAssertTrue(set.contains(a))
    XCTAssertTrue(set.contains(b))
  }
}
