//
//  TextPresenter.swift
//  cgtcalc
//
//  Created by Matt Galloway on 08/06/2020.
//

import Foundation

public class TextPresenter: Presenter {
  private let result: CalculatorResult
  private let dateFormatter: DateFormatter

  public required init(result: CalculatorResult) {
    self.result = result
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateFormatter.dateFormat = "dd/MM/yyyy"
    self.dateFormatter = dateFormatter
  }

  public func process() throws -> PresenterResult {
    var output = ""
    output += "# SUMMARY\n\n"
    output += self.summaryTable()

    output += "\n\n"

    output += "# TAX YEAR DETAILS\n\n"
    output += self.detailsOutput()

    output += "\n"

    output += "# TRANSACTIONS\n\n"
    output += self.transactionsTable()

    output += "\n\n"

    output += "# ASSET EVENTS\n\n"
    output += self.assetEventsTable()

    return .string(output)
  }

  private func formattedCurrency(_ amount: Decimal) -> String {
    return "£\(amount.rounded(to: 2).string)"
  }

  private func summaryTable() -> String {
    let rows = self.result.taxYearSummaries
      .reduce(into: [[String]]()) { output, summary in
        let row = [
          summary.taxYear.string,
          self.formattedCurrency(summary.gain),
          self.formattedCurrency(summary.proceeds),
          self.formattedCurrency(summary.exemption),
          self.formattedCurrency(summary.carryForwardLoss),
          self.formattedCurrency(summary.taxableGain),
          self.formattedCurrency(summary.basicRateTax),
          self.formattedCurrency(summary.higherRateTax)
        ]
        output.append(row)
      }

    let headerRow = [
      "Tax year",
      "Gain",
      "Proceeds",
      "Exemption",
      "Loss carry",
      "Taxable gain",
      "Tax (basic)",
      "Tax (higher)"
    ]
    let initialMaxWidths = headerRow.map { $0.count }
    let maxWidths = rows.reduce(into: initialMaxWidths) { result, row in
      for i in 0 ..< result.count {
        result[i] = max(result[i], row[i].count)
      }
    }

    let builder = { (input: [String]) -> String in
      var out: [String] = []
      for (i, column) in input.enumerated() {
        out.append(column.padding(toLength: maxWidths[i], withPad: " ", startingAt: 0))
      }
      return out.joined(separator: "   ")
    }

    let header = builder(headerRow)
    var output = header + "\n"
    output += String(repeating: "=", count: header.count) + "\n"
    for row in rows {
      output += builder(row) + "\n"
    }
    return output
  }

  private func detailsOutput() -> String {
    return self.result.taxYearSummaries
      .reduce(into: "") { output, summary in
        output += "## TAX YEAR \(summary.taxYear)\n\n"

        let gains = summary.disposalResults.filter({$0.gain >= 0})
        output += "\(gains.count) gains with total of \(gains.reduce(Decimal.zero) {$0 + $1.gain}).\n"

        let losses = summary.disposalResults.filter({$0.gain < 0})
        output += "\(losses.count) losses with total of \(losses.reduce(Decimal.zero) {$0 - $1.gain}).\n"

        output += "\n"

        var count = 1
        summary.disposalResults
          .forEach { disposalResult in
            output += "\(count)) SOLD \(disposalResult.disposal.amount)"
            output += " of \(disposalResult.disposal.asset)"
            output += " on \(self.dateFormatter.string(from: disposalResult.disposal.date))"
            output += " for "
            output += disposalResult.gain.isSignMinus ? "LOSS" : "GAIN"
            output +=
              " of \(self.formattedCurrency(disposalResult.gain * (disposalResult.gain.isSignMinus ? -1 : 1)))\n"
            output += "Matches with:\n"
            disposalResult.disposalMatches.forEach { disposalMatch in
              output += "  - \(TextPresenter.disposalMatchDetails(disposalMatch, dateFormatter: self.dateFormatter))\n"
            }
            output += "Calculation: \(TextPresenter.disposalResultCalculationString(disposalResult))\n\n"
            count += 1
          }
      }
  }

  private func transactionsTable() -> String {
    guard self.result.input.transactions.count > 0 else {
      return "NONE"
    }

    return self.result.input.transactions.reduce(into: "") { result, transaction in
      result += "\(dateFormatter.string(from: transaction.date)) "
      switch transaction.kind {
      case .Buy:
        result += "BOUGHT "
      case .Sell:
        result += "SOLD "
      }
      result +=
        "\(transaction.amount) of \(transaction.asset) at £\(transaction.price) with £\(transaction.expenses) expenses\n"
    }
  }

  private func assetEventsTable() -> String {
    guard self.result.input.assetEvents.count > 0 else {
      return "NONE"
    }

    return self.result.input.assetEvents.reduce(into: "") { result, assetEvent in
      result += "\(dateFormatter.string(from: assetEvent.date)) \(assetEvent.asset) "
      switch assetEvent.kind {
      case .CapitalReturn(let amount, let value):
        result += "CAPITAL RETURN on \(amount) for \(self.formattedCurrency(value))"
      case .Dividend(let amount, let value):
        result += "DIVIDEND on \(amount) for \(self.formattedCurrency(value))"
      case .Split(let multiplier):
        result += "SPLIT by \(multiplier)"
      case .Unsplit(let multiplier):
        result += "UNSPLIT by \(multiplier)"
      }
      result += "\n"
    }
  }
}

extension TextPresenter {
  private static func disposalMatchDetails(_ disposalMatch: DisposalMatch, dateFormatter: DateFormatter) -> String {
    switch disposalMatch.kind {
    case .SameDay(let acquisition):
      var output =
        "SAME DAY: \(acquisition.amount) bought on \(dateFormatter.string(from: acquisition.date)) at £\(acquisition.price)"
      if !acquisition.offset.isZero {
        output += " with offset of £\(acquisition.offset)"
      }
      return output
    case .BedAndBreakfast(let acquisition):
      var output =
        "BED & BREAKFAST: \(acquisition.amount) bought on \(dateFormatter.string(from: acquisition.date)) at £\(acquisition.price)"
      if !acquisition.offset.isZero {
        output += " with offset of £\(acquisition.offset)"
      }
      if disposalMatch.restructureMultiplier != Decimal(1) {
        output += " with restructure multiplier \(disposalMatch.restructureMultiplier)"
      }
      return output
    case .Section104(let amountAtDisposal, let costBasis):
      return "SECTION 104: \(amountAtDisposal) at cost basis of £\(costBasis.rounded(to: 5).string)"
    }
  }

  private static func disposalResultCalculationString(_ disposalResult: CalculatorResult.DisposalResult) -> String {
    var output =
      "(\(disposalResult.disposal.amount) * \(disposalResult.disposal.price) - \(disposalResult.disposal.expenses)) - ( "
    var disposalMatchesStrings: [String] = []
    for disposalMatch in disposalResult.disposalMatches {
      switch disposalMatch.kind {
      case .SameDay(let acquisition), .BedAndBreakfast(let acquisition):
        var output = "(\(acquisition.amount) * \(acquisition.price) + \(acquisition.expenses)"
        if !acquisition.offset.isZero {
          output += " + \(acquisition.offset)"
        }
        output += ")"
        disposalMatchesStrings.append(output)
      case .Section104(_, let costBasis):
        disposalMatchesStrings.append("(\(disposalMatch.disposal.amount) * \(costBasis.rounded(to: 5).string))")
      }
    }
    output += disposalMatchesStrings.joined(separator: " + ")
    output += " ) = \(disposalResult.gain)"
    return output
  }
}
