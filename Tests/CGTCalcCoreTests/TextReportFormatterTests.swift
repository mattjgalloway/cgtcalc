@testable import CGTCalcCore
import XCTest

final class TextReportFormatterTests: XCTestCase {
  func testFormats2024_2025SpecialRateChangeLine() {
    let firstDisposal = TestSupport.disposal(
      asset: "TEST",
      date: "29/10/2024",
      quantity: 10,
      price: 20,
      gain: 100,
      taxYear: TaxYear(startYear: 2024))
    let secondDisposal = TestSupport.disposal(
      asset: "TEST",
      date: "30/10/2024",
      quantity: 10,
      price: 20,
      gain: 200,
      taxYear: TaxYear(startYear: 2024))

    let summary = TaxYearSummary(
      taxYear: TaxYear(startYear: 2024),
      disposals: [firstDisposal, secondDisposal],
      totalGain: 300,
      totalLoss: 0,
      netGain: 300,
      exemption: 3000,
      taxableGain: 0,
      lossCarryForward: 0)

    let result = CalculationResult(
      taxYearSummaries: [summary],
      transactions: [firstDisposal.sellTransaction, secondDisposal.sellTransaction],
      assetEvents: [],
      lossCarryForward: 0)

    let output = TextReportFormatter().format(result)

    XCTAssertTrue(output.contains(
      "    > Gains to (and inc.) 29th October = 100, gains after 29th October = 200"))
  }

  func testFormatsTransactionsAndAssetEventsInInputOrder() throws {
    let summary = TaxYearSummary(
      taxYear: TaxYear(startYear: 2023),
      disposals: [],
      totalGain: 0,
      totalLoss: 0,
      netGain: 0,
      exemption: 6000,
      taxableGain: 0,
      lossCarryForward: 0)
    let transactions = [
      TestSupport.sell("03/01/2024", "BBB", 2, 12, 1),
      TestSupport.buy("01/01/2024", "AAA", 1, 10, 0),
      TestSupport.buy("02/01/2024", "CCC", 3, 11, 0)
    ]
    let assetEvents = try [
      TestSupport.dividend("03/03/2024", "BBB", 2, 5),
      AssetEvent(type: .split, date: TestSupport.date("01/03/2024"), asset: "AAA", multiplier: 2),
      TestSupport.capReturn("02/03/2024", "CCC", 3, 4)
    ]

    let result = CalculationResult(
      taxYearSummaries: [summary],
      transactions: transactions,
      assetEvents: assetEvents,
      lossCarryForward: 0)

    let output = TextReportFormatter().format(result)

    let transactionsSection = output.components(separatedBy: "# TRANSACTIONS\n\n")[1]
      .components(separatedBy: "\n\n# ASSET EVENTS")[0]
    XCTAssertTrue(transactionsSection.hasPrefix(
      """
      03/01/2024 SOLD 2 of BBB at £12 with £1 expenses
      01/01/2024 BOUGHT 1 of AAA at £10 with £0 expenses
      02/01/2024 BOUGHT 3 of CCC at £11 with £0 expenses
      """))

    let eventsSection = output.components(separatedBy: "# ASSET EVENTS\n\n")[1]
    XCTAssertTrue(eventsSection.hasPrefix(
      """
      03/03/2024 BBB DIVIDEND on 2 for £5
      01/03/2024 AAA SPLIT by 2
      02/03/2024 CCC CAPITAL RETURN on 3 for £4
      """))
  }

  func testFormatsBedAndBreakfastRestructureAndOffsetSuffixes() {
    let buy = TestSupport.buy("10/11/2019", "FUND", 20, 190.19, 2)
    let sell = TestSupport.sell("05/11/2019", "FUND", 10, 194.22, 12.5)
    let match = BedAndBreakfastMatch(
      buyTransaction: buy,
      quantity: 10,
      buyDateQuantity: 20,
      eventAdjustment: 15.81,
      cost: 1918.71)
    let disposal = Disposal(
      sellTransaction: sell,
      taxYear: TaxYear.from(date: sell.date),
      gain: 11,
      section104Matches: [],
      bedAndBreakfastMatches: [match])
    let summary = TaxYearSummary(
      taxYear: disposal.taxYear,
      disposals: [disposal],
      totalGain: 11,
      totalLoss: 0,
      netGain: 11,
      exemption: 12000,
      taxableGain: 0,
      lossCarryForward: 0)

    let result = CalculationResult(
      taxYearSummaries: [summary],
      transactions: [sell, buy],
      assetEvents: [],
      lossCarryForward: 0)

    let output = TextReportFormatter().format(result)

    XCTAssertTrue(output.contains(
      "  - BED & BREAKFAST: 20 bought on 10/11/2019 at £190.19 with restructure multiplier 2 with offset of £15.81"))
    XCTAssertTrue(output.contains(
      "Calculation: (10 * 194.22 - 12.5) - ( (20 * 190.19 + 2 + 15.81) ) = 11"))
  }

  func testFormatsSameDayMatchesWithSameDayLabel() {
    let date = TestSupport.date("01/06/2020")
    let buy = Transaction(type: .buy, date: date, asset: "FUND", quantity: 10, price: 12, expenses: 1)
    let sell = Transaction(type: .sell, date: date, asset: "FUND", quantity: 10, price: 15, expenses: 0)
    let match = BedAndBreakfastMatch(
      buyTransaction: buy,
      quantity: 10,
      buyDateQuantity: 10,
      eventAdjustment: 0,
      cost: 121)
    let disposal = Disposal(
      sellTransaction: sell,
      taxYear: TaxYear.from(date: date),
      gain: 29,
      section104Matches: [],
      bedAndBreakfastMatches: [match])
    let summary = TaxYearSummary(
      taxYear: disposal.taxYear,
      disposals: [disposal],
      totalGain: 29,
      totalLoss: 0,
      netGain: 29,
      exemption: 12300,
      taxableGain: 0,
      lossCarryForward: 0)

    let result = CalculationResult(
      taxYearSummaries: [summary],
      transactions: [buy, sell],
      assetEvents: [],
      lossCarryForward: 0)

    let output = TextReportFormatter().format(result)

    XCTAssertTrue(output.contains("  - SAME DAY: 10 bought on 01/06/2020 at £12\n"))
  }

  func testFormatsMixedBedAndBreakfastAndSection104CalculationWithResidualPoolQuantity() {
    let sell = TestSupport.sell("01/02/2024", "FUND", 100, 20, 0)
    let rebuy = TestSupport.buy("10/02/2024", "FUND", 30, 12, 0)
    let pooledBuy = TestSupport.buy("01/01/2024", "FUND", 100, 10, 0)
    let bedAndBreakfastMatch = BedAndBreakfastMatch(
      buyTransaction: rebuy,
      quantity: 30,
      buyDateQuantity: 30,
      eventAdjustment: 0,
      cost: 360)
    let section104Match = Section104Match(
      transactionId: pooledBuy.id,
      quantity: 70,
      cost: 700,
      date: pooledBuy.date,
      poolQuantity: 100,
      poolCost: 1000)
    let disposal = Disposal(
      sellTransaction: sell,
      taxYear: TaxYear.from(date: sell.date),
      gain: 940,
      section104Matches: [section104Match],
      bedAndBreakfastMatches: [bedAndBreakfastMatch])
    let summary = TaxYearSummary(
      taxYear: disposal.taxYear,
      disposals: [disposal],
      totalGain: 940,
      totalLoss: 0,
      netGain: 940,
      exemption: 6000,
      taxableGain: 0,
      lossCarryForward: 0)

    let result = CalculationResult(
      taxYearSummaries: [summary],
      transactions: [sell, rebuy],
      assetEvents: [],
      lossCarryForward: 0)

    let output = TextReportFormatter().format(result)

    XCTAssertTrue(output.contains(
      "Calculation: (100 * 20 - 0) - ( (30 * 12 + 0) + (70 * 10) ) = 940"))
    XCTAssertFalse(output.contains(
      "Calculation: (100 * 20 - 0) - ( (30 * 12 + 0) + (100 * 10) ) = 940"))
  }

  func testCountsZeroGainDisposalsAsGainsInTaxYearDetails() {
    let zeroGain = TestSupport.disposal(
      asset: "ZERO",
      date: "01/06/2020",
      quantity: 10,
      price: 10,
      gain: 0)
    let loss = TestSupport.disposal(
      asset: "LOSS",
      date: "02/06/2020",
      quantity: 10,
      price: 9,
      gain: -5)
    let summary = TaxYearSummary(
      taxYear: TaxYear(startYear: 2020),
      disposals: [zeroGain, loss],
      totalGain: 0,
      totalLoss: 5,
      netGain: -5,
      exemption: 12300,
      taxableGain: 0,
      lossCarryForward: 5)

    let result = CalculationResult(
      taxYearSummaries: [summary],
      transactions: [zeroGain.sellTransaction, loss.sellTransaction],
      assetEvents: [],
      lossCarryForward: 5)

    let output = TextReportFormatter().format(result)

    XCTAssertTrue(output.contains("1 gains with total of 0."))
    XCTAssertTrue(output.contains("1 losses with total of 5."))
    XCTAssertTrue(output.contains("for GAIN of £0"))
  }

  func testFormatsSpouseTransfersOutSectionWhenPresent() {
    let transferTx = TestSupport.spouseOut("01/02/2024", "FUND", 40)
    let transfer = SpouseTransferOut(transaction: transferTx, costBasis: 420.25)
    let result = CalculationResult(
      taxYearSummaries: [],
      transactions: [transferTx, TestSupport.spouseIn("03/02/2024", "FUND", 10, 10.5)],
      assetEvents: [],
      lossCarryForward: 0,
      spouseTransfersOut: [transfer])

    let output = TextReportFormatter().format(result)

    XCTAssertTrue(output.contains("# SPOUSE TRANSFERS OUT"))
    XCTAssertTrue(output.contains(
      "01/02/2024 SPOUSEOUT 40 of FUND at transferred cost basis £420.25 (£10.50625 per unit)"))
    XCTAssertTrue(output.contains("01/02/2024 SPOUSEOUT 40 of FUND"))
    XCTAssertTrue(output.contains("03/02/2024 SPOUSEIN 10 of FUND at £10.5"))
  }
}
