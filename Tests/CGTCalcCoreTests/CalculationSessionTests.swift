@testable import CGTCalcCore
import XCTest

final class CalculationSessionTests: XCTestCase {
  func testKeepsAssetLedgersIsolated() throws {
    var session = CalculationSession(
      transactions: [
        TestSupport.buy("01/01/2020", "AAA", 100, 10, 0),
        TestSupport.sell("01/06/2020", "AAA", 40, 20, 0),
        TestSupport.buy("01/01/2020", "BBB", 50, 5, 0)
      ],
      calculationEvents: [])

    let output = try session.run()

    XCTAssertEqual(output.disposals.count, 1)
    XCTAssertEqual(output.disposals.first?.sellTransaction.asset, "AAA")
    XCTAssertEqual(output.holdings["AAA"]?.quantity, 60)
    XCTAssertEqual(output.holdings["AAA"]?.costBasis, 600)
    XCTAssertEqual(output.holdings["BBB"]?.quantity, 50)
    XCTAssertEqual(output.holdings["BBB"]?.costBasis, 250)
  }

  func testOwnsMatchedEventAllocationAndFinalHoldingTransition() throws {
    var session = CalculationSession(
      transactions: [
        TestSupport.buy("01/01/2020", "TEST", 100, 10, 0),
        TestSupport.sell("01/06/2020", "TEST", 50, 20, 0),
        TestSupport.buy("10/06/2020", "TEST", 50, 12, 0)
      ],
      calculationEvents: [TestSupport.dividend("30/06/2020", "TEST", 50, 100)])

    let output = try session.run()
    let disposal = try XCTUnwrap(output.disposals.first)
    let match = try XCTUnwrap(disposal.bedAndBreakfastMatches.first)

    XCTAssertEqual(match.cost, 700)
    XCTAssertEqual(match.eventAdjustment, 100)
    XCTAssertEqual(disposal.rawGain, 300)
    XCTAssertEqual(output.holdings["TEST"]?.quantity, 100)
    XCTAssertEqual(output.holdings["TEST"]?.costBasis, 1000)
  }

  func testProducesSpouseTransferAndUpdatesSameAssetLedgerTogether() throws {
    var session = CalculationSession(
      transactions: [
        TestSupport.buy("01/01/2020", "TEST", 100, 10, 0),
        TestSupport.spouseOut("01/06/2020", "TEST", 40)
      ],
      calculationEvents: [])

    let output = try session.run()

    XCTAssertTrue(output.disposals.isEmpty)
    XCTAssertEqual(output.spouseTransfersOut.first?.costBasis, 400)
    XCTAssertEqual(output.holdings["TEST"]?.quantity, 60)
    XCTAssertEqual(output.holdings["TEST"]?.costBasis, 600)
  }

  func testReconcilesReciprocalRestructureDustWhenFullyConsumingPool() throws {
    let result = try CGTEngine.calculate(
      transactions: [
        TestSupport.buy("01/01/2020", "TEST", 7, 10, 0),
        TestSupport.sell("01/07/2020", "TEST", 7, 12, 0)
      ],
      assetEvents: [
        AssetEvent(date: TestSupport.date("01/03/2020"), asset: "TEST", oldUnits: 3, newUnits: 10),
        AssetEvent(date: TestSupport.date("01/05/2020"), asset: "TEST", oldUnits: 10, newUnits: 3)
      ])

    let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)

    XCTAssertEqual(disposal.section104Matches.reduce(0) { $0 + $1.quantity }, 7)
    XCTAssertEqual(disposal.rawAllowableCosts, 70)
    XCTAssertEqual(disposal.gain, 14)
    XCTAssertEqual(result.holdings["TEST"]?.quantity, 0)
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 0)
  }

  func testDoesNotReconcileQuantityOutsideArithmeticDustTolerance() throws {
    XCTAssertThrowsError(try CGTEngine.calculate(
      transactions: [
        TestSupport.buy("01/01/2020", "TEST", 7, 10, 0),
        TestSupport.sell("01/07/2020", "TEST", XCTUnwrap(Decimal.parse("7.00000002")), 12, 0)
      ],
      assetEvents: []))
    { error in
      guard case CalculationError.insufficientShares = error else {
        return XCTFail("Unexpected error: \(error)")
      }
    }
  }

  func testToleranceSizedSaleFromEmptyPoolIsRejected() throws {
    let quantity = try XCTUnwrap(Decimal.parse("0.00000001"))

    XCTAssertThrowsError(try CGTEngine.calculate(
      transactions: [TestSupport.sell("01/07/2020", "TEST", quantity, 12, 0)],
      assetEvents: []))
    { error in
      guard case CalculationError.insufficientShares = error else {
        return XCTFail("Unexpected error: \(error)")
      }
    }
  }

  func testReconcilesSplitAcquisitionRoundingFixture() throws {
    let input = try InputParser.parse(content: """
    BUY 09/02/2025 GB00B41YBW71 20 3.37 0
    BUY 09/02/2025 GB00B41YBW71 52 3.24 0
    SELL 10/02/2026 GB00B41YBW71 72 9.56 0
    BUY 18/02/2026 GB00B41YBW71 22 3.21 0
    BUY 18/02/2026 GB00B41YBW71 57 3.74 0
    SELL 25/02/2026 GB00B41YBW71 79 6.25 0
    """)

    let result = try CGTEngine.calculate(inputData: input)

    XCTAssertEqual(result.taxYearSummaries.first?.disposals.count, 2)
    XCTAssertEqual(result.holdings["GB00B41YBW71"]?.quantity, 0)
    XCTAssertEqual(result.holdings["GB00B41YBW71"]?.costBasis, 0)
  }
}
