import Foundation

public enum CGTEngine {
  public static func calculate(inputData: [InputData]) throws -> CalculationResult {
    try self.calculate(inputData: inputData, taxRateProvider: BuiltInTaxRateProvider())
  }

  public static func calculate(
    inputData: [InputData],
    taxRateProvider: any TaxRateProvider) throws -> CalculationResult
  {
    let transactions = inputData.compactMap { data -> Transaction? in
      if case .transaction(let transaction) = data { return transaction }
      return nil
    }
    let assetEvents = inputData.compactMap { data -> AssetEvent? in
      if case .assetEvent(let event) = data { return event }
      return nil
    }
    return try self.calculate(
      transactions: transactions,
      assetEvents: assetEvents,
      taxRateProvider: taxRateProvider)
  }

  public static func calculate(transactions: [Transaction], assetEvents: [AssetEvent]) throws -> CalculationResult {
    try self.calculate(
      transactions: transactions,
      assetEvents: assetEvents,
      taxRateProvider: BuiltInTaxRateProvider())
  }

  public static func calculate(
    transactions: [Transaction],
    assetEvents: [AssetEvent],
    taxRateProvider: any TaxRateProvider) throws -> CalculationResult
  {
    try CalculationInputValidator.validate(transactions: transactions, assetEvents: assetEvents)
    try self.validateSupportedDateScope(transactions: transactions, assetEvents: assetEvents)
    try CalculationTimeline.validateSameDateCombinations(transactions: transactions, assetEvents: assetEvents)

    let normalizedTransactions = try self.normalizingSourceOrder(transactions)
    let normalizedEvents = try self.normalizingSourceOrder(assetEvents)
    let calculationEvents = try self.calculationEvents(
      transactions: normalizedTransactions,
      assetEvents: normalizedEvents)

    var session = CalculationSession(
      transactions: normalizedTransactions,
      calculationEvents: calculationEvents)
    let sessionOutput = try session.run()
    let summaryResult = try TaxYearSummarizer.summarize(
      disposals: sessionOutput.disposals,
      taxRateProvider: taxRateProvider)

    return CalculationResult(
      taxYearSummaries: summaryResult.summaries,
      transactions: normalizedTransactions,
      assetEvents: normalizedEvents,
      lossCarryForward: summaryResult.lossCarryForward,
      holdings: sessionOutput.holdings,
      spouseTransfersOut: sessionOutput.spouseTransfersOut)
  }

  private static func calculationEvents(
    transactions: [Transaction],
    assetEvents: [AssetEvent]) throws -> [AssetEvent]
  {
    let groupedEvents = CalculationTimeline.groupDistributions(
      assetEvents.sorted(by: CalculationTimeline.assetEventSortsBefore))
    let transactionsByAsset = Dictionary(grouping: transactions, by: \.asset)
    let eventsByAsset = Dictionary(grouping: groupedEvents, by: \.asset)
    var calculationEvents: [AssetEvent] = []
    for asset in Set(transactionsByAsset.keys).union(eventsByAsset.keys) {
      try calculationEvents.append(contentsOf: AssetEventValidator.normalizingGroupedDistributionAmounts(
        transactions: transactionsByAsset[asset, default: []],
        assetEvents: eventsByAsset[asset, default: []]))
    }
    return calculationEvents.sorted(by: CalculationTimeline.assetEventSortsBefore)
  }

  private static func normalizingSourceOrder(_ transactions: [Transaction]) throws -> [Transaction] {
    if transactions.compactMap(\.sourceOrder).contains(Int.max) {
      throw CalculationError.sourceOrderOverflow(kind: "transactions")
    }
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
        expenses: transaction.expenses,
        explicitTotalCost: transaction.explicitTotalCost,
        explicitTotalValue: transaction.explicitTotalValue)
    }
  }

  private static func normalizingSourceOrder(_ assetEvents: [AssetEvent]) throws -> [AssetEvent] {
    if assetEvents.compactMap(\.sourceOrder).contains(Int.max) {
      throw CalculationError.sourceOrderOverflow(kind: "asset events")
    }
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

  private static var minimumSupportedDate: Date {
    var components = DateComponents()
    components.year = 2008
    components.month = 4
    components.day = 6
    return UTC.calendar.date(from: components)!
  }

  private static func validateSupportedDateScope(
    transactions: [Transaction],
    assetEvents: [AssetEvent]) throws
  {
    let minimumDate = self.minimumSupportedDate
    if let date = transactions.map(\.date).filter({ $0 < minimumDate }).min() {
      throw CalculationError.unsupportedInputDate(date: date, minimumDate: minimumDate)
    }
    if let date = assetEvents.map(\.date).filter({ $0 < minimumDate }).min() {
      throw CalculationError.unsupportedInputDate(date: date, minimumDate: minimumDate)
    }
  }
}
