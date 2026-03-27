import CGTCalcCore
import Foundation
import XCTest

final class PublicAPIAssetEventTests: XCTestCase {
  private func date(_ value: String) throws -> Date {
    try DateParser.parse(value)
  }

  func testCanConstructAndInspectAssetEventsFromPublicAPI() throws {
    let split = try AssetEvent(
      type: .split,
      date: self.date("01/03/2020"),
      asset: "TEST",
      multiplier: 2)
    switch split.kind {
    case .split(let multiplier):
      XCTAssertEqual(multiplier, 2)
    default:
      XCTFail("Expected split event")
    }

    let dividend = try AssetEvent(
      type: .dividend,
      date: self.date("01/04/2020"),
      asset: "TEST",
      distributionAmount: 100,
      distributionValue: 25)
    switch dividend.kind {
    case .dividend(let amount, let value):
      XCTAssertEqual(amount, 100)
      XCTAssertEqual(value, 25)
    default:
      XCTFail("Expected dividend event")
    }
  }

  func testCanUseCoreEngineWithoutInputParser() throws {
    let transactions = try [
      Transaction(
        type: .buy,
        date: self.date("01/01/2020"),
        asset: "TEST",
        quantity: 100,
        price: 10,
        expenses: 0),
      Transaction(
        type: .sell,
        date: self.date("01/06/2020"),
        asset: "TEST",
        quantity: 100,
        price: 12,
        expenses: 0)
    ]
    let assetEvents = try [
      AssetEvent(
        type: .capitalReturn,
        date: self.date("01/03/2020"),
        asset: "TEST",
        distributionAmount: 100,
        distributionValue: 50)
    ]

    let result = try CGTEngine.calculate(transactions: transactions, assetEvents: assetEvents)
    XCTAssertEqual(result.taxYearSummaries.count, 1)
    XCTAssertEqual(result.assetEvents.count, 1)
    switch result.assetEvents[0].kind {
    case .capitalReturn(let amount, let value):
      XCTAssertEqual(amount, 100)
      XCTAssertEqual(value, 50)
    default:
      XCTFail("Expected capital return event")
    }
  }

  func testConvenienceInitializersThrowForMismatchedType() throws {
    XCTAssertThrowsError(try AssetEvent(
      type: .dividend,
      date: self.date("01/03/2020"),
      asset: "TEST",
      multiplier: 2))
    { error in
      guard case AssetEvent.InitializationError.invalidRestructureType(let type) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(type, .dividend)
    }

    XCTAssertThrowsError(try AssetEvent(
      type: .split,
      date: self.date("01/03/2020"),
      asset: "TEST",
      distributionAmount: 100,
      distributionValue: 50))
    { error in
      guard case AssetEvent.InitializationError.invalidDistributionType(let type) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(type, .split)
    }
  }
}
