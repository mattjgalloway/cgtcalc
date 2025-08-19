//
//  TaxYearPostProcessor.swift
//  cgtcalc
//
//  Created by Matt Galloway on 19/08/2025.
//

import Foundation

protocol TaxYearPostProcessor {
  func extraTaxReturnInformation(for summary: CalculatorResult.TaxYearSummary) -> String
}

struct TaxYearPostProcessor20242025: TaxYearPostProcessor {
  func extraTaxReturnInformation(for summary: CalculatorResult.TaxYearSummary) -> String {
    // In 2024-25 tax year there was a change where the rate of tax changed for disposals on or after 30th October 2024
    let cutOffDate = Date(timeIntervalSince1970: 1730246400) // 30th October 2024 00:00:00 UTC

    let gainsUpToCutOff = summary.disposalResults
      .filter { $0.disposal.date < cutOffDate && !$0.gain.isSignMinus }
      .reduce(Decimal.zero) { $0 + $1.gain }
    let gainsAfterCutOff = summary.disposalResults
      .filter { $0.disposal.date >= cutOffDate && !$0.gain.isSignMinus }
      .reduce(Decimal.zero) { $0 + $1.gain }

    return "Gains to (and inc.) 29th October = \(gainsUpToCutOff), gains after 29th October = \(gainsAfterCutOff)"
  }
}
