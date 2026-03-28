import Foundation

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
  var summaryReportedProceeds: Decimal {
    self.disposals.reduce(Decimal(0)) { total, disposal in
      total + TaxMethods.roundedGain(disposal.rawProceeds)
    }
  }

  /// HMRC tax-return figures derived from disposals in this tax year.
  var taxReturnMath: TaxReturnMath {
    let proceeds = self.disposals.reduce(Decimal(0)) { total, disposal in
      total + TaxMethods.roundedGain(disposal.rawProceeds)
    }
    let allowableCosts = self.disposals.reduce(Decimal(0)) { total, disposal in
      total + TaxMethods.roundedGain(disposal.rawAllowableCosts)
    }
    let totalGains = self.disposals
      .filter { $0.rawGain > 0 }
      .reduce(Decimal(0)) { $0 + TaxMethods.roundedGain($1.rawGain) }
    let totalLosses = self.disposals
      .filter { $0.rawGain < 0 }
      .reduce(Decimal(0)) { $0 + TaxMethods.roundedGain(abs($1.rawGain)) }

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
