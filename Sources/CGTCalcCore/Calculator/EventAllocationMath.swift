import Foundation

enum EventAllocationMath {
  /// Event allocations use nearest rounding at ten decimal places before entering cost-basis calculations.
  static let monetaryScale = 10
  static let precisionUnit = Decimal.parse("0.0000000001") ?? Decimal(0)

  static func proportionalValue(eventValue: Decimal, destinationQuantity: Decimal,
                                eligibleQuantity: Decimal) -> Decimal
  {
    guard eventValue > 0, destinationQuantity > 0, eligibleQuantity > 0 else { return 0 }
    return (eventValue * destinationQuantity / eligibleQuantity).rounded(to: self.monetaryScale)
  }

  static func cumulativeValue(totalValue: Decimal, allocatedQuantity: Decimal, totalQuantity: Decimal) -> Decimal {
    guard totalValue > 0, allocatedQuantity > 0, totalQuantity > 0 else { return 0 }
    guard allocatedQuantity < totalQuantity else { return totalValue }
    return self.proportionalValue(
      eventValue: totalValue,
      destinationQuantity: allocatedQuantity,
      eligibleQuantity: totalQuantity)
  }
}
