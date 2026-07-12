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
}
