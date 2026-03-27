@testable import CGTCalcCore
import XCTest

/// Engine-level smoke tests. Detailed rule behavior lives in focused unit-test files.
final class CalculatorTests: XCTestCase {
  func testTransactionTotalCost() {
    let transaction = Transaction(
      type: .buy,
      date: Date(),
      asset: "TEST",
      quantity: 100,
      price: 10.0,
      expenses: 5.0)

    XCTAssertEqual(transaction.totalValue, 1000.0)
    XCTAssertEqual(transaction.totalCost, 1005.0)
    XCTAssertEqual(transaction.proceeds, 1000.0)
  }

  func testEngineOutputIsDeterministicWhenSourceOrderIsOmitted() throws {
    func makeTransactions() -> [Transaction] {
      [
        Transaction(
          type: .buy,
          date: TestSupport.date("01/01/2020"),
          asset: "TEST",
          quantity: 10,
          price: 1,
          expenses: 0),
        Transaction(
          type: .buy,
          date: TestSupport.date("01/01/2020"),
          asset: "TEST",
          quantity: 10,
          price: 2,
          expenses: 0),
        Transaction(
          type: .sell,
          date: TestSupport.date("01/01/2020"),
          asset: "TEST",
          quantity: 10,
          price: 3,
          expenses: 0)
      ]
    }

    let firstResult = try CGTEngine.calculate(transactions: makeTransactions(), assetEvents: [])
    let baseline = TextReportFormatter().format(firstResult)

    for _ in 0 ..< 20 {
      let result = try CGTEngine.calculate(transactions: makeTransactions(), assetEvents: [])
      XCTAssertEqual(TextReportFormatter().format(result), baseline)
    }
  }

  func testSection104PartialSell() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.buy("01/01/2019", "TEST", 100, 10.0, 0),
      TestSupport.sell("01/06/2019", "TEST", 25, 15.0, 0)
    ], assetEvents: [])

    let summary = result.taxYearSummaries[0]
    let disposal = summary.disposals[0]
    XCTAssertEqual(disposal.gain, 125, accuracy: 1)
  }

  func testSameDaySellsAreMergedBeforeRounding() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.sell("28/10/2018", "TEST", 10, 7, 12.5),
      TestSupport.sell("28/10/2018", "TEST", 10, 9, 2),
      TestSupport.buy("28/08/2018", "TEST", 10, 5, 12.5),
      TestSupport.buy("28/08/2018", "TEST", 10, 10, 2),
      TestSupport.buy("28/08/2018", "TEST", 10, 8, 2)
    ], assetEvents: [])

    XCTAssertEqual(result.taxYearSummaries.count, 1)
    let summary = try XCTUnwrap(result.taxYearSummaries.first)
    XCTAssertEqual(summary.disposals.count, 1)

    let disposal = try XCTUnwrap(summary.disposals.first)
    XCTAssertEqual(disposal.sellTransaction.quantity, 20)
    XCTAssertEqual(disposal.sellTransaction.price, 8, accuracy: 0.00001)
    XCTAssertEqual(disposal.sellTransaction.expenses, 14.5, accuracy: 0.00001)
    XCTAssertEqual(disposal.gain, -19, accuracy: 1)
  }

  func testBedAndBreakfast30DayRule() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.buy("01/01/2019", "TEST", 1000, 3.0, 0),
      TestSupport.sell("01/06/2019", "TEST", 500, 5.0, 0),
      TestSupport.buy("08/06/2019", "TEST", 500, 5.0, 0)
    ], assetEvents: [])

    XCTAssertEqual(result.taxYearSummaries.count, 1)
    let summary = result.taxYearSummaries[0]
    XCTAssertFalse(summary.disposals[0].bedAndBreakfastMatches.isEmpty)
  }

  func testCapitalReturnReducesSection104CostBasis() throws {
    let result = try CGTEngine.calculate(
      transactions: [
        TestSupport.buy("01/01/2019", "TEST", 100, 10.0, 0),
        TestSupport.sell("01/06/2019", "TEST", 100, 12.0, 0)
      ],
      assetEvents: [
        TestSupport.capReturn("01/03/2019", "TEST", 100, 50.0)
      ])

    let summary = try XCTUnwrap(result.taxYearSummaries.first)
    let disposal = try XCTUnwrap(summary.disposals.first)
    XCTAssertEqual(disposal.gain, 250, accuracy: 1)
  }

  func testDividendIncreasesSection104CostBasis() throws {
    let result = try CGTEngine.calculate(
      transactions: [
        TestSupport.buy("01/01/2019", "TEST", 100, 10.0, 0),
        TestSupport.sell("01/06/2019", "TEST", 100, 12.0, 0)
      ],
      assetEvents: [
        TestSupport.dividend("01/03/2019", "TEST", 100, 50.0)
      ])

    let summary = try XCTUnwrap(result.taxYearSummaries.first)
    let disposal = try XCTUnwrap(summary.disposals.first)
    XCTAssertEqual(disposal.gain, 150, accuracy: 1)
  }

  func testInvalidAssetEventAmountThrows() {
    XCTAssertThrowsError(try CGTEngine.calculate(
      transactions: [
        TestSupport.buy("01/01/2019", "TEST", 100, 10.0, 0)
      ],
      assetEvents: [
        TestSupport.capReturn("01/03/2019", "TEST", 99, 50.0)
      ])) { error in
        guard case CalculationError
          .invalidAssetEventAmount(let asset, let date, let type, let expected, let actual) = error
        else {
          return XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(asset, "TEST")
        XCTAssertEqual(DateParser.format(date), "01/03/2019")
        XCTAssertEqual(type, .capitalReturn)
        XCTAssertEqual(expected, 100)
        XCTAssertEqual(actual, 99)
      }
  }

  func testSellWithoutPriorBuyThrows() {
    XCTAssertThrowsError(try CGTEngine.calculate(
      transactions: [TestSupport.sell("01/06/2019", "TEST", 50, 15.0, 0)],
      assetEvents: []))
    { error in
      guard case CalculationError.insufficientShares(let asset, let date, let requested, let matched) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(asset, "TEST")
      XCTAssertEqual(DateParser.format(date), "01/06/2019")
      XCTAssertEqual(requested, 50)
      XCTAssertEqual(matched, 0)
    }
  }

  func testUnsupportedLaterAcquisitionFallbackThrowsSpecificError() {
    XCTAssertThrowsError(try CGTEngine.calculate(
      transactions: [
        TestSupport.sell("01/01/2020", "TEST", 10, 10, 0),
        TestSupport.buy("15/02/2020", "TEST", 10, 3, 0)
      ],
      assetEvents: []))
    { error in
      guard case CalculationError.unsupportedLaterAcquisitionIdentification(
        let asset,
        let date,
        let requested,
        let matched,
        let firstLaterAcquisitionDate) = error
      else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(asset, "TEST")
      XCTAssertEqual(DateParser.format(date), "01/01/2020")
      XCTAssertEqual(requested, 10)
      XCTAssertEqual(matched, 0)
      XCTAssertEqual(DateParser.format(firstLaterAcquisitionDate), "15/02/2020")
    }
  }

  func testPre2008InputDateThrowsUnsupportedScopeError() {
    XCTAssertThrowsError(try CGTEngine.calculate(
      transactions: [
        TestSupport.buy("01/01/2007", "TEST", 100, 1, 0),
        TestSupport.sell("01/06/2020", "TEST", 100, 2, 0)
      ],
      assetEvents: []))
    { error in
      guard case CalculationError.unsupportedInputDate(let date, let minimumDate) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(DateParser.format(date), "01/01/2007")
      XCTAssertEqual(DateParser.format(minimumDate), "06/04/2008")
    }
  }

  func testExampleFromReadme() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.buy("05/12/2019", "GB00B41YBW71", 500, 4.7012, 2),
      TestSupport.sell("28/11/2019", "GB00B41YBW71", 2000, 4.6702, 12.5),
      TestSupport.buy("28/08/2018", "GB00B41YBW71", 1000, 4.1565, 12.5),
      TestSupport.buy("01/03/2018", "GB00B41YBW71", 1000, 3.6093, 2)
    ], assetEvents: [])

    XCTAssertEqual(result.taxYearSummaries.count, 1)
    let summary = result.taxYearSummaries[0]
    XCTAssertEqual(summary.totalGain, 1140, accuracy: 1)
    XCTAssertEqual(summary.taxableGain, 0)
    XCTAssertFalse(summary.disposals[0].bedAndBreakfastMatches.isEmpty)
  }

  func testPartialRebuyCanBeSharedAcrossEarlierDisposals() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.sell("18/08/2016", "NASDAQ:META", 107, 94.26, 7.02),
      TestSupport.buy("15/08/2016", "NASDAQ:META", 107, 96.28, 0),
      TestSupport.sell("29/07/2016", "NASDAQ:META", 106, 94.71, 6.99),
      TestSupport.buy("15/05/2016", "NASDAQ:META", 106, 82.47, 0)
    ], assetEvents: [])

    let summary = try XCTUnwrap(result.taxYearSummaries.first)
    XCTAssertEqual(summary.disposals.count, 2)
    XCTAssertEqual(summary.disposals[0].gain, -174, accuracy: 1)
    XCTAssertEqual(summary.disposals[1].gain, 1240, accuracy: 1)
  }

  func testSameDayAcquisitionUsesAggregatedCostForPartialDisposal() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.buy("01/01/2020", "TEST", 10, 1, 100),
      TestSupport.buy("01/01/2020", "TEST", 10, 100, 0),
      TestSupport.sell("01/01/2020", "TEST", 10, 100, 0)
    ], assetEvents: [])

    let summary = try XCTUnwrap(result.taxYearSummaries.first)
    let disposal = try XCTUnwrap(summary.disposals.first)
    XCTAssertEqual(disposal.gain, 445, accuracy: 1)

    let holding = try XCTUnwrap(result.holdings["TEST"])
    XCTAssertEqual(holding.quantity, 10, accuracy: 0.00001)
    XCTAssertEqual(holding.costBasis, 555, accuracy: 0.00001)
  }

  func testFinalHoldingsIncludeAssetsWithoutDisposals() throws {
    let result = try CGTEngine.calculate(
      transactions: [TestSupport.buy("01/01/2020", "KEEP", 20, 5, 1)],
      assetEvents: [TestSupport.dividend("15/01/2020", "KEEP", 20, 10)])

    XCTAssertTrue(result.taxYearSummaries.isEmpty)
    let holding = try XCTUnwrap(result.holdings["KEEP"])
    XCTAssertEqual(holding.quantity, 20, accuracy: 0.00001)
    XCTAssertEqual(holding.costBasis, 111, accuracy: 0.00001)
  }

  func testFinalHoldingsIncludeUnmatchedSameDayBuysOnLastDisposalDate() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.buy("01/01/2020", "TEST", 100, 1, 0),
      TestSupport.sell("10/01/2020", "TEST", 70, 2, 0),
      TestSupport.buy("20/01/2020", "TEST", 80, 1.5, 0),
      TestSupport.sell("20/01/2020", "TEST", 50, 3, 0)
    ], assetEvents: [])

    let holding = try XCTUnwrap(result.holdings["TEST"])
    XCTAssertEqual(holding.quantity, 60, accuracy: 0.00001)
    XCTAssertEqual(holding.costBasis, 60, accuracy: 0.00001)
  }

  func testSpouseOutUsesSection104CostBasisAndDoesNotCreateDisposal() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.buy("01/01/2020", "TEST", 100, 10, 0),
      TestSupport.spouseOut("01/02/2020", "TEST", 40)
    ], assetEvents: [])

    XCTAssertTrue(result.taxYearSummaries.isEmpty)
    XCTAssertEqual(result.spouseTransfersOut.count, 1)
    XCTAssertEqual(result.spouseTransfersOut[0].transaction.quantity, 40, accuracy: 0.00001)
    XCTAssertEqual(result.spouseTransfersOut[0].costBasis, 400, accuracy: 0.00001)
    XCTAssertEqual(result.spouseTransfersOut[0].averageCost, 10, accuracy: 0.00001)

    let holding = try XCTUnwrap(result.holdings["TEST"])
    XCTAssertEqual(holding.quantity, 60, accuracy: 0.00001)
    XCTAssertEqual(holding.costBasis, 600, accuracy: 0.00001)
  }

  func testSpouseInAddsToPoolForFutureDisposalMatching() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.buy("01/01/2020", "TEST", 100, 10, 0),
      TestSupport.spouseOut("01/02/2020", "TEST", 40),
      TestSupport.spouseIn("01/03/2020", "TEST", 20, 10),
      TestSupport.sell("01/04/2020", "TEST", 30, 12, 0)
    ], assetEvents: [])

    let summary = try XCTUnwrap(result.taxYearSummaries.first)
    let disposal = try XCTUnwrap(summary.disposals.first)
    XCTAssertEqual(disposal.gain, 60, accuracy: 1)

    let holding = try XCTUnwrap(result.holdings["TEST"])
    XCTAssertEqual(holding.quantity, 50, accuracy: 0.00001)
    XCTAssertEqual(holding.costBasis, 500, accuracy: 0.00001)
  }

  func testSpouseOutUsesSameDayAcquisitionPriorityBeforeSection104Pool() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.buy("01/01/2020", "TEST", 100, 1, 0),
      TestSupport.buy("01/02/2020", "TEST", 10, 100, 0),
      TestSupport.spouseOut("01/02/2020", "TEST", 10)
    ], assetEvents: [])

    XCTAssertEqual(result.spouseTransfersOut.count, 1)
    XCTAssertEqual(result.spouseTransfersOut[0].costBasis, 1000, accuracy: 0.00001)
    XCTAssertEqual(result.spouseTransfersOut[0].averageCost, 100, accuracy: 0.00001)

    let holding = try XCTUnwrap(result.holdings["TEST"])
    XCTAssertEqual(holding.quantity, 100, accuracy: 0.00001)
    XCTAssertEqual(holding.costBasis, 100, accuracy: 0.00001)
  }

  func testSpouseOutUsesThirtyDayAcquisitionPriorityBeforeSection104Pool() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.buy("01/01/2020", "TEST", 100, 1, 0),
      TestSupport.spouseOut("01/02/2020", "TEST", 40),
      TestSupport.buy("15/02/2020", "TEST", 40, 100, 0)
    ], assetEvents: [])

    XCTAssertEqual(result.spouseTransfersOut.count, 1)
    XCTAssertEqual(result.spouseTransfersOut[0].costBasis, 4000, accuracy: 0.00001)
    XCTAssertEqual(result.spouseTransfersOut[0].averageCost, 100, accuracy: 0.00001)

    let holding = try XCTUnwrap(result.holdings["TEST"])
    XCTAssertEqual(holding.quantity, 100, accuracy: 0.00001)
    XCTAssertEqual(holding.costBasis, 100, accuracy: 0.00001)
  }

  func testSpouseOutRespectsFutureBuyReservedForLaterSameDaySell() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.buy("01/01/2020", "TEST", 100, 1, 0),
      TestSupport.spouseOut("10/01/2020", "TEST", 70),
      TestSupport.buy("20/01/2020", "TEST", 60, 1.5, 0),
      TestSupport.sell("20/01/2020", "TEST", 50, 3, 0)
    ], assetEvents: [])

    XCTAssertEqual(result.spouseTransfersOut.count, 1)
    XCTAssertEqual(result.spouseTransfersOut[0].costBasis, 75, accuracy: 0.00001)
    XCTAssertEqual(result.spouseTransfersOut[0].averageCost, 75.0 / 70.0, accuracy: 0.00001)

    let summary = try XCTUnwrap(result.taxYearSummaries.first)
    let disposal = try XCTUnwrap(summary.disposals.first)
    XCTAssertEqual(disposal.gain, 75, accuracy: 1)
    XCTAssertEqual(disposal.bedAndBreakfastMatches.count, 1)
    XCTAssertEqual(disposal.bedAndBreakfastMatches[0].buyDateQuantity, 50, accuracy: 0.00001)

    let holding = try XCTUnwrap(result.holdings["TEST"])
    XCTAssertEqual(holding.quantity, 40, accuracy: 0.00001)
    XCTAssertEqual(holding.costBasis, 40, accuracy: 0.00001)
  }

  func testSameDaySellAndSpouseOutUseCombinedIdentificationRegardlessOfSourceOrder() throws {
    let sellFirstResult = try CGTEngine.calculate(transactions: [
      TestSupport.buy("01/01/2020", "TEST", 100, 1, 0),
      TestSupport.buy("01/02/2020", "TEST", 100, 10, 0),
      TestSupport.sell("01/02/2020", "TEST", 100, 20, 0),
      TestSupport.spouseOut("01/02/2020", "TEST", 100)
    ], assetEvents: [])

    let spouseFirstResult = try CGTEngine.calculate(transactions: [
      TestSupport.buy("01/01/2020", "TEST", 100, 1, 0),
      TestSupport.buy("01/02/2020", "TEST", 100, 10, 0),
      TestSupport.spouseOut("01/02/2020", "TEST", 100),
      TestSupport.sell("01/02/2020", "TEST", 100, 20, 0)
    ], assetEvents: [])

    let sellFirstSummary = try XCTUnwrap(sellFirstResult.taxYearSummaries.first)
    let spouseFirstSummary = try XCTUnwrap(spouseFirstResult.taxYearSummaries.first)
    let sellFirstDisposal = try XCTUnwrap(sellFirstSummary.disposals.first)
    let spouseFirstDisposal = try XCTUnwrap(spouseFirstSummary.disposals.first)

    XCTAssertEqual(sellFirstDisposal.gain, spouseFirstDisposal.gain, accuracy: 0.00001)
    XCTAssertEqual(sellFirstDisposal.gain, 1450, accuracy: 0.00001)

    let sellFirstTransfer = try XCTUnwrap(sellFirstResult.spouseTransfersOut.first)
    let spouseFirstTransfer = try XCTUnwrap(spouseFirstResult.spouseTransfersOut.first)
    XCTAssertEqual(sellFirstTransfer.costBasis, spouseFirstTransfer.costBasis, accuracy: 0.00001)
    XCTAssertEqual(sellFirstTransfer.costBasis, 550, accuracy: 0.00001)
    XCTAssertEqual(sellFirstTransfer.averageCost, 5.5, accuracy: 0.00001)

    let sellFirstHolding = try XCTUnwrap(sellFirstResult.holdings["TEST"])
    let spouseFirstHolding = try XCTUnwrap(spouseFirstResult.holdings["TEST"])
    XCTAssertEqual(sellFirstHolding.quantity, 0, accuracy: 0.00001)
    XCTAssertEqual(spouseFirstHolding.quantity, 0, accuracy: 0.00001)
    XCTAssertEqual(sellFirstHolding.costBasis, 0, accuracy: 0.00001)
    XCTAssertEqual(spouseFirstHolding.costBasis, 0, accuracy: 0.00001)
  }

  func testPostBuyDividendIsNotDoubleCountedAcrossThirtyDayAndLaterSection104Disposals() throws {
    let result = try CGTEngine.calculate(transactions: [
      TestSupport.buy("01/01/2020", "TEST", 100, 10, 0),
      TestSupport.sell("01/06/2020", "TEST", 50, 20, 0),
      TestSupport.buy("10/06/2020", "TEST", 50, 12, 0),
      TestSupport.sell("20/06/2020", "TEST", 50, 25, 0)
    ], assetEvents: [
      TestSupport.dividend("30/06/2020", "TEST", 50, 100)
    ])

    let summary = try XCTUnwrap(result.taxYearSummaries.first)
    XCTAssertEqual(summary.disposals.count, 2)
    XCTAssertEqual(summary.disposals[0].gain, 400, accuracy: 1)
    XCTAssertEqual(summary.disposals[1].gain, 750, accuracy: 1)

    let holding = try XCTUnwrap(result.holdings["TEST"])
    XCTAssertEqual(holding.quantity, 50, accuracy: 0.00001)
    XCTAssertEqual(holding.costBasis, 600, accuracy: 0.00001)
  }
}
