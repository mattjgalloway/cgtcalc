import Foundation

/// Controls how whole-pound rounding is applied when deriving tax-return figures.
public enum RoundingMode: String, Sendable {
  /// Round every disposal to whole pounds, then sum. Matches HMRC's HS284 worked
  /// examples. The four tax-return boxes may not satisfy
  /// proceeds - costs = gains - losses because each is rounded independently.
  case perDisposal

  /// Keep full precision per disposal and round only the aggregate box totals.
  /// Guarantees proceeds - costs = gains - losses, which the HMRC online form checks.
  case aggregate

  /// Human-readable description for report output, so a rendered report states which
  /// rounding mode produced its figures.
  public var reportLabel: String {
    switch self {
    case .perDisposal:
      "per-disposal (each disposal rounded to whole pounds, then summed; HS284 style)"
    case .aggregate:
      "aggregate (full precision kept; only the return totals rounded, HMRC directional)"
    }
  }
}

struct TaxReturnMath {
  struct SpecialRateSplit {
    let label: String
    let gainsToAndIncludingLabelDate: Decimal
    let gainsAfterLabelDate: Decimal
  }

  let disposalsCount: Int
  let proceeds: Decimal
  let allowableCosts: Decimal
  let totalGains: Decimal
  let totalLosses: Decimal
  let specialRateSplit: SpecialRateSplit?
}

extension TaxYearSummary {
  /// Summary-table proceeds are reported as the sum of disposal-level rounded proceeds.
  func summaryReportedProceeds(rounding: RoundingMode = .perDisposal) -> Decimal {
    switch rounding {
    case .perDisposal:
      return self.disposals.reduce(Decimal(0)) { total, disposal in
        total + TaxMethods.roundedGain(disposal.rawProceeds)
      }
    case .aggregate:
      let rawTotal = self.disposals.reduce(Decimal(0)) { $0 + $1.rawProceeds }
      return TaxMethods.roundedDownIncome(rawTotal)
    }
  }

  /// Summary-table proceeds using the default per-disposal rounding.
  var summaryReportedProceeds: Decimal {
    self.summaryReportedProceeds(rounding: .perDisposal)
  }

  /// The net gain (gains − losses) as reported for the tax return under the given rounding
  /// mode, so the SUMMARY "Gain" column matches the TAX RETURN INFORMATION section
  /// (`total gains − total losses`) rather than diverging from it. Per-disposal mode reproduces
  /// the historic value (each disposal rounded down, then summed).
  func reportedNetGain(rounding: RoundingMode) -> Decimal {
    let math = self.taxReturnMath(rounding: rounding)
    return math.totalGains - math.totalLosses
  }

  /// The taxable gain consistent with `reportedNetGain(rounding:)`: the reported net gain less
  /// the annual exemption and the losses actually brought forward and used this year. The
  /// loss-carry amount applied this year is recovered from the engine's own figures
  /// (`max(0, rawNetGain − exemption) − rawTaxableGain`), so the cross-year carry chain is not
  /// re-derived here.
  func reportedTaxableGain(rounding: RoundingMode) -> Decimal {
    let reportedNet = self.reportedNetGain(rounding: rounding)
    let rawGainAfterExemption = max(Decimal(0), self.netGain - self.exemption)
    let lossAppliedThisYear = rawGainAfterExemption - self.taxableGain
    let reportedGainAfterExemption = max(Decimal(0), reportedNet - self.exemption)
    return max(Decimal(0), reportedGainAfterExemption - lossAppliedThisYear)
  }

  /// HMRC tax-return figures derived from disposals in this tax year, using the default
  /// per-disposal rounding.
  var taxReturnMath: TaxReturnMath {
    self.taxReturnMath(rounding: .perDisposal)
  }

  /// HMRC tax-return figures derived from disposals in this tax year.
  /// - Parameter rounding: Whether to round per disposal (HMRC example style) or only the
  ///   aggregate totals (so the four boxes reconcile).
  func taxReturnMath(rounding: RoundingMode) -> TaxReturnMath {
    let proceeds: Decimal
    let allowableCosts: Decimal
    let totalGains: Decimal
    let totalLosses: Decimal

    switch rounding {
    case .perDisposal:
      proceeds = self.disposals.reduce(Decimal(0)) { total, disposal in
        total + TaxMethods.roundedGain(disposal.rawProceeds)
      }
      allowableCosts = self.disposals.reduce(Decimal(0)) { total, disposal in
        total + TaxMethods.roundedGain(disposal.rawAllowableCosts)
      }
      totalGains = self.disposals
        .filter { $0.rawGain > 0 }
        .reduce(Decimal(0)) { $0 + TaxMethods.roundedGain($1.rawGain) }
      totalLosses = self.disposals
        .filter { $0.rawGain < 0 }
        .reduce(Decimal(0)) { $0 + abs(TaxMethods.roundedGain($1.rawGain)) }
    case .aggregate:
      // HMRC's Capital Gains Manual (CG14200) says the computation should retain full precision;
      // only the final figures entered on the return are rounded to whole pounds. The Self
      // Assessment rounding convention (SAM121370) then rounds income-like amounts DOWN
      // (disposal proceeds, gains) and cost/relief-like amounts UP (allowable costs, losses) —
      // always in the taxpayer's favour.
      //
      // We therefore keep every disposal at full decimal precision, sum, and round only these
      // four aggregate totals, each in its HMRC direction:
      //   proceeds       -> round DOWN   (income)
      //   allowable costs -> round UP     (expenditure)
      //   gains          -> round DOWN   (income)
      //   losses         -> round UP     (relief)
      //
      // Note on reconciliation: at full precision proceeds − costs = gains − losses exactly.
      // Because each of the four totals is rounded independently in its HMRC direction, the two
      // sides can differ by at most £1 (always in the taxpayer's favour). This can happen in any
      // year — wholly gains, wholly losses, or mixed — depending on the fractional parts.
      // HMRC's online form rounds each box client-side and warns if proceeds − costs ≠
      // gains − losses; where a £1 artefact triggers that warning it is expected and can be
      // safely accepted, since each figure is rounded exactly as HMRC's convention directs. We
      // deliberately do not fudge a box to force reconciliation, so every reported figure is the
      // correct HMRC-rounded value.
      proceeds = TaxMethods.roundedDownIncome(
        self.disposals.reduce(Decimal(0)) { $0 + $1.rawProceeds })
      allowableCosts = TaxMethods.roundedUpCost(
        self.disposals.reduce(Decimal(0)) { $0 + $1.rawAllowableCosts })
      totalGains = TaxMethods.roundedDownIncome(
        self.disposals.filter { $0.rawGain > 0 }.reduce(Decimal(0)) { $0 + $1.rawGain })
      totalLosses = TaxMethods.roundedUpCost(
        self.disposals.filter { $0.rawGain < 0 }.reduce(Decimal(0)) { $0 + abs($1.rawGain) })
    }

    let specialRateSplit: TaxReturnMath.SpecialRateSplit?
    if let cutoff = self.taxYear.specialCapitalGainsRateChangeLastOldRateDate,
       let label = self.taxYear.specialCapitalGainsRateChangeLabel
    {
      let gainsToAndIncludingLabelDate = self.disposals
        .filter { $0.gain > 0 && $0.sellTransaction.date <= cutoff }
        .reduce(Decimal(0)) { $0 + $1.gain }
      let gainsAfterLabelDate = self.disposals
        .filter { $0.gain > 0 && $0.sellTransaction.date > cutoff }
        .reduce(Decimal(0)) { $0 + $1.gain }
      specialRateSplit = TaxReturnMath.SpecialRateSplit(
        label: label,
        gainsToAndIncludingLabelDate: gainsToAndIncludingLabelDate,
        gainsAfterLabelDate: gainsAfterLabelDate)
    } else {
      specialRateSplit = nil
    }

    return TaxReturnMath(
      disposalsCount: self.disposals.count,
      proceeds: proceeds,
      allowableCosts: allowableCosts,
      totalGains: totalGains,
      totalLosses: totalLosses,
      specialRateSplit: specialRateSplit)
  }
}
