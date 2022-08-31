//
//  Calculator.swift
//  cgtcalc
//
//  Created by Matt Galloway on 06/06/2020.
//

import Foundation

public class Calculator {
  private let input: CalculatorInput
  private let logger: Logger

  public init(input: CalculatorInput, logger: Logger) throws {
    self.input = input
    self.logger = logger
  }

  public func process() throws -> CalculatorResult {
    self.logger.info("Begin processing")
    try self.preprocessTransactions()
    let calculatorResult = try self.processTransactions()
    self.logger.info("Finished processing")
    return calculatorResult
  }

  private func preprocessTransactions() throws {
    for transaction in self.input.transactions {
      // 6th April 2008 is when new CGT rules came in. We only support those new rules.
      if transaction.date < Date(timeIntervalSince1970: 1207440000) {
        throw CalculatorError.TransactionDateNotSupported
      }
    }
  }

  private func processTransactions() throws -> CalculatorResult {
    let transactionsByAsset = Dictionary(grouping: self.input.transactions, by: \.asset)
    let assetEventsByAsset = Dictionary(grouping: self.input.assetEvents, by: \.asset)

    let allAssets = Set<String>(transactionsByAsset.keys).union(Set<String>(assetEventsByAsset.keys))

    let allDisposalMatches = try allAssets
      .map { asset -> AssetResult in
        let (acquisitions, disposals) = try self
          .splitAndGroupSameDayTransactions(transactionsByAsset[asset, default: []])
        let assetEvents = try self
          .sortAndGroupSameDayAssetEvents(assetEventsByAsset[asset, default: []])
        let state = AssetProcessorState(
          asset: asset,
          acquisitions: acquisitions,
          disposals: disposals,
          assetEvents: assetEvents)
        try self.preprocessAsset(withState: state)
        return try processAsset(withState: state)
      }
      .reduce(into: [DisposalMatch]()) { disposalMatches, assetResult in
        disposalMatches.append(contentsOf: assetResult.disposalMatches)
      }

    return try CalculatorResult(input: self.input, disposalMatches: allDisposalMatches)
  }

  private func sortAndGroupSameDayAssetEvents(_ assetEvents: [AssetEvent]) throws -> [AssetEvent] {
    var groupedAssetEvents: [AssetEvent] = []

    for (_, byDateAssetEvents) in Dictionary(grouping: assetEvents, by: { $0.date }) {
      for (_, byKindAssetEvents) in Dictionary(grouping: byDateAssetEvents, by: { $0.kind.case }) {
        let groupedAssetEvent = try AssetEvent.grouped(byKindAssetEvents)
        groupedAssetEvents.append(groupedAssetEvent)
      }
    }

    return groupedAssetEvents.sorted { $0.date < $1.date }
  }

  private func splitAndGroupSameDayTransactions(_ transactions: [Transaction]) throws
    -> (acquisitions: [TransactionToMatch], disposals: [TransactionToMatch])
  {
    let acquisitions = transactions
      .filter { $0.kind == .Buy }
      .sorted { $0.date < $1.date }
    let disposals = transactions
      .filter { $0.kind == .Sell }
      .sorted { $0.date < $1.date }

    func group(_ transactions: [Transaction]) throws -> [TransactionToMatch] {
      var transactionToMatches: [TransactionToMatch] = []

      var currentDate = Date.distantPast
      var currentTransactions: [Transaction] = []

      try transactions.forEach { transaction in
        if currentDate != transaction.date {
          if !currentTransactions.isEmpty {
            let groupedTransaction = try Transaction.grouped(currentTransactions)
            transactionToMatches.append(TransactionToMatch(transaction: groupedTransaction))
            currentTransactions = []
          }
          currentDate = transaction.date
        }
        currentTransactions.append(transaction)
      }

      if !currentTransactions.isEmpty {
        let groupedTransaction = try Transaction.grouped(currentTransactions)
        transactionToMatches.append(TransactionToMatch(transaction: groupedTransaction))
      }

      return transactionToMatches
    }

    let acquisitionsToMatch = try group(acquisitions)
    let disposalsToMatch = try group(disposals)

    return (acquisitions: acquisitionsToMatch, disposals: disposalsToMatch)
  }

  private func preprocessAsset(withState state: AssetProcessorState) throws {
    guard state.assetEvents.count > 0 else {
      self.logger.info("No pre-processing of transactions required for \(state.asset).")
      return
    }

    guard state.pendingAcquisitions.count > 0 else {
      throw CalculatorError.InvalidData("Had events but no acquisitions for \(state.asset).")
    }

    self.logger.info("Begin pre-processing transactions for \(state.asset).")

    // Helper class that holds a transaction and an offset amount left. Used to handle FIFO buy/sell preprocessing.
    class TransactionTuple {
      let transaction: TransactionToMatch
      var amountLeft: Decimal
      init(transaction: TransactionToMatch) {
        self.transaction = transaction
        self.amountLeft = transaction.amount
      }
    }

    // First go over all the capital returns and decrease the price paid for acquisitions.
    var acquisitionsIndex = state.pendingAcquisitions.startIndex
    var disposalsIndex = state.pendingDisposals.startIndex
    var assetEventsIndex = state.assetEvents.startIndex
    var runningTotal = Decimal.zero
    while assetEventsIndex < state.assetEvents.endIndex {
      let assetEvent = state.assetEvents[assetEventsIndex]

      let amount: Decimal
      let value: Decimal
      switch assetEvent.kind {
      case .CapitalReturn(let a, let v):
        amount = a
        value = v
      default:
        assetEventsIndex += 1
        continue
      }

      self.logger.debug(" - Processing capital return event: \(assetEvent).")

      guard acquisitionsIndex < state.pendingAcquisitions.endIndex else {
        throw CalculatorError
          .InvalidData(
            "Error pre-processing \(state.asset) while processing capital return events. Found a capital return event but there are no remaining acquisitions to match against.")
      }

      var transactionsBeforeEvent: [TransactionToMatch] = []
      while acquisitionsIndex < state.pendingAcquisitions.endIndex {
        let acquisition = state.pendingAcquisitions[acquisitionsIndex]
        if acquisition.date < assetEvent.date {
          transactionsBeforeEvent.append(acquisition)
          acquisitionsIndex += 1
        } else {
          break
        }
      }

      while disposalsIndex < state.pendingDisposals.endIndex {
        let disposal = state.pendingDisposals[disposalsIndex]
        if disposal.date < assetEvent.date {
          transactionsBeforeEvent.append(disposal)
          disposalsIndex += 1
        } else {
          break
        }
      }

      transactionsBeforeEvent.sort { $0.date < $1.date }

      var acquisitionsMatched: [TransactionTuple] = []
      var netAcquisitionsAmount = Decimal.zero

      try transactionsBeforeEvent.forEach { transaction in
        switch transaction.transaction.kind {
        case .Buy:
          let transactionTuple = TransactionTuple(transaction: transaction)
          acquisitionsMatched.append(transactionTuple)
          netAcquisitionsAmount += transaction.amount
        case .Sell:
          // Run over all acquisitions to now and remove this sale in a FIFO way
          var amountLeft = transaction.amount

          // First remove from the running total
          let amountToRemoveFromRunningTotal = min(runningTotal, amountLeft)
          if amountToRemoveFromRunningTotal > Decimal.zero {
            runningTotal -= amountToRemoveFromRunningTotal
            amountLeft -= amountToRemoveFromRunningTotal
          }

          // Then remove from the acquisitions since the last capital return event, up until this sale
          acquisitionsMatched.forEach { acquisitionTransaction in
            guard amountLeft > Decimal.zero else { return }
            let amountToRemove = min(acquisitionTransaction.amountLeft, amountLeft)
            acquisitionTransaction.amountLeft -= amountToRemove
            amountLeft -= amountToRemove
          }

          guard amountLeft == Decimal.zero else {
            throw CalculatorError
              .InvalidData(
                "Error pre-processing \(state.asset). When processing capital returns, sold more than currently hold.")
          }

          let netTransactionAmount = transaction.amount - amountToRemoveFromRunningTotal
          netAcquisitionsAmount -= netTransactionAmount
        }
      }

      guard amount == netAcquisitionsAmount else {
        throw CalculatorError
          .InvalidData(
            "Error pre-processing \(state.asset). Capital return amount \(amount) doesn't match acquisitions \(netAcquisitionsAmount).")
      }

      acquisitionsMatched.forEach { acquisition in
        guard acquisition.amountLeft > Decimal.zero else { return }
        let apportionedValue = value * (acquisition.amountLeft / amount)
        self.logger.debug("    - Matching to acquisition \(acquisition), apportioned value of \(apportionedValue).")
        acquisition.transaction.subtractOffset(amount: apportionedValue)
      }

      runningTotal += amount
      assetEventsIndex += 1
    }

    // Second go over all the dividends and increase the price paid for acquisitions.
    assetEventsIndex = state.assetEvents.startIndex
    while assetEventsIndex < state.assetEvents.endIndex {
      let assetEvent = state.assetEvents[assetEventsIndex]

      let amount: Decimal
      let value: Decimal
      switch assetEvent.kind {
      case .Dividend(let a, let v):
        amount = a
        value = v
      default:
        assetEventsIndex += 1
        continue
      }

      self.logger.debug(" - Processing dividend event: \(assetEvent).")

      var acquisitionsIndex = state.pendingAcquisitions.startIndex
      var disposalsIndex = state.pendingDisposals.startIndex

      var transactionsBeforeEvent: [TransactionToMatch] = []
      while acquisitionsIndex < state.pendingAcquisitions.endIndex {
        let acquisition = state.pendingAcquisitions[acquisitionsIndex]
        if acquisition.date < assetEvent.date {
          transactionsBeforeEvent.append(acquisition)
          acquisitionsIndex += 1
        } else {
          break
        }
      }

      while disposalsIndex < state.pendingDisposals.endIndex {
        let disposal = state.pendingDisposals[disposalsIndex]
        if disposal.date < assetEvent.date {
          transactionsBeforeEvent.append(disposal)
          disposalsIndex += 1
        } else {
          break
        }
      }

      transactionsBeforeEvent.sort { $0.date < $1.date }

      var acquisitionsMatched: [TransactionTuple] = []
      var netAcquisitionsAmount = Decimal.zero

      try transactionsBeforeEvent.forEach { transaction in
        switch transaction.transaction.kind {
        case .Buy:
          let transactionTuple = TransactionTuple(transaction: transaction)
          acquisitionsMatched.append(transactionTuple)
          netAcquisitionsAmount += transaction.amount
        case .Sell:
          // Run over all acquisitions to now and remove this sale in a FIFO way
          var amountLeft = transaction.amount
          acquisitionsMatched.forEach { acquisitionTransaction in
            guard amountLeft > Decimal.zero else { return }
            let amountToRemove = min(acquisitionTransaction.amountLeft, amountLeft)
            acquisitionTransaction.amountLeft -= amountToRemove
            amountLeft -= amountToRemove
          }
          guard amountLeft == Decimal.zero else {
            throw CalculatorError
              .InvalidData(
                "Error pre-processing \(state.asset). When processing dividends, sold more than currently hold.")
          }
          netAcquisitionsAmount -= transaction.amount
        }
      }

      guard amount == netAcquisitionsAmount else {
        throw CalculatorError
          .InvalidData(
            "Error pre-processing \(state.asset). Dividend amount \(amount) doesn't match acquisitions \(netAcquisitionsAmount).")
      }

      acquisitionsMatched.forEach { acquisition in
        guard acquisition.amountLeft > Decimal.zero else { return }
        let apportionedValue = value * (acquisition.amountLeft / amount)
        self.logger.debug("    - Matching to acquisition \(acquisition), apportioned value of \(apportionedValue).")
        acquisition.transaction.addOffset(amount: apportionedValue)
      }

      assetEventsIndex += 1
    }

    self.logger.info("Finished pre-processing transactions for \(state.asset).")
  }

  private func processAsset(withState state: AssetProcessorState) throws -> AssetResult {
    self.logger.info("Begin processing transactions for \(state.asset).")

    let matchingProcessor = MatchingProcessor(state: state, logger: self.logger)
    try matchingProcessor.process()

    let section104Processor = Section104Processor(state: state, logger: self.logger)
    try section104Processor.process()

    if !state.isComplete {
      throw CalculatorError.Incomplete
    }

    self.logger.debug("Tax events for \(state.asset)")
    state.disposalMatches.forEach { self.logger.debug("  \($0)") }
    self.logger
      .info("Finished processing transactions for \(state.asset). Created \(state.disposalMatches.count) tax events.")

    return AssetResult(asset: state.asset, disposalMatches: state.disposalMatches)
  }
}
