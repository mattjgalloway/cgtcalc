@testable import CGTCalcCore
import Foundation
import XCTest

final class ModelCoverageTests: XCTestCase {
  func testInputDataComputedProperties() {
    let transaction = TestSupport.buy("01/01/2020", "TXN", 10, 1, 0)
    let event = TestSupport.dividend("02/01/2020", "EVT", 10, 5)

    let transactionData = InputData.transaction(transaction)
    let eventData = InputData.assetEvent(event)

    XCTAssertEqual(DateParser.format(transactionData.date), "01/01/2020")
    XCTAssertEqual(transactionData.asset, "TXN")
    XCTAssertEqual(DateParser.format(eventData.date), "02/01/2020")
    XCTAssertEqual(eventData.asset, "EVT")
  }

  func testInputDataCodableRoundTrip() throws {
    let original: [InputData] = [
      .transaction(TestSupport.buy("01/01/2020", "TEST", 100, 10, 5, sourceOrder: 1)),
      .assetEvent(TestSupport.capReturn("02/01/2020", "TEST", 100, 25, sourceOrder: 2))
    ]

    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode([InputData].self, from: encoded)
    XCTAssertEqual(decoded.count, 2)

    guard case .transaction(let transaction) = decoded[0] else {
      return XCTFail("Expected transaction")
    }
    XCTAssertEqual(transaction.type, .buy)
    XCTAssertEqual(transaction.asset, "TEST")

    guard case .assetEvent(let event) = decoded[1] else {
      return XCTFail("Expected asset event")
    }
    XCTAssertEqual(event.type, .capitalReturn)
    XCTAssertEqual(event.asset, "TEST")
  }

  func testInputDataDecodeUnknownTypeThrows() {
    let payload = #"{"type":"UNKNOWN","data":{}}"#.data(using: .utf8)!
    XCTAssertThrowsError(try JSONDecoder().decode(InputData.self, from: payload)) { error in
      guard case DecodingError.dataCorrupted(let context) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertTrue(context.debugDescription.contains("Unknown type"))
    }
  }

  func testSection104HoldingAverageCost() {
    XCTAssertEqual(Section104Holding().averageCost, 0)
    let holding = Section104Holding(quantity: 50, costBasis: 125, pool: [])
    XCTAssertEqual(holding.averageCost, 2.5, accuracy: 0.00001)
  }

  func testSection104MatchCostProperties() {
    let match = Section104Match(
      transactionId: UUID(),
      quantity: 25,
      cost: 100,
      date: TestSupport.date("01/01/2020"),
      poolQuantity: 80,
      poolCost: 320)
    XCTAssertEqual(match.unitCost, 4, accuracy: 0.00001)
    XCTAssertEqual(match.poolUnitCost, 4, accuracy: 0.00001)

    let zeroMatch = Section104Match(
      transactionId: UUID(),
      quantity: 0,
      cost: 0,
      date: TestSupport.date("01/01/2020"),
      poolQuantity: 0,
      poolCost: 0)
    XCTAssertEqual(zeroMatch.unitCost, 0)
    XCTAssertEqual(zeroMatch.poolUnitCost, 0)
  }

  func testBedAndBreakfastMatchRestructureMultiplier() {
    let buy = TestSupport.buy("01/01/2020", "TEST", 10, 10, 1)
    let match = BedAndBreakfastMatch(
      buyTransaction: buy,
      quantity: 10,
      buyDateQuantity: 20,
      eventAdjustment: 0,
      cost: 201)
    XCTAssertEqual(match.restructureMultiplier, 2, accuracy: 0.00001)

    let zeroQuantityMatch = BedAndBreakfastMatch(
      buyTransaction: buy,
      quantity: 0,
      buyDateQuantity: 10,
      eventAdjustment: 0,
      cost: 0)
    XCTAssertEqual(zeroQuantityMatch.restructureMultiplier, 1)
  }

  func testDisposalGainLossFlags() {
    let gainDisposal = TestSupport.disposal(date: "01/01/2020", gain: 10)
    XCTAssertTrue(gainDisposal.isGain)
    XCTAssertFalse(gainDisposal.isLoss)

    let lossDisposal = TestSupport.disposal(date: "01/01/2020", gain: -10)
    XCTAssertFalse(lossDisposal.isGain)
    XCTAssertTrue(lossDisposal.isLoss)
  }

  func testCalculationErrorDescriptions() {
    let insufficient = CalculationError.insufficientShares(
      asset: "ABC",
      date: TestSupport.date("01/01/2020"),
      requested: 10,
      matched: 3)
    XCTAssertEqual(
      insufficient.errorDescription,
      "Insufficient shares for ABC on 01/01/2020: tried to sell 10, but only 3 could be matched")

    let invalidAmount = CalculationError.invalidAssetEventAmount(
      asset: "ABC",
      date: TestSupport.date("02/01/2020"),
      type: .dividend,
      expected: 100,
      actual: 99)
    XCTAssertEqual(
      invalidAmount.errorDescription,
      "Invalid DIVIDEND amount for ABC on 02/01/2020: expected 100, got 99")
  }

  func testTaxYearSpecialRateChangeMetadata() throws {
    let specialYear = TaxYear(startYear: 2024)
    XCTAssertEqual(specialYear.specialCapitalGainsRateChangeLabel, "29th October")
    XCTAssertEqual(
      try DateParser.format(XCTUnwrap(specialYear.specialCapitalGainsRateChangeLastOldRateDate)),
      "29/10/2024")

    let normalYear = TaxYear(startYear: 2023)
    XCTAssertNil(normalYear.specialCapitalGainsRateChangeLastOldRateDate)
    XCTAssertNil(normalYear.specialCapitalGainsRateChangeLabel)
  }
}
