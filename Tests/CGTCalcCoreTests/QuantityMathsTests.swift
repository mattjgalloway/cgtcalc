@testable import CGTCalcCore
import XCTest

final class QuantityMathsTests: XCTestCase {
  func testArithmeticDustIncludesExactToleranceBoundary() throws {
    XCTAssertTrue(try QuantityMaths.isArithmeticDust(XCTUnwrap(Decimal.parse("0.00000001"))))
  }

  func testArithmeticDustExcludesValueImmediatelyBeyondTolerance() throws {
    XCTAssertFalse(try QuantityMaths.isArithmeticDust(XCTUnwrap(Decimal.parse("0.0000000100000001"))))
  }

  func testNearFullPoolConsumptionRequiresPositiveAvailableQuantity() throws {
    let tolerance = try XCTUnwrap(Decimal.parse("0.00000001"))

    XCTAssertFalse(QuantityMaths.isNearFullPoolConsumption(requested: tolerance, available: 0))
  }

  func testReconciledMatchRequiresPositiveMatchedQuantity() throws {
    let tolerance = try XCTUnwrap(Decimal.parse("0.00000001"))

    XCTAssertFalse(QuantityMaths.isReconciledMatch(requested: tolerance, matched: 0))
  }
}
