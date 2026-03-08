import Foundation

// MARK: - CGT Engine

public enum CGTEngine {
  /// Calculates a result from parsed input rows.
  /// - Parameter inputData: Mixed transaction and asset-event rows from the parser.
  /// - Returns: The full calculation result used by the formatter and tests.
  public static func calculate(inputData: [InputData]) throws -> CalculationResult {
    let transactions = inputData.compactMap { data -> Transaction? in
      if case .transaction(let t) = data { return t }
      return nil
    }

    let assetEvents = inputData.compactMap { data -> AssetEvent? in
      if case .assetEvent(let e) = data { return e }
      return nil
    }

    return try self.calculate(transactions: transactions, assetEvents: assetEvents)
  }

  /// Runs the CGT engine on transactions and asset events.
  /// - Parameters:
  ///   - transactions: Buy and sell rows for all assets.
  ///   - assetEvents: CAPRETURN, DIVIDEND, SPLIT, and UNSPLIT rows for all assets.
  /// - Returns: Disposals, tax-year summaries, and final holdings.
  public static func calculate(transactions: [Transaction], assetEvents: [AssetEvent]) throws -> CalculationResult {
    let sortedTransactions = transactions.sorted { $0.date < $1.date }
    let sortedEvents = assetEvents.sorted { $0.date < $1.date }
    let buys = sortedTransactions.filter { $0.type == .buy }
    let sells = SameDayDisposalMerger.merge(transactions)
    let buysByAsset = Dictionary(grouping: buys, by: \.asset)
    let sellsByAsset = Dictionary(grouping: sells, by: \.asset)
    let eventsByAsset = Dictionary(grouping: sortedEvents, by: \.asset)
    let transactionsByAsset = Dictionary(grouping: transactions, by: \.asset)

    for asset in Set(transactionsByAsset.keys).union(eventsByAsset.keys) {
      try AssetEventValidator.validate(
        transactions: transactionsByAsset[asset, default: []],
        assetEvents: eventsByAsset[asset, default: []])
    }

    var section104Holdings: [String: Section104Holding] = [:]
    var usedBuyQuantities: [UUID: Decimal] = [:]
    var disposals: [Disposal] = []

    for sell in sells {
      let taxYear = TaxYear.from(date: sell.date)
      let asset = sell.asset
      let assetBuys = buysByAsset[asset, default: []]
      let assetSells = sellsByAsset[asset, default: []]
      let assetEvents = eventsByAsset[asset, default: []]

      let sameDayBuys = assetBuys.filter { buy in
        UTC.calendar.isDate(buy.date, inSameDayAs: sell.date)
      }

      let thirtyDaysAfter = UTC.calendar.date(byAdding: .day, value: 30, to: sell.date)!
      let postSellBnbBuys = assetBuys.filter { buy in
        buy.date > sell.date && buy.date <= thirtyDaysAfter
      }
      let allBnbBuys = sameDayBuys + postSellBnbBuys

      let (bnbMatches, bnbQuantityUsed) = BedAndBreakfastMatcher.findMatches(
        for: sell,
        from: allBnbBuys,
        usedBuyQuantities: usedBuyQuantities,
        sortedEvents: assetEvents,
        allSells: assetSells)

      for match in bnbMatches {
        usedBuyQuantities[match.buyTransaction.id, default: 0] += match.buyDateQuantity
      }

      let previousSaleDate = assetSells.filter { $0.date < sell.date }.map(\.date).max() ?? Date.distantPast
      let actions = Section104Processor.actions(
        buys: assetBuys,
        events: assetEvents,
        after: previousSaleDate,
        through: sell.date)

      let processedHolding = Section104Processor.processActions(
        actions,
        into: section104Holdings[asset, default: Section104Holding()],
        usedBuyQuantities: usedBuyQuantities)
      section104Holdings[asset] = processedHolding

      let holding = section104Holdings[asset]
      let s104QuantityNeeded = sell.quantity - bnbQuantityUsed
      var section104Matches: [Section104Match] = []

      if let holding, s104QuantityNeeded > 0 {
        section104Matches = Section104Processor.makeMatches(quantityNeeded: s104QuantityNeeded, holding: holding)
      }

      let totalMatchedQuantity = bnbQuantityUsed + section104Matches.reduce(Decimal(0)) { $0 + $1.quantity }
      guard totalMatchedQuantity == sell.quantity else {
        throw CalculationError.insufficientShares(
          asset: asset,
          date: sell.date,
          requested: sell.quantity,
          matched: totalMatchedQuantity)
      }

      let bnbCost = bnbMatches.reduce(Decimal(0)) { $0 + $1.cost }
      let s104Cost = section104Matches.reduce(Decimal(0)) { $0 + $1.cost }
      let totalCost = bnbCost + s104Cost

      let proceeds = sell.proceeds
      let rawGain = proceeds - totalCost - sell.expenses
      let gain = TaxMethods.roundedGain(rawGain)

      if let holding = section104Holdings[asset] {
        section104Holdings[asset] = Section104Processor.applyMatches(section104Matches, to: holding)
      }

      disposals.append(Disposal(
        sellTransaction: sell,
        taxYear: taxYear,
        gain: gain,
        section104Matches: section104Matches,
        bedAndBreakfastMatches: bnbMatches))
    }

    let summaryResult = try TaxYearSummarizer.summarize(disposals: disposals)
    let summaries = summaryResult.summaries

    let assets = Set(buysByAsset.keys).union(eventsByAsset.keys).union(section104Holdings.keys)
    let finalHoldings = Dictionary(uniqueKeysWithValues: assets.map { asset in
      let lastSaleDate = sellsByAsset[asset, default: []].map(\.date).max() ?? Date.distantPast
      let actions = Section104Processor.actions(
        buys: buysByAsset[asset, default: []],
        events: eventsByAsset[asset, default: []],
        after: lastSaleDate,
        through: nil)
      let holding = Section104Processor.processActions(
        actions,
        into: section104Holdings[asset, default: Section104Holding()],
        usedBuyQuantities: usedBuyQuantities)
      return (asset, holding)
    })

    return CalculationResult(
      taxYearSummaries: summaries,
      transactions: transactions,
      assetEvents: assetEvents,
      lossCarryForward: summaryResult.lossCarryForward,
      holdings: finalHoldings)
  }
}
