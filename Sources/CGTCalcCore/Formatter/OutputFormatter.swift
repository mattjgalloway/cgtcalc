import Foundation

// MARK: - Output Formatter

public struct OutputFormatter {
  public init() {}

  /// Renders a full text report for a calculation result.
  /// - Parameter result: The engine output to render.
  /// - Returns: A human-readable report string.
  public func format(_ result: CalculationResult) -> String {
    var output = ""

    // Summary section
    output += self.formatSummary(result.taxYearSummaries)

    // Tax year details
    output += "\n\n# TAX YEAR DETAILS\n\n"
    output += self.formatTaxYearDetails(result.taxYearSummaries)

    // Tax return information
    output += "\n# TAX RETURN INFORMATION\n\n"
    output += self.formatTaxReturnInfo(result.taxYearSummaries)

    // Holdings
    output += "\n\n# HOLDINGS\n\n"
    output += self.formatHoldings(result.holdings)

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
        let rates = TaxRateLookup.rates(for: summary.taxYear)
        let taxBasic = self.formatCurrency(self.calculateTax(summary.taxableGain, rate: rates.basicRate))
        let taxHigher = self.formatCurrency(self.calculateTax(summary.taxableGain, rate: rates.higherRate))
        let row = [
          summary.taxYear.label,
          gain,
          proceeds,
          exemption,
          lossCarry,
          taxable,
          taxBasic,
          taxHigher
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
    let totalProceeds = summary.disposals.reduce(Decimal(0)) { $0 + $1.sellTransaction.proceeds }
    return "\(self.formatCurrency(TaxMethods.roundedGain(totalProceeds)))"
  }

  // MARK: - Tax Year Details

  /// Builds the per-tax-year disposal breakdown.
  /// - Parameter summaries: Tax-year summaries to render.
  /// - Returns: The rendered tax-year details section body.
  private func formatTaxYearDetails(_ summaries: [TaxYearSummary]) -> String {
    guard !summaries.isEmpty else {
      return ""
    }

    var output = ""

    for summary in summaries.sorted(by: { $0.taxYear < $1.taxYear }) {
      output += "## TAX YEAR \(summary.taxYear.label)\n\n"

      let gainsCount = summary.disposals.filter { $0.gain >= 0 }.count
      let lossesCount = summary.disposals.filter { $0.gain < 0 }.count
      let totalGains = summary.disposals.filter { $0.gain > 0 }.reduce(Decimal(0)) { $0 + $1.gain }
      let totalLosses = summary.disposals.filter { $0.gain < 0 }.reduce(Decimal(0)) { $0 + abs($1.gain) }

      output += "\(gainsCount) gains with total of \(totalGains).\n"
      output += "\(lossesCount) losses with total of \(totalLosses).\n\n"

      for (index, disposal) in summary.disposals.enumerated() {
        let gainStr = abs(disposal.gain)
        let gainLabel = disposal.gain >= 0 ? "GAIN" : "LOSS"

        output += "\(index + 1)) SOLD \(disposal.sellTransaction.quantity) of \(disposal.sellTransaction.asset) on \(DateParser.format(disposal.sellTransaction.date)) for \(gainLabel) of £\(gainStr)\n"

        output += "Matches with:\n"

        if !disposal.bedAndBreakfastMatches.isEmpty {
          for match in disposal.bedAndBreakfastMatches {
            let matchDate = DateParser.format(match.buyTransaction.date)
            let buyQuantity = match.buyDateQuantity
            let restructureMultiplier = match.restructureMultiplier
            let hasRestructure = restructureMultiplier != 1
            let restructureSuffix = hasRestructure ?
              " with restructure multiplier \(restructureMultiplier.rounded(to: 5).string)" : ""
            let eventOffsetSuffix = match
              .eventAdjustment != 0 ? " with offset of £\(abs(match.eventAdjustment).rounded(to: 2).string)" : ""
            let suffix = restructureSuffix + eventOffsetSuffix
            if UTC.calendar.isDate(match.buyTransaction.date, inSameDayAs: disposal.sellTransaction.date) {
              output += "  - SAME DAY: \(buyQuantity) bought on \(matchDate) at £\(match.buyTransaction.price)\(suffix)\n"
            } else {
              output += "  - BED & BREAKFAST: \(buyQuantity) bought on \(matchDate) at £\(match.buyTransaction.price)\(suffix)\n"
            }
          }
        }

        if !disposal.section104Matches.isEmpty {
          // poolQty is for display - total shares in the pool at time of disposal
          let poolQty = disposal.section104Matches[0].poolQuantity
          let poolCost = disposal.section104Matches[0].poolCost
          let poolAvgCost = poolQty > 0 ? poolCost / poolQty : 0
          output += "  - SECTION 104: \(poolQty) at cost basis of £\(poolAvgCost.rounded(to: 5).string)\n"
        }

        let saleExpenses = disposal.sellTransaction.expenses

        var costStr = "( "

        if !disposal.bedAndBreakfastMatches.isEmpty {
          // For B&B: show as (quantity * purchasePrice + purchaseExpenses)
          for (index, match) in disposal.bedAndBreakfastMatches.enumerated() {
            let purchasePrice = match.buyTransaction.price
            let purchaseExpenses = match.buyTransaction.expenses * match.buyDateQuantity / match.buyTransaction.quantity
            if index > 0 {
              costStr += " + "
            }
            let eventAdjustmentComponent = match
              .eventAdjustment != 0 ? " + \(match.eventAdjustment.rounded(to: 2).string)" : ""
            costStr += "(\(match.buyDateQuantity) * \(purchasePrice.rounded(to: 5).string) + \(purchaseExpenses.rounded(to: 2).string)\(eventAdjustmentComponent))"
          }
        }

        if !disposal.section104Matches.isEmpty {
          // Use pool average cost for calculation line
          let poolQty = disposal.section104Matches[0].poolQuantity
          let poolCost = disposal.section104Matches[0].poolCost
          let poolAvgCost = poolQty > 0 ? poolCost / poolQty : 0
          let section104MatchedQuantity = disposal.section104Matches.reduce(Decimal(0)) { $0 + $1.quantity }
          if !disposal.bedAndBreakfastMatches.isEmpty {
            costStr += " + "
          }
          costStr += "(\(section104MatchedQuantity) * \(poolAvgCost.rounded(to: 5).string))"
        }

        costStr += " )"

        output += "Calculation: (\(disposal.sellTransaction.quantity) * \(disposal.sellTransaction.price) - \(saleExpenses)) - \(costStr) = \(disposal.gain)\n"

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
      let disposalsCount = summary.disposals.count
      let totalProceeds = summary.disposals.reduce(Decimal(0)) { total, disposal in
        total + TaxMethods.roundedGain(disposal.sellTransaction.proceeds)
      }
      let allowableCosts = summary.disposals.reduce(Decimal(0)) { total, disposal in
        let roundedDisposalProceeds = TaxMethods.roundedGain(disposal.sellTransaction.proceeds)
        let reportedDisposalAllowableCost = roundedDisposalProceeds - disposal.gain
        return total + reportedDisposalAllowableCost
      }

      let totalGains = summary.disposals.filter { $0.gain > 0 }.reduce(Decimal(0)) { $0 + $1.gain }
      let totalLosses = summary.disposals.filter { $0.gain < 0 }.reduce(Decimal(0)) { $0 + abs($1.gain) }

      output += "\(summary.taxYear.label): Disposals = \(disposalsCount), proceeds = \(TaxMethods.roundedGain(totalProceeds)), allowable costs = \(TaxMethods.roundedGain(allowableCosts)), total gains = \(totalGains), total losses = \(totalLosses)\n"

      if let specialRateChangeDate = summary.taxYear.specialCapitalGainsRateChangeLastOldRateDate,
         let specialRateChangeLabel = summary.taxYear.specialCapitalGainsRateChangeLabel
      {
        let gainsToAndIncludingCutoff = summary.disposals
          .filter { $0.gain > 0 && $0.sellTransaction.date <= specialRateChangeDate }
          .reduce(Decimal(0)) { $0 + $1.gain }
        let gainsAfterCutoff = summary.disposals
          .filter { $0.gain > 0 && $0.sellTransaction.date > specialRateChangeDate }
          .reduce(Decimal(0)) { $0 + $1.gain }

        output += "    > Gains to (and inc.) \(specialRateChangeLabel) = \(gainsToAndIncludingCutoff), gains after \(specialRateChangeLabel) = \(gainsAfterCutoff)\n"
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
        output += "\(asset): \(holding.quantity) units acquired at £\(avgCost.rounded(to: 5).string) cost basis\n"
      }
    }

    if output.isEmpty {
      output = "NONE\n"
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
      let typeStr = transaction.type == .buy ? "BOUGHT" : "SOLD"
      output += "\(dateStr) \(typeStr) \(transaction.quantity) of \(transaction.asset) at £\(transaction.price) with £\(transaction.expenses) expenses\n"
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

      switch event.type {
      case .split:
        output += "\(dateStr) \(event.asset) SPLIT by \(event.amount)\n"
      case .unsplit:
        output += "\(dateStr) \(event.asset) UNSPLIT by \(event.amount)\n"
      case .capitalReturn:
        output += "\(dateStr) \(event.asset) CAPITAL RETURN on \(event.amount) for \(self.formatCurrency(event.value))\n"
      case .dividend:
        output += "\(dateStr) \(event.asset) DIVIDEND on \(event.amount) for \(self.formatCurrency(event.value))\n"
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

  /// Calculates tax for a taxable gain at a supplied rate.
  /// - Parameters:
  ///   - gain: The taxable gain amount.
  ///   - rate: The CGT rate to apply.
  /// - Returns: Tax due at that rate before any presentation formatting.
  private func calculateTax(_ gain: Decimal, rate: Decimal) -> Decimal {
    gain * rate
  }
}
