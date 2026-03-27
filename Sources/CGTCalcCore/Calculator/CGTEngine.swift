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
    let normalizedTransactions = self.normalizingSourceOrder(transactions)
    let normalizedEvents = self.normalizingSourceOrder(assetEvents)
    let sortedTransactions = normalizedTransactions.sorted(by: self.transactionSortsBefore)
    let sortedEvents = normalizedEvents.sorted(by: self.assetEventSortsBefore)
    let buys = sortedTransactions.filter(\.type.isAcquisition)
    let sells = SameDayDisposalMerger.merge(sortedTransactions.filter(\.type.isTaxableDisposal))
    let spouseOuts = sortedTransactions.filter(\.type.isSpouseTransferOut)
    let buysByAsset = Dictionary(grouping: buys, by: \.asset)
    let sellsByAsset = Dictionary(grouping: sells, by: \.asset)
    let spouseOutsByAsset = Dictionary(grouping: spouseOuts, by: \.asset)
    let eventsByAsset = Dictionary(grouping: sortedEvents, by: \.asset)
    let transactionsByAsset = Dictionary(grouping: normalizedTransactions, by: \.asset)
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
    for outboundGroup in self.groupedOutboundsByAssetAndDay(allOutbounds) {
      let asset = outboundGroup[0].asset
      let outboundDate = outboundGroup[0].date
      let groupedQuantity = outboundGroup.reduce(Decimal(0)) { $0 + $1.quantity }
      let groupedOutbound = Transaction(
        sourceOrder: outboundGroup[0].sourceOrder,
        type: .sell,
        date: outboundDate,
        asset: asset,
        quantity: groupedQuantity,
        price: 0,
        expenses: 0)
      let assetOutbounds = outboundsByAsset[asset, default: []]
      let assetBuys = buysByAsset[asset, default: []]
      let assetEvents = eventsByAsset[asset, default: []]
      let previousOutboundDate = previousOutboundDateByAsset[asset] ?? Date.distantPast

      let sameDayBuys = assetBuys.filter { buy in
        UTC.calendar.isDate(buy.date, inSameDayAs: outboundDate)
      }
      let thirtyDaysAfter = UTC.calendar.date(byAdding: .day, value: 30, to: outboundDate)!
      let postOutboundBnbBuys = assetBuys.filter { buy in
        buy.date > outboundDate && buy.date <= thirtyDaysAfter
      }
      let allBnbBuys = sameDayBuys + postOutboundBnbBuys

      let (bnbMatches, bnbQuantityUsed) = BedAndBreakfastMatcher.findMatches(
        for: groupedOutbound,
        from: allBnbBuys,
        usedBuyQuantities: usedBuyQuantities,
        sortedEvents: assetEvents,
        allOutbounds: assetOutbounds)

      for match in bnbMatches {
        usedBuyQuantities[match.buyTransaction.id, default: 0] += match.buyDateQuantity
      }

      let actions = Section104Processor.actions(
        buys: assetBuys,
        events: assetEvents,
        after: previousOutboundDate,
        through: outboundDate)

      let processedHolding = Section104Processor.processActions(
        actions,
        into: section104Holdings[asset, default: Section104Holding()],
        usedBuyQuantities: usedBuyQuantities)
      section104Holdings[asset] = processedHolding

      let holding = section104Holdings[asset]
      let s104QuantityNeeded = groupedQuantity - bnbQuantityUsed
      var section104Matches: [Section104Match] = []

      if let holding, s104QuantityNeeded > 0 {
        section104Matches = Section104Processor.makeMatches(quantityNeeded: s104QuantityNeeded, holding: holding)
      }

      let matchedQuantity = bnbQuantityUsed + section104Matches.reduce(Decimal(0)) { $0 + $1.quantity }
      guard matchedQuantity == groupedQuantity else {
        if let firstLaterAcquisitionDate = self.firstLaterAcquisitionDateForUnsupportedFallback(
          outboundDate: outboundDate,
          buys: assetBuys)
        {
          throw CalculationError.unsupportedLaterAcquisitionIdentification(
            asset: asset,
            date: outboundDate,
            requested: groupedQuantity,
            matched: matchedQuantity,
            firstLaterAcquisitionDate: firstLaterAcquisitionDate)
        }
        throw CalculationError.insufficientShares(
          asset: asset,
          date: outboundDate,
          requested: groupedQuantity,
          matched: matchedQuantity)
      }

      if let holding = section104Holdings[asset] {
        section104Holdings[asset] = Section104Processor.applyMatches(section104Matches, to: holding)
      }

      let allocationByOutbound = self.allocateMatchBreakdown(
        outbounds: outboundGroup,
        bnbMatches: bnbMatches,
        section104Matches: section104Matches)

      for outbound in outboundGroup {
        let allocation = allocationByOutbound[outbound.id, default: MatchAllocation()]
        let totalCost = allocation.totalCost

        if outbound.type.isTaxableDisposal {
          let taxYear = TaxYear.from(date: outbound.date)
          let rawGain = outbound.proceeds - totalCost - outbound.expenses
          let gain = TaxMethods.roundedGain(rawGain)
          disposals.append(Disposal(
            sellTransaction: outbound,
            taxYear: taxYear,
            gain: gain,
            section104Matches: allocation.section104Matches,
            bedAndBreakfastMatches: allocation.bedAndBreakfastMatches))
        } else {
          spouseTransfersOut.append(SpouseTransferOut(transaction: outbound, costBasis: totalCost))
        }
      }
      previousOutboundDateByAsset[asset] = outboundDate
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
      transactions: normalizedTransactions,
      assetEvents: normalizedEvents,
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

  private struct OutboundGroupKey: Hashable {
    let asset: String
    let day: Date
  }

  private static func groupedOutboundsByAssetAndDay(_ outbounds: [Transaction]) -> [[Transaction]] {
    let grouped = Dictionary(grouping: outbounds) { outbound in
      OutboundGroupKey(asset: outbound.asset, day: UTC.calendar.startOfDay(for: outbound.date))
    }
    return grouped.values
      .map { $0.sorted(by: self.transactionSortsBefore) }
      .sorted { lhs, rhs in
        self.transactionSortsBefore(lhs[0], rhs[0])
      }
  }

  private static func assetEventSortsBefore(_ lhs: AssetEvent, _ rhs: AssetEvent) -> Bool {
    if lhs.date != rhs.date {
      return lhs.date < rhs.date
    }
    if lhs.sourceOrder != rhs.sourceOrder {
      return (lhs.sourceOrder ?? .max) < (rhs.sourceOrder ?? .max)
    }
    return lhs.id.uuidString < rhs.id.uuidString
  }

  /// Ensures transactions without explicit source order still get a deterministic tie-breaker.
  private static func normalizingSourceOrder(_ transactions: [Transaction]) -> [Transaction] {
    var nextSourceOrder = (transactions.compactMap(\.sourceOrder).max() ?? -1) + 1
    return transactions.map { transaction in
      guard transaction.sourceOrder == nil else { return transaction }
      defer { nextSourceOrder += 1 }
      return Transaction(
        id: transaction.id,
        sourceOrder: nextSourceOrder,
        type: transaction.type,
        date: transaction.date,
        asset: transaction.asset,
        quantity: transaction.quantity,
        price: transaction.price,
        expenses: transaction.expenses)
    }
  }

  /// Ensures asset events without explicit source order still get a deterministic tie-breaker.
  private static func normalizingSourceOrder(_ assetEvents: [AssetEvent]) -> [AssetEvent] {
    var nextSourceOrder = (assetEvents.compactMap(\.sourceOrder).max() ?? -1) + 1
    return assetEvents.map { event in
      guard event.sourceOrder == nil else { return event }
      defer { nextSourceOrder += 1 }
      return AssetEvent(
        id: event.id,
        sourceOrder: nextSourceOrder,
        date: event.date,
        asset: event.asset,
        kind: event.kind)
    }
  }

  private static func firstLaterAcquisitionDateForUnsupportedFallback(
    outboundDate: Date,
    buys: [Transaction]) -> Date?
  {
    guard let day30 = UTC.calendar.date(byAdding: .day, value: 30, to: outboundDate) else {
      return nil
    }
    return buys
      .map(\.date)
      .filter { $0 > day30 }
      .min()
  }

  private struct MatchAllocation {
    var bedAndBreakfastMatches: [BedAndBreakfastMatch] = []
    var section104Matches: [Section104Match] = []

    var totalCost: Decimal {
      self.bedAndBreakfastMatches.reduce(Decimal(0)) { $0 + $1.cost } +
        self.section104Matches.reduce(Decimal(0)) { $0 + $1.cost }
    }
  }

  private static func allocateMatchBreakdown(
    outbounds: [Transaction],
    bnbMatches: [BedAndBreakfastMatch],
    section104Matches: [Section104Match]) -> [UUID: MatchAllocation]
  {
    let totalQuantity = outbounds.reduce(Decimal(0)) { $0 + $1.quantity }
    guard totalQuantity > 0 else {
      return [:]
    }

    var allocations = Dictionary(uniqueKeysWithValues: outbounds.map { ($0.id, MatchAllocation()) })

    for outbound in outbounds {
      let quantityRatio = outbound.quantity / totalQuantity
      let allocatedBnbMatches = bnbMatches.map { match in
        BedAndBreakfastMatch(
          buyTransaction: match.buyTransaction,
          quantity: match.quantity * quantityRatio,
          buyDateQuantity: match.buyDateQuantity * quantityRatio,
          eventAdjustment: match.eventAdjustment * quantityRatio,
          cost: match.cost * quantityRatio)
      }
      let allocatedSection104Matches = section104Matches.map { match in
        Section104Match(
          transactionId: match.transactionId,
          sourceOrder: match.sourceOrder,
          quantity: match.quantity * quantityRatio,
          cost: match.cost * quantityRatio,
          date: match.date,
          poolQuantity: match.poolQuantity,
          poolCost: match.poolCost)
      }
      allocations[outbound.id] = MatchAllocation(
        bedAndBreakfastMatches: allocatedBnbMatches,
        section104Matches: allocatedSection104Matches)
    }

    return allocations
  }
}
