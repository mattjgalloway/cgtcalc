import Foundation

extension Decimal {
  private static let cgtLocale = Locale(identifier: "en_GB")

  /// Parses a decimal using the calculator's fixed locale.
  /// - Parameter string: Numeric text in calculator format.
  /// - Returns: The parsed decimal, or `nil` if invalid.
  static func parse(_ string: String) -> Decimal? {
    Decimal(string: string, locale: self.cgtLocale)
  }

  /// Rounds a decimal to a fixed scale using the supplied rounding mode.
  /// - Parameters:
  ///   - scale: Number of decimal places to keep.
  ///   - roundingMode: Foundation decimal rounding mode.
  /// - Returns: The rounded decimal.
  func rounded(to scale: Int, roundingMode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
    var input = self
    var result: Decimal = .zero
    NSDecimalRound(&result, &input, scale, roundingMode)
    return result
  }

  var string: String {
    var input = self
    return NSDecimalString(&input, Self.cgtLocale)
  }
}
