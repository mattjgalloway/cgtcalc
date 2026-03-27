import Foundation

// MARK: - Section 104 Holding

public enum CalculationError: Error, LocalizedError {
  case insufficientShares(asset: String, date: Date, requested: Decimal, matched: Decimal)
  case unsupportedInputDate(date: Date, minimumDate: Date)
  case unsupportedLaterAcquisitionIdentification(
    asset: String,
    date: Date,
    requested: Decimal,
    matched: Decimal,
    firstLaterAcquisitionDate: Date)
  case invalidAssetEventAmount(asset: String, date: Date, type: AssetEventType, expected: Decimal, actual: Decimal)

  /// Human-readable explanation for a calculation failure.
  public var errorDescription: String? {
    switch self {
    case .insufficientShares(let asset, let date, let requested, let matched):
      "Insufficient shares for \(asset) on \(DateParser.format(date)): tried to sell \(requested), but only \(matched) could be matched"
    case .unsupportedInputDate(let date, let minimumDate):
      "Unsupported input date \(DateParser.format(date)): dates before \(DateParser.format(minimumDate)) are not supported"
    case .unsupportedLaterAcquisitionIdentification(
      let asset,
      let date,
      let requested,
      let matched,
      let firstLaterAcquisitionDate):
      "Unsupported share-identification case for \(asset) on \(DateParser.format(date)): matched \(matched) of \(requested) using same-day/30-day/Section 104 rules, and found later acquisitions from \(DateParser.format(firstLaterAcquisitionDate)). HMRC's later-acquisition fallback stage is not currently implemented."
    case .invalidAssetEventAmount(let asset, let date, let type, let expected, let actual):
      "Invalid \(type.rawValue) amount for \(asset) on \(DateParser.format(date)): expected \(expected), got \(actual)"
    }
  }
}

public struct Section104Holding {
  public var quantity: Decimal
  public var costBasis: Decimal
  public var pool: [Section104Match]

  /// Creates a Section 104 holding state.
  /// - Parameters:
  ///   - quantity: Total pooled quantity.
  ///   - costBasis: Total pooled allowable cost.
  ///   - pool: Provenance entries used for explanation and pool depletion.
  public init(
    quantity: Decimal = 0,
    costBasis: Decimal = 0,
    pool: [Section104Match] = [])
  {
    self.quantity = quantity
    self.costBasis = costBasis
    self.pool = pool
  }

  public var averageCost: Decimal {
    guard self.quantity > 0 else { return 0 }
    return self.costBasis / self.quantity
  }
}

public struct Section104Match: Identifiable {
  public let id: UUID
  public let transactionId: UUID
  public let sourceOrder: Int?
  public let quantity: Decimal
  public let cost: Decimal
  public let date: Date
  // Original pool state at time of sale
  public let poolQuantity: Decimal
  public let poolCost: Decimal

  /// Creates a Section 104 provenance or disposal match entry.
  /// - Parameters:
  ///   - id: Stable identifier for encoding.
  ///   - transactionId: Source buy transaction identifier.
  ///   - sourceOrder: Parsed source order of the source buy, if known.
  ///   - quantity: Quantity represented by this entry.
  ///   - cost: Allowable cost attributed to the quantity.
  ///   - date: Source buy date.
  ///   - poolQuantity: Total pool quantity at pricing time.
  ///   - poolCost: Total pool cost at pricing time.
  public init(
    id: UUID = UUID(),
    transactionId: UUID,
    sourceOrder: Int? = nil,
    quantity: Decimal,
    cost: Decimal,
    date: Date,
    poolQuantity: Decimal,
    poolCost: Decimal)
  {
    self.id = id
    self.transactionId = transactionId
    self.sourceOrder = sourceOrder
    self.quantity = quantity
    self.cost = cost
    self.date = date
    self.poolQuantity = poolQuantity
    self.poolCost = poolCost
  }

  public var unitCost: Decimal {
    guard self.quantity > 0 else { return 0 }
    return self.cost / self.quantity
  }

  public var poolUnitCost: Decimal {
    guard self.poolQuantity > 0 else { return 0 }
    return self.poolCost / self.poolQuantity
  }
}

// MARK: - Bed and Breakfast Match

public struct BedAndBreakfastMatch: Identifiable {
  public let id: UUID
  public let buyTransaction: Transaction
  public let quantity: Decimal
  public let buyDateQuantity: Decimal
  public let eventAdjustment: Decimal
  public let cost: Decimal

  /// Creates a same-day or 30-day rebuy match for a disposal.
  /// - Parameters:
  ///   - id: Stable identifier for encoding.
  ///   - buyTransaction: The matched rebuy transaction.
  ///   - quantity: Quantity matched on the sell-date basis.
  ///   - buyDateQuantity: Quantity on the rebuy's own basis after restructure adjustment.
  ///   - eventAdjustment: Net post-buy CAPRETURN and DIVIDEND adjustment.
  ///   - cost: Final allowable cost for the matched quantity.
  public init(
    id: UUID = UUID(),
    buyTransaction: Transaction,
    quantity: Decimal,
    buyDateQuantity: Decimal,
    eventAdjustment: Decimal,
    cost: Decimal)
  {
    self.id = id
    self.buyTransaction = buyTransaction
    self.quantity = quantity
    self.buyDateQuantity = buyDateQuantity
    self.eventAdjustment = eventAdjustment
    self.cost = cost
  }

  public var restructureMultiplier: Decimal {
    guard self.quantity != 0 else { return 1 }
    return self.buyDateQuantity / self.quantity
  }
}

// MARK: - Disposal

public struct Disposal: Identifiable {
  public let id: UUID
  public let sellTransaction: Transaction
  public let taxYear: TaxYear
  public let gain: Decimal
  public let section104Matches: [Section104Match]
  public let bedAndBreakfastMatches: [BedAndBreakfastMatch]

  /// Creates a completed disposal record.
  /// - Parameters:
  ///   - id: Stable identifier for encoding.
  ///   - sellTransaction: The effective disposal transaction.
  ///   - taxYear: Tax year containing the disposal.
  ///   - gain: Rounded gain or loss.
  ///   - section104Matches: Section 104 matches used for pricing.
  ///   - bedAndBreakfastMatches: Same-day and 30-day rebuy matches used for pricing.
  public init(
    id: UUID = UUID(),
    sellTransaction: Transaction,
    taxYear: TaxYear,
    gain: Decimal,
    section104Matches: [Section104Match],
    bedAndBreakfastMatches: [BedAndBreakfastMatch])
  {
    self.id = id
    self.sellTransaction = sellTransaction
    self.taxYear = taxYear
    self.gain = gain
    self.section104Matches = section104Matches
    self.bedAndBreakfastMatches = bedAndBreakfastMatches
  }

  public var isLoss: Bool {
    self.gain < 0
  }

  public var isGain: Bool {
    self.gain > 0
  }
}

// MARK: - Tax Year Summary

public struct TaxYearSummary {
  public let taxYear: TaxYear
  public let disposals: [Disposal]
  public let totalGain: Decimal
  public let totalLoss: Decimal
  public let netGain: Decimal
  public let exemption: Decimal
  public let taxableGain: Decimal
  public let lossCarryForward: Decimal

  /// Creates a tax-year summary from completed disposals.
  /// - Parameters:
  ///   - taxYear: Tax year being summarized.
  ///   - disposals: Disposals in that tax year.
  ///   - totalGain: Sum of positive disposal gains.
  ///   - totalLoss: Sum of absolute disposal losses.
  ///   - netGain: Gains less losses before exemption and carried losses.
  ///   - exemption: Annual exempt amount for the year.
  ///   - taxableGain: Gain remaining after exemption and loss carry.
  ///   - lossCarryForward: Remaining carried loss after the year is processed.
  public init(
    taxYear: TaxYear,
    disposals: [Disposal],
    totalGain: Decimal,
    totalLoss: Decimal,
    netGain: Decimal,
    exemption: Decimal,
    taxableGain: Decimal,
    lossCarryForward: Decimal)
  {
    self.taxYear = taxYear
    self.disposals = disposals
    self.totalGain = totalGain
    self.totalLoss = totalLoss
    self.netGain = netGain
    self.exemption = exemption
    self.taxableGain = taxableGain
    self.lossCarryForward = lossCarryForward
  }
}

// MARK: - Spouse Transfer

public struct SpouseTransferOut: Identifiable {
  public let id: UUID
  public let transaction: Transaction
  public let costBasis: Decimal

  /// Creates a spouse/civil-partner transfer-out record costed using disposal identification rules.
  /// - Parameters:
  ///   - id: Stable identifier for encoding.
  ///   - transaction: The source `SPOUSEOUT` transaction.
  ///   - costBasis: Total transferred allowable cost.
  public init(
    id: UUID = UUID(),
    transaction: Transaction,
    costBasis: Decimal)
  {
    self.id = id
    self.transaction = transaction
    self.costBasis = costBasis
  }

  public var averageCost: Decimal {
    guard self.transaction.quantity > 0 else { return 0 }
    return self.costBasis / self.transaction.quantity
  }
}

// MARK: - Calculation Result

public struct CalculationResult {
  public let taxYearSummaries: [TaxYearSummary]
  public let transactions: [Transaction]
  public let assetEvents: [AssetEvent]
  public let lossCarryForward: Decimal
  public let holdings: [String: Section104Holding]
  public let spouseTransfersOut: [SpouseTransferOut]

  /// Creates the full calculator output model.
  /// - Parameters:
  ///   - taxYearSummaries: Per-year disposal summaries.
  ///   - transactions: Original parsed transactions in input order.
  ///   - assetEvents: Original parsed asset events in input order.
  ///   - lossCarryForward: Remaining carried loss after all years.
  ///   - holdings: Final Section 104 holdings by asset.
  public init(
    taxYearSummaries: [TaxYearSummary],
    transactions: [Transaction],
    assetEvents: [AssetEvent],
    lossCarryForward: Decimal,
    holdings: [String: Section104Holding] = [:],
    spouseTransfersOut: [SpouseTransferOut] = [])
  {
    self.taxYearSummaries = taxYearSummaries
    self.transactions = transactions
    self.assetEvents = assetEvents
    self.lossCarryForward = lossCarryForward
    self.holdings = holdings
    self.spouseTransfersOut = spouseTransfersOut
  }
}
