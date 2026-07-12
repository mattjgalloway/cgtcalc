@testable import CGTCalcCore
import XCTest

/// Engine-level smoke tests. Detailed rule behavior lives in focused unit-test files.
final class CalculatorTests: XCTestCase {
  func testSameDateDividendUpliftPrecedesCapitalReturnRegardlessOfInputOrder() throws {
    let prefix = """
    BUY 01/01/2020 TEST 100 10 0
    DIVIDEND 30/06/2020 TEST 100 0
    BUY 01/07/2020 TEST 100 1 0
    """
    let eventRows = [
      "DIVIDEND 31/12/2020 TEST 200 100",
      "CAPRETURN 31/12/2020 TEST 100 150"
    ]

    for rows in [eventRows, Array(eventRows.reversed())] {
      let input = try InputParser.parse(content: prefix + "\n" + rows.joined(separator: "\n"))
      let result = try CGTEngine.calculate(inputData: input)

      XCTAssertEqual(result.holdings["TEST"]?.quantity, 200)
      XCTAssertEqual(result.holdings["TEST"]?.costBasis, 1050)
    }
  }

  func testSameDateDividendUpliftPrecedesCapitalReturnForMatchedRebuyRegardlessOfInputOrder() throws {
    let prefix = """
    BUY 01/01/2020 TEST 100 10 0
    SELL 01/06/2020 TEST 100 20 0
    BUY 10/06/2020 TEST 100 1 0
    """
    let eventRows = [
      "DIVIDEND 31/12/2020 TEST 100 100",
      "CAPRETURN 31/12/2020 TEST 100 150"
    ]

    for rows in [eventRows, Array(eventRows.reversed())] {
      let input = try InputParser.parse(content: prefix + "\n" + rows.joined(separator: "\n"))
      let result = try CGTEngine.calculate(inputData: input)
      let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)

      XCTAssertEqual(disposal.rawAllowableCosts, 50)
      XCTAssertEqual(disposal.rawGain, 1950)
      XCTAssertEqual(result.holdings["TEST"]?.quantity, 100)
      XCTAssertEqual(result.holdings["TEST"]?.costBasis, 1000)
    }
  }

  func testSameDateTransactionPermutationsProduceIdenticalEconomics() throws {
    let rows = [
      "BUY 01/06/2020 TEST 30 2 3",
      "BUY 01/06/2020 TEST 70 4 7",
      "SELL 01/06/2020 TEST 50 10 0",
      "SPOUSEOUT 01/06/2020 TEST 10"
    ]

    for permutation in self.permutations(of: rows) {
      let input = try InputParser.parse(content: permutation.joined(separator: "\n"))
      let result = try CGTEngine.calculate(inputData: input)
      let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)
      let spouseTransfer = try XCTUnwrap(result.spouseTransfersOut.first)

      XCTAssertEqual(disposal.rawProceeds, 500)
      XCTAssertEqual(disposal.rawAllowableCosts, 175)
      XCTAssertEqual(disposal.rawGain, 325)
      XCTAssertEqual(spouseTransfer.costBasis, 35)
      XCTAssertEqual(result.holdings["TEST"]?.quantity, 40)
      XCTAssertEqual(result.holdings["TEST"]?.costBasis, 140)
      XCTAssertEqual(disposal.bedAndBreakfastMatches.reduce(0) { $0 + $1.quantity }, 50)
      XCTAssertEqual(disposal.bedAndBreakfastMatches.reduce(0) { $0 + $1.cost }, 175)
    }
  }

  func testSameDateSpouseInAndSellAreOrderIndependentWithoutSourceOrder() throws {
    for transactions in [
      [TestSupport.spouseIn("01/06/2020", "TEST", 10, 3), TestSupport.sell("01/06/2020", "TEST", 10, 5, 0)],
      [TestSupport.sell("01/06/2020", "TEST", 10, 5, 0), TestSupport.spouseIn("01/06/2020", "TEST", 10, 3)]
    ] {
      let result = try CGTEngine.calculate(transactions: transactions, assetEvents: [])
      let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)

      XCTAssertEqual(disposal.rawAllowableCosts, 30)
      XCTAssertEqual(disposal.rawGain, 20)
      XCTAssertEqual(result.holdings["TEST"]?.quantity, 0)
    }
  }

  func testSameDateDistributionOrderIsIndependentOfPublicAPIArrayOrderAndUUIDs() throws {
    let transactions = [
      TestSupport.buy("01/01/2020", "TEST", 100, 10, 0),
      TestSupport.buy("01/07/2020", "TEST", 100, 1, 0)
    ]

    for capitalReturnFirst in [false, true] {
      let dividend = TestSupport.dividend("31/12/2020", "TEST", 200, 100)
      let capitalReturn = TestSupport.capReturn("31/12/2020", "TEST", 100, 150)
      let reset = TestSupport.dividend("30/06/2020", "TEST", 100, 0)
      let events = capitalReturnFirst ? [capitalReturn, reset, dividend] : [reset, dividend, capitalReturn]
      let result = try CGTEngine.calculate(transactions: transactions, assetEvents: events)

      XCTAssertEqual(result.holdings["TEST"]?.quantity, 200)
      XCTAssertEqual(result.holdings["TEST"]?.costBasis, 1050)
    }
  }

  func testSameDateRestructureAndOutboundUsePostRestructureBasisRegardlessOfInputOrder() throws {
    let rows = [
      "UNSPLIT 01/06/2020 TEST 2",
      "SELL 01/06/2020 TEST 20 30 0"
    ]

    for sameDateRows in [rows, Array(rows.reversed())] {
      let content = (["BUY 01/01/2020 TEST 100 10 0"] + sameDateRows).joined(separator: "\n")
      let result = try CGTEngine.calculate(inputData: InputParser.parse(content: content))
      let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)

      XCTAssertEqual(disposal.rawAllowableCosts, 400)
      XCTAssertEqual(disposal.rawGain, 200)
      XCTAssertEqual(result.holdings["TEST"]?.quantity, 30)
      XCTAssertEqual(result.holdings["TEST"]?.costBasis, 600)
    }
  }

  func testSplitDistributionRowsHaveSameEconomicsAsAggregatedRows() throws {
    let transactions = [
      TestSupport.buy("01/01/2020", "TEST", 100, 10, 0),
      TestSupport.buy("01/07/2020", "TEST", 100, 1, 0)
    ]
    let reset = TestSupport.dividend("30/06/2020", "TEST", 100, 0)
    let splitEvents = [
      reset,
      TestSupport.dividend("31/12/2020", "TEST", 50, 25),
      TestSupport.capReturn("31/12/2020", "TEST", 40, 60),
      TestSupport.dividend("31/12/2020", "TEST", 150, 75),
      TestSupport.capReturn("31/12/2020", "TEST", 60, 90)
    ]
    let aggregatedEvents = [
      reset,
      TestSupport.capReturn("31/12/2020", "TEST", 100, 150),
      TestSupport.dividend("31/12/2020", "TEST", 200, 100)
    ]

    let splitResult = try CGTEngine.calculate(transactions: transactions, assetEvents: splitEvents)
    let aggregatedResult = try CGTEngine.calculate(transactions: transactions, assetEvents: aggregatedEvents)

    XCTAssertEqual(splitResult.holdings["TEST"]?.quantity, aggregatedResult.holdings["TEST"]?.quantity)
    XCTAssertEqual(splitResult.holdings["TEST"]?.costBasis, aggregatedResult.holdings["TEST"]?.costBasis)
  }

  private func permutations<T>(of values: [T]) -> [[T]] {
    guard values.count > 1 else { return [values] }
    return values.indices.flatMap { index in
      var remainder = values
      let value = remainder.remove(at: index)
      return self.permutations(of: remainder).map { [value] + $0 }
    }
  }

  func testSharedRebuyCostIncludingExpensesIsConservedAcrossDisposals() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 3 1 0
    SELL 01/06/2020 TEST 1 100 0
    SELL 02/06/2020 TEST 1 100 0
    SELL 03/06/2020 TEST 1 100 0
    BUY 10/06/2020 TEST 3 30 10
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let matchedCosts = result.taxYearSummaries
      .flatMap(\.disposals)
      .flatMap(\.bedAndBreakfastMatches)
      .reduce(Decimal(0)) { $0 + $1.cost }

    XCTAssertEqual(matchedCosts, 100)
  }

  func testExactTotalCostSpouseHandoffPreservesRecipientBasis() throws {
    let transferorInput = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100000000 0.123456789 0
    SPOUSEOUT 01/06/2020 TEST 100000000
    """)
    let transferorResult = try CGTEngine.calculate(inputData: transferorInput)
    let transfer = try XCTUnwrap(transferorResult.spouseTransfersOut.first)

    XCTAssertEqual(transfer.costBasis, Decimal.parse("12345678.9"))
    XCTAssertTrue(TextReportFormatter().format(transferorResult).contains(
      "Recipient input: SPOUSEIN 01/06/2020 TEST 100000000 TOTALCOST 12345678.9"))

    let recipientInput = try InputParser.parse(content: """
    SPOUSEIN 01/06/2020 TEST 100000000 TOTALCOST 12345678.9
    SELL 01/07/2020 TEST 100000000 0.2 0
    """)
    let recipientResult = try CGTEngine.calculate(inputData: recipientInput)
    let disposal = try XCTUnwrap(recipientResult.taxYearSummaries.first?.disposals.first)

    XCTAssertEqual(disposal.rawAllowableCosts, transfer.costBasis)
    XCTAssertEqual(disposal.rawGain, Decimal.parse("7654321.1"))
    XCTAssertEqual(disposal.gain, 7654321)
  }

  func testMultipleExactTotalCostSpouseInsEnterSection104WithoutRateConversion() throws {
    let input = try InputParser.parse(content: """
    SPOUSEIN 01/01/2020 TEST 3 TOTALCOST 10
    SPOUSEIN 01/02/2020 TEST 7 TOTALCOST 20
    """)

    let result = try CGTEngine.calculate(inputData: input)

    XCTAssertEqual(result.holdings["TEST"]?.quantity, 10)
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 30)
  }

  func testCapitalReturnUsesHighCostGroupIITrancheInsteadOfPoolAverage() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 1 0
    DIVIDEND 30/06/2020 TEST 100 0
    BUY 01/07/2020 TEST 100 100 0
    CAPRETURN 31/12/2020 TEST 100 6000
    """)

    let result = try CGTEngine.calculate(inputData: input)

    XCTAssertEqual(result.holdings["TEST"]?.quantity, 200)
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 4100)
  }

  func testCapitalReturnRejectsValueAboveLowCostGroupIITranche() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 100 0
    DIVIDEND 30/06/2020 TEST 100 0
    BUY 01/07/2020 TEST 100 1 0
    CAPRETURN 31/12/2020 TEST 100 200
    """)

    XCTAssertThrowsError(try CGTEngine.calculate(inputData: input)) { error in
      guard case CalculationError.unsupportedCapitalReturn(_, _, let value, let availableCost) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(value, 200)
      XCTAssertEqual(availableCost, 100)
    }
  }

  func testGroupIICostIncludesAcquisitionExpenses() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 10 0
    DIVIDEND 30/06/2020 TEST 100 0
    BUY 01/07/2020 TEST 100 1 25
    CAPRETURN 31/12/2020 TEST 100 125
    """)

    let result = try CGTEngine.calculate(inputData: input)

    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 1000)
  }

  func testCapitalReturnUsesCombinedCostOfMultipleGroupIIAcquisitions() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 10 0
    DIVIDEND 30/06/2020 TEST 100 0
    BUY 01/07/2020 TEST 50 1 0
    BUY 02/07/2020 TEST 50 3 0
    CAPRETURN 31/12/2020 TEST 100 200
    """)

    let result = try CGTEngine.calculate(inputData: input)

    XCTAssertEqual(result.holdings["TEST"]?.quantity, 200)
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 1000)
  }

  func testPartialPoolDisposalDepletesGroupIBeforeGroupIICost() throws {
    let validInput = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 10 0
    DIVIDEND 30/06/2020 TEST 100 0
    BUY 01/07/2020 TEST 100 2 0
    SELL 01/10/2020 TEST 150 10 0
    CAPRETURN 31/12/2020 TEST 50 100
    """)
    let excessiveInput = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 10 0
    DIVIDEND 30/06/2020 TEST 100 0
    BUY 01/07/2020 TEST 100 2 0
    SELL 01/10/2020 TEST 150 10 0
    CAPRETURN 31/12/2020 TEST 50 100.01
    """)

    let result = try CGTEngine.calculate(inputData: validInput)

    XCTAssertEqual(result.holdings["TEST"]?.quantity, 50)
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 200)
    XCTAssertThrowsError(try CGTEngine.calculate(inputData: excessiveInput))
  }

  func testGroupIICostSurvivesQuantityOnlyRestructures() throws {
    let inputs = [
      """
      BUY 01/01/2020 TEST 100 10 0
      DIVIDEND 30/06/2020 TEST 100 0
      BUY 01/07/2020 TEST 100 1 0
      SPLIT 01/10/2020 TEST 2
      CAPRETURN 31/12/2020 TEST 200 100
      """,
      """
      BUY 01/01/2020 TEST 100 10 0
      DIVIDEND 30/06/2020 TEST 100 0
      BUY 01/07/2020 TEST 100 1 0
      UNSPLIT 01/10/2020 TEST 2
      CAPRETURN 31/12/2020 TEST 50 100
      """,
      """
      BUY 01/01/2020 TEST 100 10 0
      DIVIDEND 30/06/2020 TEST 100 0
      BUY 01/07/2020 TEST 100 1 0
      RESTRUCT 01/10/2020 TEST 2:3
      CAPRETURN 31/12/2020 TEST 150 100
      """
    ]

    for input in inputs {
      let result = try CGTEngine.calculate(inputData: InputParser.parse(content: input))
      XCTAssertEqual(result.holdings["TEST"]?.costBasis, 1000)
    }
  }

  func testSubsequentDisposalStillUsesSection104AverageAfterGroupIICapitalReturn() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 1 0
    DIVIDEND 30/06/2020 TEST 100 0
    BUY 01/07/2020 TEST 100 100 0
    CAPRETURN 31/12/2020 TEST 100 6000
    SELL 01/01/2021 TEST 200 50 0
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)

    XCTAssertEqual(disposal.section104Matches.reduce(Decimal(0)) { $0 + $1.cost }, 4100)
    XCTAssertEqual(disposal.rawGain, 5900)
  }

  func testSameDayDividendIncreasesGroupIICostAvailableToCapitalReturn() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 10 0
    DIVIDEND 30/06/2020 TEST 100 0
    BUY 01/07/2020 TEST 100 1 0
    DIVIDEND 31/12/2020 TEST 200 100
    CAPRETURN 31/12/2020 TEST 100 150
    """)

    let result = try CGTEngine.calculate(inputData: input)

    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 1050)
  }

  func testGroupedCapitalReturnValuesCannotExceedGroupIICost() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 10 0
    DIVIDEND 30/06/2020 TEST 100 0
    BUY 01/07/2020 TEST 100 1 0
    CAPRETURN 31/12/2020 TEST 50 60
    CAPRETURN 31/12/2020 TEST 50 50
    """)

    XCTAssertThrowsError(try CGTEngine.calculate(inputData: input)) { error in
      guard case CalculationError.unsupportedCapitalReturn(_, _, let value, let availableCost) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(value, 110)
      XCTAssertEqual(availableCost, 100)
    }
  }

  func testFinalMatchedDestinationReceivesRepeatingAllocationResidual() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 0.0003 500000 0
    SELL 01/06/2020 TEST 0.0001 2000000 0
    SELL 02/06/2020 TEST 0.0001 2000000 0
    SELL 03/06/2020 TEST 0.0001 2000000 0
    BUY 10/06/2020 TEST 0.0003 500000 0
    DIVIDEND 15/06/2020 TEST 0.0002 100
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let adjustments = result.taxYearSummaries
      .flatMap(\.disposals)
      .sorted { $0.sellTransaction.date < $1.sellTransaction.date }
      .compactMap { $0.bedAndBreakfastMatches.first?.eventAdjustment }

    XCTAssertEqual(adjustments, try [
      XCTUnwrap(Decimal.parse("33.3333333333")),
      XCTUnwrap(Decimal.parse("33.3333333333")),
      XCTUnwrap(Decimal.parse("33.3333333334"))
    ])
    XCTAssertEqual(adjustments.reduce(Decimal(0), +), 100)
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 150)
  }

  func testRepeatingOneThirdCapitalReturnUsesExactMonetaryAllocation() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 0.0003 1000000 0
    SELL 01/06/2020 TEST 0.0001 2000000 0
    BUY 10/06/2020 TEST 0.0001 1000000 0
    CAPRETURN 15/06/2020 TEST 0.0002 90
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)

    XCTAssertEqual(disposal.bedAndBreakfastMatches.first?.eventAdjustment, -30)
    XCTAssertEqual(disposal.rawAllowableCosts, 70)
    XCTAssertEqual(disposal.rawGain, 130)
    XCTAssertEqual(disposal.gain, 130)
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 240)
  }

  func testRepeatingOneThirdDividendUsesExactMonetaryAllocation() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 0.0003 1000000 0
    SELL 01/06/2020 TEST 0.0001 2000000 0
    BUY 10/06/2020 TEST 0.0001 1000000 0
    DIVIDEND 15/06/2020 TEST 0.0002 90
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)

    XCTAssertEqual(disposal.bedAndBreakfastMatches.first?.eventAdjustment, 30)
    XCTAssertEqual(disposal.rawAllowableCosts, 130)
    XCTAssertEqual(disposal.rawGain, 70)
    XCTAssertEqual(disposal.gain, 70)
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 360)
  }

  func testAllocationPrecisionPreservesGenuineValuesAroundWholePoundBoundary() throws {
    let belowInput = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 0.0003 1000000 0
    SELL 01/06/2020 TEST 0.0001 2000000 0
    BUY 10/06/2020 TEST 0.0001 1000000 0
    CAPRETURN 15/06/2020 TEST 0.0002 89.999997
    """)
    let aboveInput = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 0.0003 1000000 0
    SELL 01/06/2020 TEST 0.0001 2000000 0
    BUY 10/06/2020 TEST 0.0001 1000000 0
    CAPRETURN 15/06/2020 TEST 0.0002 90.000003
    """)

    let below = try XCTUnwrap(try CGTEngine.calculate(inputData: belowInput).taxYearSummaries.first?.disposals.first)
    let above = try XCTUnwrap(try CGTEngine.calculate(inputData: aboveInput).taxYearSummaries.first?.disposals.first)

    XCTAssertLessThan(try -XCTUnwrap(below.bedAndBreakfastMatches.first).eventAdjustment, 30)
    XCTAssertEqual(below.gain, 129)
    XCTAssertGreaterThan(try -XCTUnwrap(above.bedAndBreakfastMatches.first).eventAdjustment, 30)
    XCTAssertEqual(above.gain, 130)
  }

  func testToleratedEventAmountIsAllocatedProportionatelyAcrossTaxYears() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2024 TEST 0.0002 500000 0
    SELL 20/03/2025 TEST 0.0001 2000000 0
    SELL 06/04/2025 TEST 0.0001 2000000 0
    BUY 10/04/2025 TEST 0.0002 500000 0
    DIVIDEND 15/04/2025 TEST 0.0001 100
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let disposals = result.taxYearSummaries
      .flatMap(\.disposals)
      .sorted { $0.sellTransaction.date < $1.sellTransaction.date }

    XCTAssertEqual(disposals.count, 2)
    XCTAssertEqual(disposals[0].bedAndBreakfastMatches.first?.eventAdjustment, 50)
    XCTAssertEqual(disposals[0].rawGain, 100)
    XCTAssertEqual(disposals[0].gain, 100)
    XCTAssertEqual(disposals[1].bedAndBreakfastMatches.first?.eventAdjustment, 50)
    XCTAssertEqual(disposals[1].rawGain, 100)
    XCTAssertEqual(disposals[1].gain, 100)
    XCTAssertEqual(result.holdings["TEST"]?.quantity, Decimal.parse("0.0002"))
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 100)
  }

  func testToleratedTinyDividendAmountCannotAllocateMoreThanEventValue() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 0.0001 1000000 0
    SELL 01/06/2020 TEST 0.0001 2000000 0
    BUY 10/06/2020 TEST 0.0001 1000000 0
    DIVIDEND 15/06/2020 TEST 0.00001 100
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)

    XCTAssertEqual(disposal.rawGain, 0)
    XCTAssertEqual(disposal.bedAndBreakfastMatches.first?.eventAdjustment, 100)
    XCTAssertEqual(result.holdings["TEST"]?.quantity, Decimal.parse("0.0001"))
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 100)
  }

  func testRelativeToleranceAboveEligibleQuantityConservesDividendValue() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100000 1 0
    SELL 01/06/2020 TEST 50000 2 0
    BUY 10/06/2020 TEST 50000 1 0
    DIVIDEND 15/06/2020 TEST 100001 100
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)
    let allocated = try XCTUnwrap(disposal.bedAndBreakfastMatches.first?.eventAdjustment)
    let poolIncrease = try XCTUnwrap(result.holdings["TEST"]?.costBasis) - 100000

    XCTAssertEqual(allocated + poolIncrease, 100, accuracy: 0.0000001)
  }

  func testRelativeToleranceBelowEligibleQuantityConservesCapitalReturnValue() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100000 2 0
    SELL 01/06/2020 TEST 50000 3 0
    BUY 10/06/2020 TEST 50000 2 0
    CAPRETURN 15/06/2020 TEST 99999 100
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)
    let allocatedReduction = try -XCTUnwrap(disposal.bedAndBreakfastMatches.first?.eventAdjustment)
    let poolReduction = try 200000 - XCTUnwrap(result.holdings["TEST"]?.costBasis)

    XCTAssertEqual(allocatedReduction + poolReduction, 100, accuracy: 0.0000001)
  }

  func testMultipleMatchesCannotCollectMoreThanLogicalEventValue() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 0.0002 500000 0
    SELL 01/06/2020 TEST 0.0001 2000000 0
    SELL 02/06/2020 TEST 0.0001 2000000 0
    BUY 10/06/2020 TEST 0.0002 500000 0
    DIVIDEND 15/06/2020 TEST 0.0001 100
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let allocated = result.taxYearSummaries
      .flatMap(\.disposals)
      .flatMap(\.bedAndBreakfastMatches)
      .reduce(Decimal(0)) { $0 + $1.eventAdjustment }

    XCTAssertEqual(allocated, 100)
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 100)
  }

  func testRejectsCapitalReturnExceedingRemainingAllowableCost() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 1 0
    CAPRETURN 01/02/2020 TEST 100 150
    SELL 01/03/2020 TEST 100 2 0
    """)

    XCTAssertThrowsError(try CGTEngine.calculate(inputData: input)) { error in
      guard case CalculationError.unsupportedCapitalReturn(
        let asset,
        let date,
        let value,
        let availableCost) = error
      else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(asset, "TEST")
      XCTAssertEqual(date, TestSupport.date("01/02/2020"))
      XCTAssertEqual(value, 150)
      XCTAssertEqual(availableCost, 100)
    }
  }

  func testAllowsCapitalReturnEqualToRemainingAllowableCost() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 1 0
    CAPRETURN 01/02/2020 TEST 100 100
    """)

    let result = try CGTEngine.calculate(inputData: input)

    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 0)
  }

  func testAllowsCapitalReturnWithinMonetaryDustTolerance() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 1 0
    CAPRETURN 01/02/2020 TEST 100 100.00005
    """)

    let result = try CGTEngine.calculate(inputData: input)

    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 0)
  }

  func testRejectsCapitalReturnOnePennyAboveRemainingAllowableCost() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 1 0
    CAPRETURN 01/02/2020 TEST 100 100.01
    """)

    XCTAssertThrowsError(try CGTEngine.calculate(inputData: input))
  }

  func testRejectsExcessResidualCapitalReturnAfterPartialThirtyDayAllocation() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 0.5 0
    SELL 01/06/2020 TEST 50 1 0
    BUY 10/06/2020 TEST 50 2 0
    CAPRETURN 15/06/2020 TEST 100 150
    """)

    XCTAssertThrowsError(try CGTEngine.calculate(inputData: input)) { error in
      guard case CalculationError.unsupportedCapitalReturn(_, _, let value, let availableCost) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(value, 75)
      XCTAssertEqual(availableCost, 25)
    }
  }

  func testRejectsExcessCapitalReturnAgainstFullyMatchedRebuy() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 1 0
    SELL 01/06/2020 TEST 100 2 0
    BUY 10/06/2020 TEST 100 1 0
    CAPRETURN 15/06/2020 TEST 100 101
    """)

    XCTAssertThrowsError(try CGTEngine.calculate(inputData: input)) { error in
      guard case CalculationError.unsupportedCapitalReturn(_, _, let value, let availableCost) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(value, 101)
      XCTAssertEqual(availableCost, 100)
    }
  }

  func testMultipleSameDayDividendRowsMatchSingleAggregatedEvent() throws {
    let splitRows = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 10 0
    SELL 01/06/2020 TEST 100 20 0
    BUY 10/06/2020 TEST 100 10 0
    DIVIDEND 15/06/2020 TEST 50 5
    DIVIDEND 15/06/2020 TEST 50 5
    """)
    let aggregatedRow = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 10 0
    SELL 01/06/2020 TEST 100 20 0
    BUY 10/06/2020 TEST 100 10 0
    DIVIDEND 15/06/2020 TEST 100 10
    """)

    let splitResult = try CGTEngine.calculate(inputData: splitRows)
    let aggregatedResult = try CGTEngine.calculate(inputData: aggregatedRow)
    let splitDisposal = try XCTUnwrap(splitResult.taxYearSummaries.first?.disposals.first)
    let aggregatedDisposal = try XCTUnwrap(aggregatedResult.taxYearSummaries.first?.disposals.first)

    XCTAssertEqual(splitDisposal.rawGain, 990)
    XCTAssertEqual(splitDisposal.rawGain, aggregatedDisposal.rawGain)
    XCTAssertEqual(splitDisposal.bedAndBreakfastMatches.first?.eventAdjustment, 10)
    XCTAssertEqual(splitResult.holdings["TEST"]?.costBasis, 1000)
    XCTAssertEqual(splitResult.holdings["TEST"]?.costBasis, aggregatedResult.holdings["TEST"]?.costBasis)
  }

  func testMultipleSameDayCapitalReturnRowsMatchSingleAggregatedEvent() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 10 0
    SELL 01/06/2020 TEST 100 20 0
    BUY 10/06/2020 TEST 100 10 0
    CAPRETURN 15/06/2020 TEST 25 2
    CAPRETURN 15/06/2020 TEST 75 9
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let disposal = try XCTUnwrap(result.taxYearSummaries.first?.disposals.first)

    XCTAssertEqual(disposal.rawGain, 1011)
    XCTAssertEqual(disposal.bedAndBreakfastMatches.first?.eventAdjustment, -11)
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 1000)
  }

  func testDistributionValueIsConservedAcrossThirtyDayMatchAndSection104() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 10 0
    SELL 01/06/2020 TEST 50 20 0
    BUY 10/06/2020 TEST 50 12 0
    DIVIDEND 15/06/2020 TEST 100 100
    SELL 20/06/2020 TEST 50 25 0
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let disposals = result.taxYearSummaries.flatMap(\.disposals)
      .sorted { $0.sellTransaction.date < $1.sellTransaction.date }

    XCTAssertEqual(disposals.count, 2)
    XCTAssertEqual(disposals[0].rawGain, 350)
    XCTAssertEqual(disposals[0].bedAndBreakfastMatches.first?.eventAdjustment, 50)
    XCTAssertEqual(disposals[1].rawGain, 725)
    XCTAssertEqual(result.holdings["TEST"]?.quantity, 50)
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 525)
  }

  func testCapitalReturnValueIsConservedAcrossThirtyDayMatchAndSection104() throws {
    let input = try InputParser.parse(content: """
    BUY 01/01/2020 TEST 100 10 0
    SELL 01/06/2020 TEST 50 20 0
    BUY 10/06/2020 TEST 50 12 0
    CAPRETURN 15/06/2020 TEST 100 100
    SELL 20/06/2020 TEST 50 25 0
    """)

    let result = try CGTEngine.calculate(inputData: input)
    let disposals = result.taxYearSummaries.flatMap(\.disposals)
      .sorted { $0.sellTransaction.date < $1.sellTransaction.date }

    XCTAssertEqual(disposals.count, 2)
    XCTAssertEqual(disposals[0].rawGain, 450)
    XCTAssertEqual(disposals[0].bedAndBreakfastMatches.first?.eventAdjustment, -50)
    XCTAssertEqual(disposals[1].rawGain, 775)
    XCTAssertEqual(result.holdings["TEST"]?.quantity, 50)
    XCTAssertEqual(result.holdings["TEST"]?.costBasis, 475)
  }

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
}
