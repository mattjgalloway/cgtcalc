@testable import CGTCalcCore
import XCTest

final class AssetEventValidatorTests: XCTestCase {
  func testRejectsDividendWithWrongAmount() {
    XCTAssertThrowsError(try AssetEventValidator.validate(
      transactions: [
        TestSupport.buy("01/01/2019", "TEST", 100, 10, 0)
      ],
      assetEvents: [
        TestSupport.dividend("01/03/2019", "TEST", 99, 50)
      ])) { error in
        guard case CalculationError
          .invalidAssetEventAmount(let asset, let date, let type, let expected, let actual) = error
        else {
          return XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(asset, "TEST")
        XCTAssertEqual(DateParser.format(date), "01/03/2019")
        XCTAssertEqual(type, .dividend)
        XCTAssertEqual(expected, 100)
        XCTAssertEqual(actual, 99)
      }
  }

  func testValidatesCapitalReturnAgainstPostDistributionTranche() {
    XCTAssertNoThrow(try AssetEventValidator.validate(
      transactions: [
        TestSupport.buy("01/01/2019", "TEST", 100, 10, 0),
        TestSupport.buy("01/04/2019", "TEST", 20, 12, 0)
      ],
      assetEvents: [
        TestSupport.dividend("01/03/2019", "TEST", 100, 50),
        TestSupport.capReturn("01/05/2019", "TEST", 20, 10)
      ]))
  }

  func testRejectsCapitalReturnWhenAmountDoesNotMatchGroupTwoTranche() {
    XCTAssertThrowsError(try AssetEventValidator.validate(
      transactions: [
        TestSupport.buy("01/01/2019", "TEST", 100, 10, 0),
        TestSupport.buy("01/04/2019", "TEST", 20, 12, 0)
      ],
      assetEvents: [
        TestSupport.dividend("01/03/2019", "TEST", 100, 50),
        TestSupport.capReturn("01/05/2019", "TEST", 120, 10)
      ])) { error in
        guard case CalculationError
          .invalidAssetEventAmount(let asset, let date, let type, let expected, let actual) = error
        else {
          return XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(asset, "TEST")
        XCTAssertEqual(DateParser.format(date), "01/05/2019")
        XCTAssertEqual(type, .capitalReturn)
        XCTAssertEqual(expected, 20)
        XCTAssertEqual(actual, 120)
      }
  }

  func testTreatsEarlierSellsAsReducingOlderPoolBeforeGroupTwoTranche() {
    XCTAssertNoThrow(try AssetEventValidator.validate(
      transactions: [
        TestSupport.buy("01/08/2019", "FOOBAR", 10, 100, 0),
        TestSupport.sell("01/09/2019", "FOOBAR", 5, 105, 0),
        TestSupport.buy("01/01/2020", "FOOBAR", 10, 90, 0),
        TestSupport.buy("01/06/2020", "FOOBAR", 10, 80, 0),
        TestSupport.sell("01/07/2020", "FOOBAR", 5, 100, 0)
      ],
      assetEvents: [
        TestSupport.capReturn("01/04/2020", "FOOBAR", 15, 50),
        TestSupport.dividend("01/04/2020", "FOOBAR", 15, 30),
        TestSupport.capReturn("01/04/2021", "FOOBAR", 10, 10),
        TestSupport.dividend("01/04/2021", "FOOBAR", 20, 40)
      ]))
  }

  func testAllowsSameDayCapitalReturnRowsToSplitTheGroupTwoTranche() {
    XCTAssertNoThrow(try AssetEventValidator.validate(
      transactions: [
        TestSupport.buy("04/12/2020", "TEST", 54.1692, 184.57, 2),
        TestSupport.buy("15/12/2020", "TEST", 6.501, 185.51, 0),
        TestSupport.buy("30/12/2020", "TEST", 6.4686, 186.44, 0),
        TestSupport.buy("10/02/2021", "TEST", 6.4081, 188.2, 0),
        TestSupport.buy("11/03/2021", "TEST", 6.4526, 186.9, 0)
      ],
      assetEvents: [
        TestSupport.capReturn("01/04/2021", "TEST", 54.1692, 63.24),
        TestSupport.capReturn("01/04/2021", "TEST", 25.8303, 30.15)
      ]))
  }

  func testAllowsSameDayDividendRowsToSplitTheHeldQuantity() {
    XCTAssertNoThrow(try AssetEventValidator.validate(
      transactions: [
        TestSupport.buy("01/01/2019", "TEST", 40, 10, 0)
      ],
      assetEvents: [
        TestSupport.dividend("01/03/2019", "TEST", 15, 20),
        TestSupport.dividend("01/03/2019", "TEST", 25, 30)
      ]))
  }

  func testAllowsTinySameDayCapitalReturnRoundingNoise() throws {
    XCTAssertNoThrow(try AssetEventValidator.validate(
      transactions: [
        TestSupport.buy("04/12/2020", "TEST", 54.1692, 184.57, 2),
        TestSupport.buy("15/12/2020", "TEST", 6.501, 185.51, 0),
        TestSupport.buy("30/12/2020", "TEST", 6.4686, 186.44, 0),
        TestSupport.buy("10/02/2021", "TEST", 6.4081, 188.2, 0),
        TestSupport.buy("11/03/2021", "TEST", 6.4526, 186.9, 0)
      ],
      assetEvents: [
        TestSupport.capReturn("01/04/2021", "TEST", 54.1692, 63.24),
        TestSupport.capReturn("01/04/2021", "TEST", XCTUnwrap(Decimal(string: "25.830300001")), 30.15)
      ]))
  }

  func testRejectsCapitalReturnOutsideTolerance() throws {
    XCTAssertThrowsError(try AssetEventValidator.validate(
      transactions: [
        TestSupport.buy("01/01/2019", "TEST", 100, 10, 0)
      ],
      assetEvents: [
        TestSupport.capReturn("01/03/2019", "TEST", XCTUnwrap(Decimal(string: "100.00000002")), 10)
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
        XCTAssertEqual(actual, Decimal(string: "100.00000002"))
      }
  }
}
