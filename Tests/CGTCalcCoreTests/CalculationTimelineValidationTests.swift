@testable import CGTCalcCore
import XCTest

final class CalculationTimelineValidationTests: XCTestCase {
  func testRejectsTransactionAndDistributionCombinationsConsistently() {
    let transactions = [
      TestSupport.buy("01/01/2020", "TEST", 100, 1, 0),
      TestSupport.sell("01/01/2020", "TEST", 10, 2, 0),
      TestSupport.spouseIn("01/01/2020", "TEST", 100, 1),
      TestSupport.spouseOut("01/01/2020", "TEST", 10)
    ]
    let events = [
      TestSupport.dividend("01/01/2020", "TEST", 100, 10),
      TestSupport.capReturn("01/01/2020", "TEST", 100, 10)
    ]

    for transaction in transactions {
      for event in events {
        self.assertUnsupported(transactions: [transaction], events: [event])
      }
    }
  }

  func testRejectsRestructureCombinedWithAnyOtherSameDateRow() throws {
    let restructures = try [
      AssetEvent(type: .split, date: TestSupport.date("01/01/2020"), asset: "TEST", multiplier: 2),
      AssetEvent(type: .unsplit, date: TestSupport.date("01/01/2020"), asset: "TEST", multiplier: 2),
      AssetEvent(date: TestSupport.date("01/01/2020"), asset: "TEST", oldUnits: 3, newUnits: 7)
    ]
    let transaction = TestSupport.buy("01/01/2020", "TEST", 100, 1, 0)
    let distribution = TestSupport.dividend("01/01/2020", "TEST", 100, 10)

    for restructure in restructures {
      self.assertUnsupported(transactions: [transaction], events: [restructure])
      self.assertUnsupported(transactions: [], events: [restructure, distribution])
    }
    for firstIndex in restructures.indices {
      for secondIndex in restructures.indices where firstIndex != secondIndex {
        self.assertUnsupported(
          transactions: [],
          events: [restructures[firstIndex], restructures[secondIndex]])
      }
    }
  }

  func testAllowsOneRestructureWithSameDateOutboundsOnPostRestructureBasis() throws {
    let restructure = try AssetEvent(
      type: .unsplit,
      date: TestSupport.date("01/01/2020"),
      asset: "TEST",
      multiplier: 2)
    let outbounds = [
      TestSupport.sell("01/01/2020", "TEST", 10, 2, 0),
      TestSupport.spouseOut("01/01/2020", "TEST", 5)
    ]

    XCTAssertNoThrow(try CalculationTimeline.validateSameDateCombinations(
      transactions: outbounds,
      assetEvents: [restructure]))
  }

  func testAmbiguousRowsForDifferentAssetsRemainIndependent() throws {
    let transaction = TestSupport.buy("01/01/2020", "AAA", 100, 1, 0)
    let event = TestSupport.dividend("01/01/2020", "BBB", 100, 10)

    XCTAssertNoThrow(try CalculationTimeline.validateSameDateCombinations(
      transactions: [transaction],
      assetEvents: [event]))
  }

  private func assertUnsupported(transactions: [Transaction], events: [AssetEvent]) {
    for transactionRows in [transactions, Array(transactions.reversed())] {
      for eventRows in [events, Array(events.reversed())] {
        XCTAssertThrowsError(try CalculationTimeline.validateSameDateCombinations(
          transactions: Array(transactionRows),
          assetEvents: Array(eventRows)))
        { error in
          guard case CalculationError.unsupportedSameDateCombination(
            let asset,
            let date,
            let rowTypes) = error
          else {
            return XCTFail("Unexpected error: \(error)")
          }
          XCTAssertEqual(asset, "TEST")
          XCTAssertEqual(date, TestSupport.date("01/01/2020"))
          XCTAssertEqual(rowTypes, rowTypes.sorted())
        }
      }
    }
  }
}
