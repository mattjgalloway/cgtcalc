import Foundation

struct CalculationSession {
  struct Output {
    let disposals: [Disposal]
    let holdings: [String: Section104Holding]
    let spouseTransfersOut: [SpouseTransferOut]
  }

  struct AssetLedger {
    var holding = Section104Holding()
    var usedBuyQuantities: [UUID: Decimal] = [:]
    var allocatedEventValues: [UUID: Decimal] = [:]
    var allocatedEventQuantities: [UUID: Decimal] = [:]
    var previousOutboundDate = Date.distantPast
  }

  private let buysByAsset: [String: [Transaction]]
  private let sellsByAsset: [String: [Transaction]]
  private let spouseOutsByAsset: [String: [Transaction]]
  private let outboundsByAsset: [String: [Transaction]]
  private let eventsByAsset: [String: [AssetEvent]]
  private let allOutbounds: [Transaction]
  private var ledgers: [String: AssetLedger] = [:]
  private var disposals: [Disposal] = []
  private var spouseTransfersOut: [SpouseTransferOut] = []

  init(transactions: [Transaction], calculationEvents: [AssetEvent]) {
    let sortedTransactions = transactions.sorted(by: CalculationTimeline.transactionSortsBefore)
    let buys = sortedTransactions.filter(\.type.isAcquisition)
    let sells = SameDayDisposalMerger.merge(sortedTransactions.filter(\.type.isTaxableDisposal))
    let spouseOuts = sortedTransactions.filter(\.type.isSpouseTransferOut)
    let outbounds = (sells + spouseOuts).sorted(by: CalculationTimeline.transactionSortsBefore)

    self.buysByAsset = Dictionary(grouping: buys, by: \.asset)
    self.sellsByAsset = Dictionary(grouping: sells, by: \.asset)
    self.spouseOutsByAsset = Dictionary(grouping: spouseOuts, by: \.asset)
    self.outboundsByAsset = Dictionary(grouping: outbounds, by: \.asset)
    self.eventsByAsset = Dictionary(
      grouping: calculationEvents.sorted(by: CalculationTimeline.assetEventSortsBefore),
      by: \.asset)
    self.allOutbounds = outbounds
  }

  mutating func run() throws -> Output {
    for outboundGroup in self.groupedOutboundsByAssetAndDay() {
      try self.process(outboundGroup)
    }

    let assets = Set(self.buysByAsset.keys)
      .union(self.sellsByAsset.keys)
      .union(self.spouseOutsByAsset.keys)
      .union(self.eventsByAsset.keys)
    var finalHoldings: [String: Section104Holding] = [:]
    for asset in assets {
      var ledger = self.ledgers[asset, default: AssetLedger()]
      let actions = Section104Processor.actions(
        buys: self.buysByAsset[asset, default: []],
        events: self.eventsByAsset[asset, default: []],
        after: ledger.previousOutboundDate,
        through: nil)
      ledger.holding = try Section104Processor.processActions(
        actions,
        into: ledger.holding,
        usedBuyQuantities: ledger.usedBuyQuantities,
        allocatedEventValues: ledger.allocatedEventValues,
        allocatedEventQuantities: ledger.allocatedEventQuantities)
      self.ledgers[asset] = ledger
      finalHoldings[asset] = ledger.holding
    }

    return Output(
      disposals: self.disposals,
      holdings: finalHoldings,
      spouseTransfersOut: self.spouseTransfersOut.sorted {
        CalculationTimeline.transactionSortsBefore($0.transaction, $1.transaction)
      })
  }

  private mutating func process(_ outboundGroup: [Transaction]) throws {
    let asset = outboundGroup[0].asset
    let outboundDate = outboundGroup[0].date
    var ledger = self.ledgers[asset, default: AssetLedger()]
    let result = try self.processOutboundGroup(
      outboundGroup,
      assetBuys: self.buysByAsset[asset, default: []],
      assetEvents: self.eventsByAsset[asset, default: []],
      assetOutbounds: self.outboundsByAsset[asset, default: []],
      ledger: &ledger)
    ledger.holding = result.updatedHolding

    for outbound in outboundGroup {
      let allocation = result.allocationByOutbound[outbound.id, default: MatchAllocation()]
      let totalCost = allocation.totalCost
      if outbound.type.isTaxableDisposal {
        let rawGain = outbound.proceeds - totalCost - outbound.expenses
        self.disposals.append(Disposal(
          sellTransaction: outbound,
          taxYear: TaxYear.from(date: outbound.date),
          gain: TaxMethods.roundedGain(rawGain),
          rawGain: rawGain,
          rawProceeds: outbound.proceeds,
          rawAllowableCosts: totalCost + outbound.expenses,
          section104Matches: allocation.section104Matches,
          bedAndBreakfastMatches: allocation.bedAndBreakfastMatches))
      } else {
        self.spouseTransfersOut.append(SpouseTransferOut(transaction: outbound, costBasis: totalCost))
      }
    }
    ledger.previousOutboundDate = outboundDate
    self.ledgers[asset] = ledger
  }

  private struct OutboundGroupKey: Hashable {
    let asset: String
    let day: Date
  }

  private func groupedOutboundsByAssetAndDay() -> [[Transaction]] {
    Dictionary(grouping: self.allOutbounds) { outbound in
      OutboundGroupKey(asset: outbound.asset, day: CalculationTimeline.day(for: outbound.date))
    }.values
      .map { $0.sorted(by: CalculationTimeline.transactionSortsBefore) }
      .sorted { CalculationTimeline.transactionSortsBefore($0[0], $1[0]) }
  }

  private struct OutboundGroupProcessResult {
    let updatedHolding: Section104Holding
    let allocationByOutbound: [UUID: MatchAllocation]
  }

  private func processOutboundGroup(
    _ outboundGroup: [Transaction],
    assetBuys: [Transaction],
    assetEvents: [AssetEvent],
    assetOutbounds: [Transaction],
    ledger: inout AssetLedger) throws -> OutboundGroupProcessResult
  {
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

    let sameDayBuys = assetBuys.filter { UTC.calendar.isDate($0.date, inSameDayAs: outboundDate) }
    let thirtyDaysAfter = UTC.calendar.date(byAdding: .day, value: 30, to: outboundDate)!
    let laterBuys = assetBuys.filter { $0.date > outboundDate && $0.date <= thirtyDaysAfter }
    let (bnbMatches, bnbQuantityUsed) = try BedAndBreakfastMatcher.findMatches(
      for: groupedOutbound,
      from: sameDayBuys + laterBuys,
      usedBuyQuantities: ledger.usedBuyQuantities,
      sortedEvents: assetEvents,
      allOutbounds: assetOutbounds,
      allocatedEventValues: &ledger.allocatedEventValues,
      allocatedEventQuantities: &ledger.allocatedEventQuantities)

    for match in bnbMatches {
      ledger.usedBuyQuantities[match.buyTransaction.id, default: 0] += match.buyDateQuantity
    }

    let actions = Section104Processor.actions(
      buys: assetBuys,
      events: assetEvents,
      after: ledger.previousOutboundDate,
      through: outboundDate)
    let processedHolding = try Section104Processor.processActions(
      actions,
      into: ledger.holding,
      usedBuyQuantities: ledger.usedBuyQuantities,
      allocatedEventValues: ledger.allocatedEventValues,
      allocatedEventQuantities: ledger.allocatedEventQuantities)
    let section104QuantityNeeded = groupedQuantity - bnbQuantityUsed
    let section104Matches = section104QuantityNeeded > 0
      ? Section104Processor.makeMatches(quantityNeeded: section104QuantityNeeded, holding: processedHolding)
      : []

    let matchedQuantity = bnbQuantityUsed + section104Matches.reduce(0) { $0 + $1.quantity }
    guard QuantityMaths.isReconciledMatch(requested: groupedQuantity, matched: matchedQuantity) else {
      if let laterDate = self.firstLaterAcquisitionDate(
        outboundDate: outboundDate,
        buys: assetBuys)
      {
        throw CalculationError.unsupportedLaterAcquisitionIdentification(
          asset: asset,
          date: outboundDate,
          requested: groupedQuantity,
          matched: matchedQuantity,
          firstLaterAcquisitionDate: laterDate)
      }
      throw CalculationError.insufficientShares(
        asset: asset,
        date: outboundDate,
        requested: groupedQuantity,
        matched: matchedQuantity)
    }

    let allocationByOutbound = self.allocateMatchBreakdown(
      outbounds: outboundGroup,
      bnbMatches: bnbMatches,
      section104Matches: section104Matches)
    let poolAdjustedHolding = Section104Processor.applyMatches(section104Matches, to: processedHolding)
    return OutboundGroupProcessResult(
      updatedHolding: Section104Processor.applyOutboundToGroupII(
        quantity: groupedQuantity,
        holdingQuantity: processedHolding.quantity,
        to: poolAdjustedHolding),
      allocationByOutbound: allocationByOutbound)
  }

  private func firstLaterAcquisitionDate(outboundDate: Date, buys: [Transaction]) -> Date? {
    guard let day30 = UTC.calendar.date(byAdding: .day, value: 30, to: outboundDate) else { return nil }
    return buys.map(\.date).filter { $0 > day30 }.min()
  }

  private struct MatchAllocation {
    var bedAndBreakfastMatches: [BedAndBreakfastMatch] = []
    var section104Matches: [Section104Match] = []

    var totalCost: Decimal {
      self.bedAndBreakfastMatches.reduce(0) { $0 + $1.cost } +
        self.section104Matches.reduce(0) { $0 + $1.cost }
    }
  }

  private func allocateMatchBreakdown(
    outbounds: [Transaction],
    bnbMatches: [BedAndBreakfastMatch],
    section104Matches: [Section104Match]) -> [UUID: MatchAllocation]
  {
    let totalQuantity = outbounds.reduce(Decimal(0)) { $0 + $1.quantity }
    guard totalQuantity > 0 else { return [:] }
    var allocations = Dictionary(uniqueKeysWithValues: outbounds.map { ($0.id, MatchAllocation()) })
    var cumulativeOutboundQuantity: Decimal = 0

    for outbound in outbounds.sorted(by: self.outboundAllocationSortsBefore) {
      let previousQuantity = cumulativeOutboundQuantity
      cumulativeOutboundQuantity += outbound.quantity
      allocations[outbound.id] = MatchAllocation(
        bedAndBreakfastMatches: bnbMatches.map { match in
          BedAndBreakfastMatch(
            buyTransaction: match.buyTransaction,
            quantity: self.cumulativeAllocation(
              of: match.quantity,
              from: previousQuantity,
              through: cumulativeOutboundQuantity,
              totalQuantity: totalQuantity),
            buyDateQuantity: self.cumulativeAllocation(
              of: match.buyDateQuantity,
              from: previousQuantity,
              through: cumulativeOutboundQuantity,
              totalQuantity: totalQuantity),
            eventAdjustment: self.cumulativeAllocation(
              of: match.eventAdjustment,
              from: previousQuantity,
              through: cumulativeOutboundQuantity,
              totalQuantity: totalQuantity),
            cost: self.cumulativeAllocation(
              of: match.cost,
              from: previousQuantity,
              through: cumulativeOutboundQuantity,
              totalQuantity: totalQuantity))
        },
        section104Matches: section104Matches.map { match in
          Section104Match(
            transactionId: match.transactionId,
            sourceOrder: match.sourceOrder,
            quantity: self.cumulativeAllocation(
              of: match.quantity,
              from: previousQuantity,
              through: cumulativeOutboundQuantity,
              totalQuantity: totalQuantity),
            cost: self.cumulativeAllocation(
              of: match.cost,
              from: previousQuantity,
              through: cumulativeOutboundQuantity,
              totalQuantity: totalQuantity),
            date: match.date,
            poolQuantity: match.poolQuantity,
            poolCost: match.poolCost)
        })
    }
    return allocations
  }

  private func cumulativeAllocation(
    of value: Decimal,
    from previousQuantity: Decimal,
    through cumulativeQuantity: Decimal,
    totalQuantity: Decimal) -> Decimal
  {
    EventAllocationMath.cumulativeValue(
      totalValue: value,
      allocatedQuantity: cumulativeQuantity,
      totalQuantity: totalQuantity) - EventAllocationMath.cumulativeValue(
      totalValue: value,
      allocatedQuantity: previousQuantity,
      totalQuantity: totalQuantity)
  }

  private func outboundAllocationSortsBefore(_ lhs: Transaction, _ rhs: Transaction) -> Bool {
    if lhs.type != rhs.type { return lhs.type == .sell }
    if lhs.quantity != rhs.quantity { return lhs.quantity < rhs.quantity }
    if lhs.totalValue != rhs.totalValue { return lhs.totalValue < rhs.totalValue }
    if lhs.expenses != rhs.expenses { return lhs.expenses < rhs.expenses }
    return lhs.asset < rhs.asset
  }
}
