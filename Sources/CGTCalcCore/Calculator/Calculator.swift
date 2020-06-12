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
    let transactionsByAsset = self.input.transactions
      .reduce(into: [String:[Transaction]]()) { (result, transaction) in
        var transactions = result[transaction.asset, default: []]
        transactions.append(transaction)
        result[transaction.asset] = transactions
      }
    let assetEventsByAsset = self.input.assetEvents
      .reduce(into: [String:[AssetEvent]]()) { (result, assetEvent) in
        var assetEvents = result[assetEvent.asset, default: []]
        assetEvents.append(assetEvent)
        result[assetEvent.asset] = assetEvents
      }

    let allAssets = Set<String>(transactionsByAsset.keys).union(Set<String>(assetEventsByAsset.keys))

    let allDisposalMatches = try allAssets
      .map { asset -> AssetResult in
        let transactions = transactionsByAsset[asset, default: []].sorted { $0.date < $1.date }
        var acquisitions: [SubTransaction] = []
        var disposals: [SubTransaction] = []
        transactions.forEach { transaction in
          let subTransaction = SubTransaction(transaction: transaction)
          switch transaction.kind {
          case .Buy:
            acquisitions.append(subTransaction)
          case .Sell:
            disposals.append(subTransaction)
          }
        }
        let assetEvents = assetEventsByAsset[asset, default: []].sorted { $0.date < $1.date }
        let state = AssetProcessorState(asset: asset, acquisitions: acquisitions, disposals: disposals, assetEvents: assetEvents)
        try self.preprocessAsset(withState: state)
        return try processAsset(withState: state)
      }
      .reduce(into: [DisposalMatch]()) { (disposalMatches, assetResult) in
        disposalMatches.append(contentsOf: assetResult.disposalMatches)
      }

    return try CalculatorResult(input: self.input, disposalMatches: allDisposalMatches)
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

    // First go over all the capital returns and decrease the price paid for acquisitions.
    var acquisitionsIndex = state.pendingAcquisitions.startIndex
    var assetEventsIndex = state.assetEvents.startIndex
    while assetEventsIndex < state.assetEvents.endIndex && acquisitionsIndex < state.pendingAcquisitions.endIndex {
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

      var amountLeft = amount
      while amountLeft > Decimal.zero && acquisitionsIndex < state.pendingAcquisitions.endIndex {
        let acquisition = state.pendingAcquisitions[acquisitionsIndex]
        let apportionedValue = value * (acquisition.amount / amount)
        self.logger.debug("    - Matching to acquisition \(acquisition), apportioned value of \(apportionedValue).")
        acquisition.subtractOffset(amount: apportionedValue)
        amountLeft -= acquisition.amount
        acquisitionsIndex += 1
      }

      if amountLeft != Decimal.zero {
        throw CalculatorError.InvalidData("Error pre-processing \(state.asset). Capital return amount doesn't match acquisitions.")
      }

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

      var amountLeft = amount
      var acquisitionsIndex = state.pendingAcquisitions.startIndex
      while amountLeft > Decimal.zero && acquisitionsIndex < state.pendingAcquisitions.endIndex {
        let acquisition = state.pendingAcquisitions[acquisitionsIndex]
        guard acquisition.date <= assetEvent.date else {
          throw CalculatorError.InvalidData("Error pre-processing \(state.asset) while processing dividend events. Went past asset event date while matching acquisitions.")
        }

        let apportionedValue = value * (acquisition.amount / amount)
        self.logger.debug("    - Matching to acquisition \(acquisition), apportioned value of \(apportionedValue).")
        acquisition.addOffset(amount: apportionedValue)
        amountLeft -= acquisition.amount
        acquisitionsIndex += 1
      }

      if amountLeft != Decimal.zero {
        throw CalculatorError.InvalidData("Error pre-processing \(state.asset) while processing dividend events. Amount doesn't match acquisitions.")
      }

      assetEventsIndex += 1
    }

    self.logger.info("Finished pre-processing transactions for \(state.asset).")
  }

  private func processAsset(withState state: AssetProcessorState) throws -> AssetResult {
    self.logger.info("Begin processing transactions for \(state.asset).")

    let sameDayProcessor = MatchingProcessor(state: state, logger: self.logger) { (acquisition, disposal) in
      if acquisition.date < disposal.date {
        return .SkipAcquisition
      } else if disposal.date < acquisition.date {
        return .SkipDisposal
      } else {
        return .Match(DisposalMatch(kind: .SameDay(acquisition), disposal: disposal))
      }
    }
    try sameDayProcessor.process()

    let bedAndBreakfastProcessor = MatchingProcessor(state: state, logger: self.logger) { (acquisition, disposal) in
      if acquisition.date < disposal.date {
        return .SkipAcquisition
      } else if disposal.date.addingTimeInterval(60*60*24*30) < acquisition.date {
        return .SkipDisposal
      } else {
        return .Match(DisposalMatch(kind: .BedAndBreakfast(acquisition), disposal: disposal))
      }
    }
    try bedAndBreakfastProcessor.process()

    let section104Processor = Section104Processor(state: state, logger: self.logger)
    try section104Processor.process()

    if !state.isComplete {
      throw CalculatorError.Incomplete
    }

    self.logger.debug("Tax events for \(state.asset)")
    state.disposalMatches.forEach { self.logger.debug("  \($0)") }
    self.logger.info("Finished processing transactions for \(state.asset). Created \(state.disposalMatches.count) tax events.")

    return AssetResult(asset: state.asset, disposalMatches: state.disposalMatches)
  }
}
