//
//  CalculatorResult.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

import Foundation

public struct CalculatorResult {
  let transactions: [Transaction]
  let taxYearSummaries: [TaxYearSummary]

  struct DisposalResult {
    let disposal: Transaction
    let gain: Decimal
    let disposalMatches: [DisposalMatch]
  }

  struct TaxYearSummary {
    let taxYear: TaxYear
    let gain: Decimal
    let taxableGain: Decimal
    let basicRateTax: Decimal
    let higherRateTax: Decimal
    let disposalResults: [DisposalResult]
  }

  init(transactions: [Transaction], disposalMatches: [DisposalMatch]) throws {
    self.transactions = transactions
    self.taxYearSummaries = try disposalMatches
      .reduce(into: [TaxYear:[DisposalMatch]]()) { (result, disposalMatch) in
        var disposalMatches = result[disposalMatch.taxYear, default: []]
        disposalMatches.append(disposalMatch)
        result[disposalMatch.taxYear] = disposalMatches
      }
      .map { (taxYear, disposalMatches) in
        var gain = Decimal.zero
        var transactionsById: [Transaction.Id:Transaction] = [:]
        var disposalMatchesByDisposal: [Transaction.Id:[DisposalMatch]] = [:]
        var gainByDisposal: [Transaction.Id:Decimal] = [:]

        disposalMatches.forEach { disposalMatch in
          let disposal = disposalMatch.disposal.transaction
          transactionsById[disposal.id] = disposal
          gain += disposalMatch.gain
          var matches = disposalMatchesByDisposal[disposal.id, default: []]
          matches.append(disposalMatch)
          disposalMatchesByDisposal[disposal.id] = matches
          gainByDisposal[disposal.id, default: Decimal.zero] += disposalMatch.gain
        }

        let disposalResults =
          disposalMatchesByDisposal.map {
            DisposalResult(disposal: transactionsById[$0]!, gain: gainByDisposal[$0]!, disposalMatches: $1)
          }
          .sorted { $0.disposal.date < $1.disposal.date }

        guard let taxYearRates = taxYear.rates else {
          throw CalculatorError.InternalError("Missing tax year rates for \(taxYear)")
        }
        let taxableGain = max(Decimal.zero, gain - taxYearRates.exemption)
        let basicRateTax = taxableGain * taxYearRates.basicRate * 0.01
        let higherRateTax = taxableGain * taxYearRates.higherRate * 0.01

        return TaxYearSummary(taxYear: taxYear, gain: gain, taxableGain: taxableGain, basicRateTax: basicRateTax, higherRateTax: higherRateTax, disposalResults: disposalResults)
      }
      .sorted { $0.taxYear < $1.taxYear }
  }
}
