//
//  CalculatorResult.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

import Foundation

public struct CalculatorResult {
  let taxYearSummaries: [TaxYearSummary]

  struct DisposalResult {
    let disposal: Transaction
    let gain: Decimal
    let disposalMatches: [DisposalMatch]
  }

  struct TaxYearSummary {
    let taxYear: TaxYear
    let gain: Decimal
    let disposalResults: [DisposalResult]
  }

  init(disposalMatches: [DisposalMatch]) {
    self.taxYearSummaries = disposalMatches
      .reduce(into: [TaxYear:[DisposalMatch]]()) { (result, disposalMatch) in
        var disposalMatches = result[disposalMatch.taxYear, default: []]
        disposalMatches.append(disposalMatch)
        result[disposalMatch.taxYear] = disposalMatches
      }
      .map { (taxYear, disposalMatches) in
        var taxYearGain = Decimal.zero
        var transactionsById: [Transaction.Id:Transaction] = [:]
        var disposalMatchesByDisposal: [Transaction.Id:[DisposalMatch]] = [:]
        var gainByDisposal: [Transaction.Id:Decimal] = [:]

        disposalMatches.forEach { disposalMatch in
          let disposal = disposalMatch.disposal.transaction
          transactionsById[disposal.id] = disposal
          taxYearGain += disposalMatch.gain
          var matches = disposalMatchesByDisposal[disposal.id, default: []]
          matches.append(disposalMatch)
          disposalMatchesByDisposal[disposal.id] = matches
          gainByDisposal[disposal.id, default: Decimal.zero] += disposalMatch.gain
        }

        let disposalResults = disposalMatchesByDisposal.map {
          DisposalResult(disposal: transactionsById[$0]!, gain: gainByDisposal[$0]!, disposalMatches: $1)
        }

        return TaxYearSummary(taxYear: taxYear, gain: taxYearGain, disposalResults: disposalResults)
      }
      .sorted { $0.taxYear < $1.taxYear }
  }
}
