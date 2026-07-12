import Foundation

enum QuantityMaths {
  static let arithmeticDustTolerance = Decimal(1) / 100000000

  static func isArithmeticDust(_ value: Decimal) -> Bool {
    abs(value) <= self.arithmeticDustTolerance
  }

  static func isNearFullPoolConsumption(requested: Decimal, available: Decimal) -> Bool {
    requested > 0 && available > 0 && self.isArithmeticDust(requested - available)
  }

  static func isReconciledMatch(requested: Decimal, matched: Decimal) -> Bool {
    requested > 0 && matched > 0 && self.isArithmeticDust(requested - matched)
  }

  static func normalizingArithmeticZero(_ value: Decimal) -> Decimal {
    self.isArithmeticDust(value) ? 0 : value
  }
}
