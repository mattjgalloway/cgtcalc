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

  func testGroupedCapitalReturn() throws {
    let a = ModelCreation.assetEvent(.CapitalReturn(10, 1), "01/01/2020", "Foo")
    let b = ModelCreation.assetEvent(.CapitalReturn(20, 2), "01/01/2020", "Foo")
    let grouped = try AssetEvent.grouped([a, b])
    XCTAssertEqual(grouped.kind, AssetEvent.Kind.CapitalReturn(30, 3))
    XCTAssertEqual(grouped.asset, "Foo")
  }

  func testGroupedDividend() throws {
    let a = ModelCreation.assetEvent(.Dividend(10, 1), "01/01/2020", "Foo")
    let b = ModelCreation.assetEvent(.Dividend(20, 2), "01/01/2020", "Foo")
    let grouped = try AssetEvent.grouped([a, b])
    XCTAssertEqual(grouped.kind, AssetEvent.Kind.Dividend(30, 3))
    XCTAssertEqual(grouped.asset, "Foo")
  }

  func testGroupedSplit() throws {
    let a = ModelCreation.assetEvent(.Split(3), "01/01/2020", "Foo")
    let b = ModelCreation.assetEvent(.Split(4), "01/01/2020", "Foo")
    let grouped = try AssetEvent.grouped([a, b])
    XCTAssertEqual(grouped.kind, AssetEvent.Kind.Split(12))
    XCTAssertEqual(grouped.asset, "Foo")
  }

  func testGroupedUnsplit() throws {
    let a = ModelCreation.assetEvent(.Unsplit(3), "01/01/2020", "Foo")
    let b = ModelCreation.assetEvent(.Unsplit(4), "01/01/2020", "Foo")
    let grouped = try AssetEvent.grouped([a, b])
    XCTAssertEqual(grouped.kind, AssetEvent.Kind.Unsplit(12))
    XCTAssertEqual(grouped.asset, "Foo")
  }

  func testGroupedMultiple() throws {
    let a = ModelCreation.assetEvent(.Dividend(10, 1), "01/01/2020", "Foo")
    let b = ModelCreation.assetEvent(.Dividend(20, 2), "01/01/2020", "Foo")
    let c = ModelCreation.assetEvent(.Dividend(30, 3), "01/01/2020", "Foo")
    let grouped = try AssetEvent.grouped([a, b, c])
    XCTAssertEqual(grouped.kind, AssetEvent.Kind.Dividend(60, 6))
    XCTAssertEqual(grouped.asset, "Foo")
  }

  func testGroupedDifferentKind() throws {
    let a = ModelCreation.assetEvent(.Dividend(10, 1), "01/01/2020", "Foo")
    let b = ModelCreation.assetEvent(.CapitalReturn(20, 2), "01/01/2020", "Foo")
    XCTAssertThrowsError(try AssetEvent.grouped([a, b]))
  }

  func testGroupedDifferentDate() throws {
    let a = ModelCreation.assetEvent(.Dividend(10, 1), "01/01/2020", "Foo")
    let b = ModelCreation.assetEvent(.Dividend(20, 2), "02/01/2020", "Foo")
    XCTAssertThrowsError(try AssetEvent.grouped([a, b]))
  }

  func testGroupedDifferentAsset() throws {
    let a = ModelCreation.assetEvent(.Dividend(10, 1), "01/01/2020", "Foo")
    let b = ModelCreation.assetEvent(.Dividend(20, 2), "01/01/2020", "Bar")
    XCTAssertThrowsError(try AssetEvent.grouped([a, b]))
  }

  func testGroupedEmptyArray() throws {
    XCTAssertThrowsError(try AssetEvent.grouped([]))
  }
}
