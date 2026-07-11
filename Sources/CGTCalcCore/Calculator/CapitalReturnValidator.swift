import Foundation

enum CapitalReturnValidator {
  static let monetaryTolerance = Decimal.parse("0.0001") ?? Decimal(0)

  static func validate(asset: String, date: Date, value: Decimal, availableCost: Decimal) throws {
    guard value <= availableCost + self.monetaryTolerance else {
      throw CalculationError.unsupportedCapitalReturn(
        asset: asset,
        date: date,
        value: value,
        availableCost: availableCost)
    }
  }
}
