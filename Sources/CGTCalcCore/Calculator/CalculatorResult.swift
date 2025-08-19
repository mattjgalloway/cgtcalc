//
//  CalculatorResult.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

import Foundation

public struct CalculatorResult {
  let input: CalculatorInput
  let taxYearSummaries: [TaxYearSummary]

  struct DisposalResult {
    let disposal: Transaction
    let gain: Decimal
    let disposalMatches: [DisposalMatch]
  }

  struct TaxYearSummary {
    let taxYear: TaxYear
    let gain: Decimal
    let proceeds: Decimal
    let allowableCosts: Decimal
    let exemption: Decimal
    let carryForwardLoss: Decimal
    let taxableGain: Decimal
    let basicRateTax: Decimal
    let higherRateTax: Decimal
    let disposalResults: [DisposalResult]
  }

  init(input: CalculatorInput, disposalMatches: [DisposalMatch]) throws {
    self.input = input

    var carryForwardLoss = Decimal.zero
    self.taxYearSummaries = try disposalMatches
      .reduce(into: [TaxYear: [DisposalMatch]]()) { result, disposalMatch in
        var disposalMatches = result[disposalMatch.taxYear, default: []]
        disposalMatches.append(disposalMatch)
        result[disposalMatch.taxYear] = disposalMatches
      }
      .sorted { $0.key < $1.key }
      .map { taxYear, disposalMatches in
        var disposalMatchesByDisposal: [Transaction: [DisposalMatch]] = [:]
        var gainByDisposal: [Transaction: Decimal] = [:]

        var totalProceeds = Decimal.zero
        var totalAllowableCosts = Decimal.zero

        disposalMatches.forEach { disposalMatch in
          let disposal = disposalMatch.disposal.transaction
          var matches = disposalMatchesByDisposal[disposal, default: []]
          matches.append(disposalMatch)
          disposalMatchesByDisposal[disposal] = matches
          gainByDisposal[disposal, default: Decimal.zero] += disposalMatch.gain
          totalProceeds += disposalMatch.disposal.value
          totalAllowableCosts += disposalMatch.allowableCosts
        }

        var totalGain = Decimal.zero
        let disposalResults =
          disposalMatchesByDisposal.map { disposal, disposalMatches -> DisposalResult in
            let roundedGain = TaxMethods.roundedGain(gainByDisposal[disposal]!)
            totalGain += roundedGain
            return DisposalResult(disposal: disposal, gain: roundedGain, disposalMatches: disposalMatches)
          }
          .sorted {
            if $0.disposal.date == $1.disposal.date {
              return $0.disposal.asset < $1.disposal.asset
            }
            return $0.disposal.date < $1.disposal.date
          }

        guard let taxYearRates = TaxYear.rates[taxYear] else {
          throw CalculatorError.InternalError("Missing tax year rates for \(taxYear)")
        }

        let taxableGain: Decimal
        let gainAboveExemption = max(totalGain - taxYearRates.exemption, Decimal.zero)
        if !gainAboveExemption.isZero {
          let lossUsed = min(gainAboveExemption, carryForwardLoss)
          taxableGain = gainAboveExemption - lossUsed
          carryForwardLoss -= lossUsed
        } else {
          taxableGain = Decimal.zero
          if totalGain.isSignMinus {
            carryForwardLoss -= totalGain
          }
        }
        let basicRateTax = TaxMethods.roundedGain(taxableGain * taxYearRates.basicRate * 0.01)
        let higherRateTax = TaxMethods.roundedGain(taxableGain * taxYearRates.higherRate * 0.01)

        return TaxYearSummary(
          taxYear: taxYear,
          gain: totalGain,
          proceeds: TaxMethods.roundedGain(totalProceeds),
          allowableCosts: TaxMethods.roundedGain(totalAllowableCosts),
          exemption: taxYearRates.exemption,
          carryForwardLoss: carryForwardLoss,
          taxableGain: taxableGain,
          basicRateTax: basicRateTax,
          higherRateTax: higherRateTax,
          disposalResults: disposalResults)
      }
  }
}
