@testable import CGTCalcCore
import XCTest

final class AssetEventGrouperTests: XCTestCase {
  func testGroupsSameAssetDayAndTypeBySummingAmountAndValue() {
    let events = [
      TestSupport.dividend("15/06/2020", "TEST", 25, 2),
      TestSupport.dividend("15/06/2020", "TEST", 75, 9)
    ]

    let grouped = AssetEventGrouper.groupDistributions(events)

    XCTAssertEqual(grouped.count, 1)
    XCTAssertEqual(grouped[0].distributionAmount, 100)
    XCTAssertEqual(grouped[0].distributionValue, 11)
  }

  func testKeepsDividendAndCapitalReturnAsSeparateLogicalEvents() {
    let events = [
      TestSupport.dividend("15/06/2020", "TEST", 50, 5),
      TestSupport.capReturn("15/06/2020", "TEST", 50, 3),
      TestSupport.dividend("15/06/2020", "TEST", 50, 6),
      TestSupport.capReturn("15/06/2020", "TEST", 50, 4)
    ]

    let grouped = AssetEventGrouper.groupDistributions(events)

    XCTAssertEqual(grouped.count, 2)
    XCTAssertEqual(grouped[0].distributionType, .dividend)
    XCTAssertEqual(grouped[0].distributionAmount, 100)
    XCTAssertEqual(grouped[0].distributionValue, 11)
    XCTAssertEqual(grouped[1].distributionType, .capitalReturn)
    XCTAssertEqual(grouped[1].distributionAmount, 100)
    XCTAssertEqual(grouped[1].distributionValue, 7)
  }

  func testEmitsDividendBeforeCapitalReturnRegardlessOfInputOrder() {
    let capitalReturn = TestSupport.capReturn("15/06/2020", "TEST", 100, 3, sourceOrder: 0)
    let dividend = TestSupport.dividend("15/06/2020", "TEST", 200, 5, sourceOrder: 1)

    for events in [[capitalReturn, dividend], [dividend, capitalReturn]] {
      let grouped = AssetEventGrouper.groupDistributions(events)

      XCTAssertEqual(grouped.map(\.distributionType), [.dividend, .capitalReturn])
    }
  }

  func testKeepsDifferentAssetsAndDaysSeparate() {
    let events = [
      TestSupport.dividend("15/06/2020", "AAA", 100, 5),
      TestSupport.dividend("15/06/2020", "BBB", 100, 6),
      TestSupport.dividend("16/06/2020", "AAA", 100, 7)
    ]

    XCTAssertEqual(AssetEventGrouper.groupDistributions(events).count, 3)
  }
}
