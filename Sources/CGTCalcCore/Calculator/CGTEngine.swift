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
  ///   - transactions: Transaction rows for all assets, including spouse transfer rows.
  ///   - assetEvents: CAPRETURN, DIVIDEND, SPLIT, UNSPLIT, and RESTRUCT rows for all assets.
  /// - Returns: Disposals, tax-year summaries, and final holdings.
  public static func calculate(transactions: [Transaction], assetEvents: [AssetEvent]) throws -> CalculationResult {
    let sortedTransactions = transactions.sorted(by: self.transactionSortsBefore)
    let sortedEvents = assetEvents.sorted { $0.date < $1.date }
    let buys = sortedTransactions.filter(\.type.isAcquisition)
    let sells = SameDayDisposalMerger.merge(sortedTransactions.filter(\.type.isTaxableDisposal))
    let spouseOuts = sortedTransactions.filter(\.type.isSpouseTransferOut)
    let buysByAsset = Dictionary(grouping: buys, by: \.asset)
    let sellsByAsset = Dictionary(grouping: sells, by: \.asset)
    let spouseOutsByAsset = Dictionary(grouping: spouseOuts, by: \.asset)
    let eventsByAsset = Dictionary(grouping: sortedEvents, by: \.asset)
    let transactionsByAsset = Dictionary(grouping: transactions, by: \.asset)
    let allOutbounds = (sells + spouseOuts).sorted(by: self.transactionSortsBefore)
    let outboundsByAsset = Dictionary(grouping: allOutbounds, by: \.asset)

    for asset in Set(transactionsByAsset.keys).union(eventsByAsset.keys) {
      try AssetEventValidator.validate(
        transactions: transactionsByAsset[asset, default: []],
        assetEvents: eventsByAsset[asset, default: []])
    }

    var section104Holdings: [String: Section104Holding] = [:]
    var usedBuyQuantities: [UUID: Decimal] = [:]
    var disposals: [Disposal] = []
    var spouseTransfersOut: [SpouseTransferOut] = []
    var previousOutboundDateByAsset: [String: Date] = [:]
    for outbound in allOutbounds {
      let asset = outbound.asset
      let assetBuys = buysByAsset[asset, default: []]
      let assetEvents = eventsByAsset[asset, default: []]
      let assetOutbounds = outboundsByAsset[asset, default: []]
      let previousOutboundDate = previousOutboundDateByAsset[asset] ?? Date.distantPast

      if outbound.type.isTaxableDisposal {
        let sell = outbound
        let taxYear = TaxYear.from(date: sell.date)

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
          allSells: assetOutbounds)

        for match in bnbMatches {
          usedBuyQuantities[match.buyTransaction.id, default: 0] += match.buyDateQuantity
        }

        let actions = Section104Processor.actions(
          buys: assetBuys,
          events: assetEvents,
          after: previousOutboundDate,
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
      } else {
        let sameDayBuys = assetBuys.filter { buy in
          UTC.calendar.isDate(buy.date, inSameDayAs: outbound.date)
        }
        let thirtyDaysAfter = UTC.calendar.date(byAdding: .day, value: 30, to: outbound.date)!
        let postTransferBnbBuys = assetBuys.filter { buy in
          buy.date > outbound.date && buy.date <= thirtyDaysAfter
        }
        let allBnbBuys = sameDayBuys + postTransferBnbBuys

        let (bnbMatches, bnbQuantityUsed) = BedAndBreakfastMatcher.findMatches(
          for: outbound,
          from: allBnbBuys,
          usedBuyQuantities: usedBuyQuantities,
          sortedEvents: assetEvents,
          allSells: assetOutbounds)

        for match in bnbMatches {
          usedBuyQuantities[match.buyTransaction.id, default: 0] += match.buyDateQuantity
        }

        let actions = Section104Processor.actions(
          buys: assetBuys,
          events: assetEvents,
          after: previousOutboundDate,
          through: outbound.date)

        let processedHolding = Section104Processor.processActions(
          actions,
          into: section104Holdings[asset, default: Section104Holding()],
          usedBuyQuantities: usedBuyQuantities)
        section104Holdings[asset] = processedHolding

        let holding = section104Holdings[asset, default: Section104Holding()]
        let section104Matches = Section104Processor.makeMatches(
          quantityNeeded: outbound.quantity - bnbQuantityUsed,
          holding: holding)
        let matchedQuantity = bnbQuantityUsed + section104Matches.reduce(Decimal(0)) { $0 + $1.quantity }
        guard matchedQuantity == outbound.quantity else {
          throw CalculationError.insufficientShares(
            asset: asset,
            date: outbound.date,
            requested: outbound.quantity,
            matched: matchedQuantity)
        }

        let bnbCost = bnbMatches.reduce(Decimal(0)) { $0 + $1.cost }
        let s104Cost = section104Matches.reduce(Decimal(0)) { $0 + $1.cost }
        let transferCostBasis = bnbCost + s104Cost
        section104Holdings[asset] = Section104Processor.applyMatches(section104Matches, to: holding)
        spouseTransfersOut.append(SpouseTransferOut(transaction: outbound, costBasis: transferCostBasis))
      }
      previousOutboundDateByAsset[asset] = outbound.date
    }

    let summaryResult = try TaxYearSummarizer.summarize(disposals: disposals)
    let summaries = summaryResult.summaries

    let assets = Set(buysByAsset.keys)
      .union(sellsByAsset.keys)
      .union(spouseOutsByAsset.keys)
      .union(eventsByAsset.keys)
    let finalHoldings = Dictionary(uniqueKeysWithValues: assets.map { asset in
      let lastOutboundDate = previousOutboundDateByAsset[asset] ?? Date.distantPast
      let actions = Section104Processor.actions(
        buys: buysByAsset[asset, default: []],
        events: eventsByAsset[asset, default: []],
        after: lastOutboundDate,
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
      holdings: finalHoldings,
      spouseTransfersOut: spouseTransfersOut.sorted(by: self.spouseTransferSortsBefore))
  }

  private static func transactionSortsBefore(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
    if lhs.date != rhs.date {
      return lhs.date < rhs.date
    }
    if lhs.sourceOrder != rhs.sourceOrder {
      return (lhs.sourceOrder ?? .max) < (rhs.sourceOrder ?? .max)
    }
    return lhs.id.uuidString < rhs.id.uuidString
  }

  private static func spouseTransferSortsBefore(_ lhs: SpouseTransferOut, _ rhs: SpouseTransferOut) -> Bool {
    self.transactionSortsBefore(lhs.transaction, rhs.transaction)
  }
}
