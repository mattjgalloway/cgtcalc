@testable import CGTCalcCore
import XCTest

final class SameDayDisposalMergerTests: XCTestCase {
  func testMergesSameAssetSameDaySells() {
    let merged = SameDayDisposalMerger.merge([
      TestSupport.sell("28/10/2018", "TEST", 10, 7, 12.5),
      TestSupport.sell("28/10/2018", "TEST", 10, 9, 2),
      TestSupport.buy("28/08/2018", "TEST", 10, 5, 12.5)
    ])

    XCTAssertEqual(merged.count, 1)
    XCTAssertEqual(merged[0].quantity, 20)
    XCTAssertEqual(merged[0].price, 8, accuracy: 0.00001)
    XCTAssertEqual(merged[0].expenses, 14.5, accuracy: 0.00001)
  }

  func testKeepsDifferentAssetsAsSeparateDisposals() {
    let merged = SameDayDisposalMerger.merge([
      TestSupport.sell("28/10/2018", "AAA", 10, 7, 1),
      TestSupport.sell("28/10/2018", "BBB", 10, 9, 2),
      TestSupport.sell("28/10/2018", "AAA", 5, 11, 3)
    ])

    XCTAssertEqual(merged.count, 2)
    XCTAssertEqual(merged[0].asset, "AAA")
    XCTAssertEqual(merged[0].quantity, 15)
    XCTAssertEqual(merged[1].asset, "BBB")
    XCTAssertEqual(merged[1].quantity, 10)
  }

  func testPreservesFirstAppearanceOrderForInterleavedInput() {
    let merged = SameDayDisposalMerger.merge([
      TestSupport.buy("28/08/2018", "AAA", 10, 5, 0),
      TestSupport.sell("28/10/2018", "BBB", 10, 9, 2),
      TestSupport.sell("28/10/2018", "AAA", 10, 7, 1),
      TestSupport.sell("28/10/2018", "BBB", 5, 11, 3)
    ])

    XCTAssertEqual(merged.map(\.asset), ["BBB", "AAA"])
    XCTAssertEqual(merged[0].quantity, 15)
    XCTAssertEqual(merged[1].quantity, 10)
  }
}
