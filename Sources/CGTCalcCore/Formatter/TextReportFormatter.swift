import Foundation

// MARK: - Output Formatter

public struct TextReportFormatter {
  public init() {}

  /// Renders a full text report for a calculation result.
  /// - Parameter result: The engine output to render.
  /// - Returns: A human-readable report string.
  public func format(_ result: CalculationResult) -> String {
    let document = ReportDocument(result: result)
    var output = ""

    // Summary section
    output += self.formatSummary(document.taxYears.map(\.summary))

    // Tax year details
    output += "\n\n# TAX YEAR DETAILS\n\n"
    output += self.formatTaxYearDetails(document.taxYears)

    // Tax return information
    output += "\n# TAX RETURN INFORMATION\n\n"
    output += self.formatTaxReturnInfo(document.taxYears.map(\.summary))

    // Holdings
    output += "\n\n# HOLDINGS\n\n"
    output += self.formatHoldings(result.holdings)

    // Spouse transfers out
    if !result.spouseTransfersOut.isEmpty {
      output += "\n\n# SPOUSE TRANSFERS OUT\n\n"
      output += self.formatSpouseTransfersOut(result.spouseTransfersOut)
    }

    // Transactions
    output += "\n\n# TRANSACTIONS\n\n"
    output += self.formatTransactions(result.transactions)

    // Asset events
    output += "\n\n# ASSET EVENTS\n\n"
    output += self.formatAssetEvents(result.assetEvents)

    return output
  }

  // MARK: - Summary

  /// Builds the summary table for all tax years.
  /// - Parameter summaries: Tax-year summaries to display.
  /// - Returns: The rendered summary section.
  private func formatSummary(_ summaries: [TaxYearSummary]) -> String {
    var output = "# SUMMARY\n\n"

    let rows = summaries
      .reduce(into: [[String]]()) { output, summary in
        let gain = self.formatCurrency(summary.netGain)
        let proceeds = self.formatProceeds(summary)
        let exemption = self.formatCurrency(summary.exemption)
        let lossCarry = self.formatCurrency(summary.lossCarryForward)
        let taxable = self.formatCurrency(summary.taxableGain)
        let row = [
          summary.taxYear.label,
          gain,
          proceeds,
          exemption,
          lossCarry,
          taxable
        ]
        output.append(row)
      }

    let headerRow = [
      "Tax year",
      "Gain",
      "Proceeds",
      "Exemption",
      "Loss carry",
      "Taxable gain"
    ]
    let initialMaxWidths = headerRow.map(\.count)
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
    output += header + "\n"
    output += String(repeating: "=", count: header.count) + "\n"
    for row in rows {
      output += builder(row) + "\n"
    }
    return output
  }

  /// Formats total disposal proceeds for a tax year.
  /// - Parameter summary: The tax-year summary to inspect.
  /// - Returns: Rounded proceeds as a currency string.
  private func formatProceeds(_ summary: TaxYearSummary) -> String {
    "\(self.formatCurrency(summary.summaryReportedProceeds))"
  }

  // MARK: - Tax Year Details

  /// Builds the per-tax-year disposal breakdown.
  /// - Parameter summaries: Tax-year summaries to render.
  /// - Returns: The rendered tax-year details section body.
  private func formatTaxYearDetails(_ sections: [TaxYearReportSection]) -> String {
    guard !sections.isEmpty else {
      return ""
    }

    var output = ""

    for section in sections {
      let summary = section.summary
      output += "## TAX YEAR \(summary.taxYear.label)\n\n"

      output += "\(section.gainsCount) gains with total of \(self.formatDecimal(section.totalGains)).\n"
      output += "\(section.lossesCount) losses with total of \(self.formatDecimal(section.totalLosses)).\n\n"

      for (index, entry) in section.disposals.enumerated() {
        let disposal = entry.disposal
        let gainStr = self.formatDecimal(abs(disposal.gain))
        let gainLabel = disposal.gain >= 0 ? "GAIN" : "LOSS"

        output += "\(index + 1)) SOLD \(self.formatDecimal(disposal.sellTransaction.quantity)) of \(disposal.sellTransaction.asset) on \(DateParser.format(disposal.sellTransaction.date)) for \(gainLabel) of £\(gainStr)\n"

        output += "Matches with:\n"

        if !entry.acquisitionMatches.isEmpty {
          for match in entry.acquisitionMatches {
            let matchDate = DateParser.format(match.date)
            let restructureMultiplier = match.restructureMultiplier
            let hasRestructure = restructureMultiplier != 1
            let restructureSuffix = hasRestructure ?
              " with restructure multiplier \(restructureMultiplier.rounded(to: 5).string)" : ""
            let eventOffsetSuffix = match
              .eventAdjustment != 0 ? " with offset of £\(abs(match.eventAdjustment).rounded(to: 2).string)" : ""
            let suffix = restructureSuffix + eventOffsetSuffix
            let label = match.kind == .sameDay ? "SAME DAY" : "BED & BREAKFAST"
            output += "  - \(label): \(self.formatDecimal(match.quantity)) bought on \(matchDate) at £\(self.formatDecimal(match.purchasePrice))\(suffix)\n"
          }
        }

        if let section104 = entry.section104 {
          output += "  - SECTION 104: \(self.formatDecimal(section104.poolQuantity)) at cost basis of £\(section104.averageCost.rounded(to: 5).string)\n"
        }

        let saleExpenses = disposal.sellTransaction.expenses

        var costStr = "( "

        if !entry.acquisitionMatches.isEmpty {
          for (index, match) in entry.acquisitionMatches.enumerated() {
            if index > 0 {
              costStr += " + "
            }
            let eventAdjustmentComponent = match
              .eventAdjustment != 0 ? " + \(match.eventAdjustment.rounded(to: 2).string)" : ""
            costStr += "(\(match.quantity) * \(match.purchasePrice.rounded(to: 5).string) + \(match.purchaseExpenses.rounded(to: 2).string)\(eventAdjustmentComponent))"
          }
        }

        if let section104 = entry.section104 {
          if !entry.acquisitionMatches.isEmpty {
            costStr += " + "
          }
          costStr += "(\(section104.matchedQuantity) * \(section104.averageCost.rounded(to: 5).string))"
        }

        costStr += " )"

        output += "Calculation: (\(self.formatDecimal(disposal.sellTransaction.quantity)) * \(self.formatDecimal(disposal.sellTransaction.price)) - \(self.formatDecimal(saleExpenses))) - \(costStr) = \(self.formatDecimal(disposal.gain))\n"

        output += "\n"
      }
    }

    return output
  }

  // MARK: - Tax Return Info

  /// Builds the tax-return-information section for each tax year.
  /// - Parameter summaries: Tax-year summaries to render.
  /// - Returns: The rendered tax return information section body.
  private func formatTaxReturnInfo(_ summaries: [TaxYearSummary]) -> String {
    var output = ""

    for summary in summaries.sorted(by: { $0.taxYear < $1.taxYear }) {
      let taxReturn = summary.taxReturnMath
      output += "\(summary.taxYear.label): Disposals = \(taxReturn.disposalsCount), proceeds = \(self.formatDecimal(taxReturn.proceeds)), allowable costs = \(self.formatDecimal(TaxMethods.roundedGain(taxReturn.allowableCosts))), total gains = \(self.formatDecimal(taxReturn.totalGains)), total losses = \(self.formatDecimal(taxReturn.totalLosses))\n"

      if let split = taxReturn.specialRateSplit {
        output += "    > Gains to (and inc.) \(split.label) = \(self.formatDecimal(split.gainsToAndIncludingLabelDate)), gains after \(split.label) = \(self.formatDecimal(split.gainsAfterLabelDate))\n"
      }
    }

    return output
  }

  // MARK: - Holdings

  /// Formats final Section 104 holdings by asset.
  /// - Parameter holdings: Final pooled holdings keyed by asset.
  /// - Returns: The rendered holdings section body.
  private func formatHoldings(_ holdings: [String: Section104Holding]) -> String {
    guard !holdings.isEmpty else {
      return "NONE\n"
    }

    var output = ""

    for (asset, holding) in holdings.sorted(by: { $0.key < $1.key }) {
      if holding.quantity > 0 {
        let avgCost = holding.quantity > 0 ? holding.costBasis / holding.quantity : 0
        output += "\(asset): \(self.formatDecimal(holding.quantity)) units acquired at £\(avgCost.rounded(to: 5).string) cost basis\n"
      }
    }

    if output.isEmpty {
      output = "NONE\n"
    }

    return output
  }

  /// Formats `SPOUSEOUT` transfers with the computed no-gain/no-loss cost basis used.
  /// - Parameter spouseTransfersOut: Transfer rows costed by disposal identification ordering.
  /// - Returns: The rendered spouse transfer section body.
  private func formatSpouseTransfersOut(_ spouseTransfersOut: [SpouseTransferOut]) -> String {
    guard !spouseTransfersOut.isEmpty else {
      return "NONE\n"
    }

    var output = ""
    for transfer in spouseTransfersOut {
      let tx = transfer.transaction
      let dateStr = DateParser.format(tx.date)
      output += "\(dateStr) SPOUSEOUT \(self.formatDecimal(tx.quantity)) of \(tx.asset) at transferred cost basis £\(transfer.costBasis.rounded(to: 2).string) (£\(transfer.averageCost.rounded(to: 5).string) per unit, informational)\n"
      output += "Recipient input: SPOUSEIN \(dateStr) \(tx.asset) \(self.formatDecimal(tx.quantity)) TOTALCOST \(self.formatDecimal(transfer.costBasis))\n"
    }
    return output
  }

  // MARK: - Transactions

  /// Formats input transactions in their original input order.
  /// - Parameter transactions: Parsed transactions to display.
  /// - Returns: The rendered transactions section body.
  private func formatTransactions(_ transactions: [Transaction]) -> String {
    guard !transactions.isEmpty else {
      return "NONE\n"
    }

    var output = ""

    for transaction in transactions {
      let dateStr = DateParser.format(transaction.date)
      let line = switch transaction.type {
      case .buy:
        "\(dateStr) BOUGHT \(self.formatDecimal(transaction.quantity)) of \(transaction.asset) at £\(self.formatDecimal(transaction.price)) with £\(self.formatDecimal(transaction.expenses)) expenses"
      case .sell:
        "\(dateStr) SOLD \(self.formatDecimal(transaction.quantity)) of \(transaction.asset) at £\(self.formatDecimal(transaction.price)) with £\(self.formatDecimal(transaction.expenses)) expenses"
      case .spouseIn:
        if let totalCost = transaction.explicitTotalCost {
          "\(dateStr) SPOUSEIN \(self.formatDecimal(transaction.quantity)) of \(transaction.asset) with exact total cost £\(self.formatDecimal(totalCost))"
        } else {
          "\(dateStr) SPOUSEIN \(self.formatDecimal(transaction.quantity)) of \(transaction.asset) at £\(self.formatDecimal(transaction.price)) per unit"
        }
      case .spouseOut:
        "\(dateStr) SPOUSEOUT \(self.formatDecimal(transaction.quantity)) of \(transaction.asset)"
      }
      output += line + "\n"
    }

    return output
  }

  // MARK: - Asset Events

  /// Formats asset events in their original input order.
  /// - Parameter events: Parsed asset events to display.
  /// - Returns: The rendered asset-events section body.
  private func formatAssetEvents(_ events: [AssetEvent]) -> String {
    guard !events.isEmpty else {
      return "NONE\n"
    }

    var output = ""

    for event in events {
      let dateStr = DateParser.format(event.date)

      switch event.kind {
      case .split(let multiplier):
        output += "\(dateStr) \(event.asset) SPLIT by \(self.formatDecimal(multiplier))\n"
      case .unsplit(let multiplier):
        output += "\(dateStr) \(event.asset) UNSPLIT by \(self.formatDecimal(multiplier))\n"
      case .restruct(let oldUnits, let newUnits):
        output += "\(dateStr) \(event.asset) RESTRUCT by \(self.formatDecimal(oldUnits)):\(self.formatDecimal(newUnits))\n"
      case .capitalReturn(let amount, let value):
        output += "\(dateStr) \(event.asset) CAPITAL RETURN on \(self.formatDecimal(amount)) for \(self.formatCurrency(value))\n"
      case .dividend(let amount, let value):
        output += "\(dateStr) \(event.asset) DIVIDEND on \(self.formatDecimal(amount)) for \(self.formatCurrency(value))\n"
      }
    }

    return output
  }

  // MARK: - Formatting Helpers

  /// Formats a decimal as pounds without forcing trailing zeros.
  /// - Parameter value: The amount to format.
  /// - Returns: A string prefixed with `£`.
  private func formatCurrency(_ value: Decimal) -> String {
    "£" + value.rounded(to: 2).string
  }

  private func formatDecimal(_ value: Decimal) -> String {
    value.string
  }
}
