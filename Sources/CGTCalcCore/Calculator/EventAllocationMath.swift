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
}
