import Foundation

class TaxMethods {
  /// Rounds a gain or loss down to whole pounds using the project's reporting rule.
  /// - Parameter gain: Raw gain or loss amount.
  /// - Returns: The rounded whole-pound amount.
  static func roundedGain(_ gain: Decimal) -> Decimal {
    gain.rounded(to: 0, roundingMode: .down)
  }
}
