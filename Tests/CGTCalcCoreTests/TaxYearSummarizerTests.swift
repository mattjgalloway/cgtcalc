@testable import CGTCalcCore
import XCTest

final class TaxYearSummarizerTests: XCTestCase {
  func testSummarizesNetGainWithinTaxYear() throws {
    let result = try TaxYearSummarizer.summarize(disposals: [
      TestSupport.disposal(date: "01/06/2019", gain: 400),
      TestSupport.disposal(date: "01/08/2019", gain: -150)
    ])

    XCTAssertEqual(result.summaries.count, 1)
    let summary = result.summaries[0]
    XCTAssertEqual(summary.totalGain, 400)
    XCTAssertEqual(summary.totalLoss, 150)
    XCTAssertEqual(summary.netGain, 250)
    XCTAssertEqual(summary.taxableGain, 0)
    XCTAssertEqual(summary.lossCarryForward, 0)
  }

  func testCarriesForwardLossesOnlyWhenYearIsNetNegative() throws {
    let result = try TaxYearSummarizer.summarize(disposals: [
      TestSupport.disposal(date: "01/06/2019", gain: -1000),
      TestSupport.disposal(date: "01/06/2020", gain: 13000)
    ])

    XCTAssertEqual(result.summaries.count, 2)
    XCTAssertEqual(result.summaries[0].netGain, -1000)
    XCTAssertEqual(result.summaries[0].lossCarryForward, 1000)
    XCTAssertEqual(result.summaries[1].taxableGain, 0)
    XCTAssertEqual(result.summaries[1].lossCarryForward, 300)
    XCTAssertEqual(result.lossCarryForward, 300)
  }

  func testAppliesLossCarryOnlyAboveExemption() throws {
    let result = try TaxYearSummarizer.summarize(disposals: [
      TestSupport.disposal(date: "01/06/2019", gain: -5000),
      TestSupport.disposal(date: "01/06/2020", gain: 15000)
    ])

    XCTAssertEqual(result.summaries.count, 2)
    let secondYear = result.summaries[1]
    XCTAssertEqual(secondYear.exemption, 12300)
    XCTAssertEqual(secondYear.taxableGain, 0)
    XCTAssertEqual(secondYear.lossCarryForward, 2300)
    XCTAssertEqual(result.lossCarryForward, 2300)
  }

  func testThrowsWhenTaxRatesAreMissingForYear() {
    XCTAssertThrowsError(
      try TaxYearSummarizer.summarize(disposals: [
        TestSupport.disposal(date: "01/06/2012", gain: 100)
      ])) { error in
        guard case TaxRateLookup.LookupError.missingTaxRates(let startYear) = error else {
          return XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(startYear, 2012)
      }
  }
}
