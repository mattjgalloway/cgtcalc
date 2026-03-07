import Foundation

extension Decimal {
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
    return NSDecimalString(&input, nil)
  }
}
