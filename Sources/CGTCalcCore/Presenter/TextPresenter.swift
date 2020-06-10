//
//  TextPresenter.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

import Foundation

public class TextPresenter {
  private let result: CalculatorResult

  public init(result: CalculatorResult) {
    self.result = result
  }

  private func formattedCurrency(_ amount: Decimal) -> String {
    return "£\(amount.rounded(to: 2).string)"
  }

  public func process() throws -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateFormatter.dateFormat = "dd/MM/yyyy"

    var summaryOutput = ""
    var detailsOutput = ""
    try self.result.taxYearSummaries
      .forEach { taxYearSummary in
        guard let taxYearRates = taxYearSummary.taxYear.rates else {
          throw CalculatorError.InternalError("Missing tax year rates for \(taxYearSummary.taxYear)")
        }
        summaryOutput += "Year \(taxYearSummary.taxYear): Gain = \(self.formattedCurrency(taxYearSummary.gain)), Exemption = \(self.formattedCurrency(taxYearRates.exemption))\n"

        detailsOutput += "\n## TAX YEAR \(taxYearSummary.taxYear)\n\n"
        var count = 1
        taxYearSummary.disposalResults
          .forEach { disposalResult in
            detailsOutput += "\(count)) SOLD \(disposalResult.disposal.amount) of \(disposalResult.disposal.asset) on \(dateFormatter.string(from: disposalResult.disposal.date)) for gain of \(self.formattedCurrency(disposalResult.gain))\n"
            detailsOutput += "Matches with:\n"
            disposalResult.disposalMatches.forEach { disposalMatch in
              detailsOutput += "  - \(TextPresenter.disposalMatchDetails(disposalMatch, dateFormatter: dateFormatter))\n"
            }
            detailsOutput += "Calculation: \(TextPresenter.disposalResultCalculationString(disposalResult))\n\n"
            count += 1
          }
        detailsOutput += "\n"
      }

    var output = ""
    output += "# SUMMARY\n\n"
    output += summaryOutput

    output += "\n\n"

    output += "# DETAILS\n"
    output += detailsOutput

    return output
  }
}

extension TextPresenter {

  private static func disposalMatchDetails(_ disposalMatch: DisposalMatch, dateFormatter: DateFormatter) -> String {
    switch disposalMatch.kind {
    case .SameDay(let acquisition):
      return "SAME DAY: \(acquisition.amount) bought on \(dateFormatter.string(from: acquisition.date)) at \(acquisition.price)"
    case .BedAndBreakfast(let acquisition):
      return "BED & BREAKFAST: \(acquisition.amount) bought on \(dateFormatter.string(from: acquisition.date)) at \(acquisition.price)"
    case .Section104(let amountAtDisposal, let costBasis):
      return "SECTION 104: \(amountAtDisposal) at cost basis of £\(costBasis.rounded(to: 5).string)"
    }
  }

  private static func disposalResultCalculationString(_ disposalResult: CalculatorResult.DisposalResult) -> String {
    var output = "(\(disposalResult.disposal.amount) * £\(disposalResult.disposal.price) - £\(disposalResult.disposal.expenses)) - ( "
    var gain = Decimal.zero
    var disposalMatchesStrings: [String] = []
    for disposalMatch in disposalResult.disposalMatches {
      gain += disposalMatch.gain
      switch disposalMatch.kind {
      case .SameDay(let acquisition), .BedAndBreakfast(let acquisition):
        disposalMatchesStrings.append("(\(acquisition.amount) * £\(acquisition.price) + £\(acquisition.expenses))")
      case .Section104(_, let costBasis):
        disposalMatchesStrings.append("(\(disposalMatch.disposal.amount) * £\(costBasis.rounded(to: 5).string))")
      }
    }
    output += disposalMatchesStrings.joined(separator: " + ")
    output += " ) = £\(gain.rounded(to: 2).string)"
    return output
  }

}
