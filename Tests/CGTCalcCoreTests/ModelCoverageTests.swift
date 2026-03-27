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

    let unsupportedDate = CalculationError.unsupportedInputDate(
      date: TestSupport.date("01/01/2007"),
      minimumDate: TestSupport.date("06/04/2008"))
    XCTAssertEqual(
      unsupportedDate.errorDescription,
      "Unsupported input date 01/01/2007: dates before 06/04/2008 are not supported")

    let unsupportedFallback = CalculationError.unsupportedLaterAcquisitionIdentification(
      asset: "ABC",
      date: TestSupport.date("01/01/2020"),
      requested: 10,
      matched: 3,
      firstLaterAcquisitionDate: TestSupport.date("15/02/2020"))
    XCTAssertEqual(
      unsupportedFallback.errorDescription,
      "Unsupported share-identification case for ABC on 01/01/2020: matched 3 of 10 using same-day/30-day/Section 104 rules, and found later acquisitions from 15/02/2020. HMRC's later-acquisition fallback stage is not currently implemented.")

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

  func testDecimalHelpersUseFixedLocale() {
    let enGB = Locale(identifier: "en_GB")
    let parsed = Decimal.parse("1234.56")
    XCTAssertEqual(parsed, Decimal(string: "1234.56"))
    XCTAssertEqual(parsed?.string, "1234.56")
    XCTAssertEqual(Decimal.parse("1,234.56"), Decimal(string: "1,234.56", locale: enGB))
  }

  func testTaxReturnMathComputedProperties() throws {
    let beforeRateChange = TestSupport.disposal(
      asset: "TEST",
      date: "29/10/2024",
      quantity: 1,
      price: 10.9,
      gain: 3.5,
      taxYear: TaxYear(startYear: 2024))
    let afterRateChange = TestSupport.disposal(
      asset: "TEST",
      date: "30/10/2024",
      quantity: 1,
      price: 10.9,
      gain: 4,
      taxYear: TaxYear(startYear: 2024))
    let loss = TestSupport.disposal(
      asset: "TEST",
      date: "31/10/2024",
      quantity: 1,
      price: 5.9,
      gain: -1.25,
      taxYear: TaxYear(startYear: 2024))
    let summary = TaxYearSummary(
      taxYear: TaxYear(startYear: 2024),
      disposals: [beforeRateChange, afterRateChange, loss],
      totalGain: 7.5,
      totalLoss: 1.25,
      netGain: 6.25,
      exemption: 3000,
      taxableGain: 0,
      lossCarryForward: 0)

    XCTAssertEqual(summary.summaryReportedProceeds, 27)

    let taxReturn = summary.taxReturnMath
    XCTAssertEqual(taxReturn.disposalsCount, 3)
    XCTAssertEqual(taxReturn.proceeds, 25)
    XCTAssertEqual(taxReturn.allowableCosts, 18.75)
    XCTAssertEqual(taxReturn.totalGains, 7.5)
    XCTAssertEqual(taxReturn.totalLosses, 1.25)

    let split = try XCTUnwrap(taxReturn.specialRateSplit)
    XCTAssertEqual(split.label, "29th October")
    XCTAssertEqual(split.gainsToAndIncludingLabelDate, 3.5)
    XCTAssertEqual(split.gainsAfterLabelDate, 4)
  }
}
