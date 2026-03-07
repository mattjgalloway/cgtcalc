import Foundation

// MARK: - Tax Year Summarizer

struct TaxYearSummaryResult {
  let summaries: [TaxYearSummary]
  let lossCarryForward: Decimal
}

enum TaxYearSummarizer {
  /// Groups disposals by tax year and applies exemption and carried-loss rules.
  /// - Parameter disposals: Completed disposal records from the engine.
  /// - Returns: Per-year summaries plus the remaining carried loss after the last year.
  static func summarize(disposals: [Disposal]) -> TaxYearSummaryResult {
    let disposalsByYear = Dictionary(grouping: disposals) { $0.taxYear }
    var summaries: [TaxYearSummary] = []
    var lossCarryForward: Decimal = 0

    for (taxYear, yearDisposals) in disposalsByYear.sorted(by: { $0.key < $1.key }) {
      let totalGain = yearDisposals.filter { $0.gain > 0 }.reduce(Decimal(0)) { $0 + $1.gain }
      let totalLoss = yearDisposals.filter { $0.gain < 0 }.reduce(Decimal(0)) { $0 + abs($1.gain) }
      let rawNetGain = totalGain - totalLoss
      let exemption = TaxRateLookup.rates(for: taxYear).exemption

      let netGain = rawNetGain
      var lossAppliedThisYear: Decimal = 0
      let gainAfterExemption = max(Decimal(0), netGain - exemption)

      if gainAfterExemption > 0, lossCarryForward > 0 {
        lossAppliedThisYear = min(lossCarryForward, gainAfterExemption)
        lossCarryForward -= lossAppliedThisYear
      }

      let taxableGain = gainAfterExemption - lossAppliedThisYear

      if rawNetGain < 0 {
        lossCarryForward += abs(rawNetGain)
      }

      summaries.append(TaxYearSummary(
        taxYear: taxYear,
        disposals: yearDisposals,
        totalGain: totalGain,
        totalLoss: totalLoss,
        netGain: rawNetGain,
        exemption: exemption,
        taxableGain: taxableGain,
        lossCarryForward: lossCarryForward))
    }

    return TaxYearSummaryResult(summaries: summaries, lossCarryForward: lossCarryForward)
  }
}
