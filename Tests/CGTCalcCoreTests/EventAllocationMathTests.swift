@testable import CGTCalcCore
import XCTest

final class EventAllocationMathTests: XCTestCase {
  func testNormalizesRepeatingProportionsToTenDecimalPlaces() {
    XCTAssertEqual(
      EventAllocationMath.proportionalValue(eventValue: 90, destinationQuantity: 1, eligibleQuantity: 3),
      30)
    XCTAssertEqual(
      EventAllocationMath.proportionalValue(eventValue: 90, destinationQuantity: 2, eligibleQuantity: 3),
      60)
    XCTAssertEqual(
      EventAllocationMath.proportionalValue(eventValue: 100, destinationQuantity: 1, eligibleQuantity: 7),
      Decimal.parse("14.2857142857"))
  }

  func testDoesNotSnapMeaningfulValuesAcrossWholePoundBoundary() throws {
    XCTAssertEqual(
      try EventAllocationMath.proportionalValue(
        eventValue: XCTUnwrap(Decimal.parse("89.999997")),
        destinationQuantity: 1,
        eligibleQuantity: 3),
      Decimal.parse("29.999999"))
    XCTAssertEqual(
      try EventAllocationMath.proportionalValue(
        eventValue: XCTUnwrap(Decimal.parse("90.000003")),
        destinationQuantity: 1,
        eligibleQuantity: 3),
      Decimal.parse("30.000001"))
  }
}
