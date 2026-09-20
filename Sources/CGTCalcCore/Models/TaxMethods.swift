import Foundation

class TaxMethods {
  /// Rounds a gain or loss down to whole pounds using the project's reporting rule.
  /// - Parameter gain: Raw gain or loss amount.
  /// - Returns: The rounded whole-pound amount.
  static func roundedGain(_ gain: Decimal) -> Decimal {
    gain.rounded(to: 0, roundingMode: .down)
  }

  /// Rounds an income-like figure (proceeds, gains) DOWN to whole pounds.
  /// HMRC's Self Assessment convention (SAM121370) rounds amounts of income down.
  static func roundedDownIncome(_ value: Decimal) -> Decimal {
    value.rounded(to: 0, roundingMode: .down)
  }

  /// Rounds a cost-like figure (allowable costs, expenses, losses in magnitude) UP to whole
  /// pounds. HMRC's Self Assessment convention (SAM121370) rounds amounts of expenses and
  /// reliefs up. Rounding proceeds/gains down and costs/losses up is taxpayer-favourable and,
  /// applied consistently, keeps the tax-return boxes reconciled
  /// (proceeds − costs = gains − losses).
  static func roundedUpCost(_ value: Decimal) -> Decimal {
    value.rounded(to: 0, roundingMode: .up)
  }
}
