import Foundation

// MARK: - Transaction Types

public enum TransactionType: String {
  case buy = "BUY"
  case sell = "SELL"
  case spouseIn = "SPOUSEIN"
  case spouseOut = "SPOUSEOUT"

  public var isAcquisition: Bool {
    switch self {
    case .buy, .spouseIn:
      true
    case .sell, .spouseOut:
      false
    }
  }

  public var isTaxableDisposal: Bool {
    self == .sell
  }

  public var isSpouseTransferOut: Bool {
    self == .spouseOut
  }
}

// MARK: - Transaction

public struct Transaction: Identifiable {
  public let id: UUID
  public let sourceOrder: Int?
  public let type: TransactionType
  public let date: Date
  public let asset: String
  public let quantity: Decimal
  public let price: Decimal
  public let expenses: Decimal

  /// Creates a buy or sell transaction row.
  /// - Parameters:
  ///   - id: Stable identifier for matching and encoding.
  ///   - sourceOrder: Zero-based parsed row order, if known.
  ///   - type: `BUY` or `SELL`.
  ///   - date: Trade date.
  ///   - asset: Asset identifier.
  ///   - quantity: Quantity traded.
  ///   - price: Per-unit trade price.
  ///   - expenses: Dealing costs for the trade.
  public init(
    id: UUID = UUID(),
    sourceOrder: Int? = nil,
    type: TransactionType,
    date: Date,
    asset: String,
    quantity: Decimal,
    price: Decimal,
    expenses: Decimal)
  {
    self.id = id
    self.sourceOrder = sourceOrder
    self.type = type
    self.date = date
    self.asset = asset
    self.quantity = quantity
    self.price = price
    self.expenses = expenses
  }

  public var totalValue: Decimal {
    self.quantity * self.price
  }

  public var totalCost: Decimal {
    self.totalValue + self.expenses
  }

  public var proceeds: Decimal {
    // Proceeds = full sale amount (quantity * price)
    // Expenses reduce the gain, not proceeds
    self.totalValue
  }
}

// MARK: - Input Data

public enum InputData {
  case transaction(Transaction)
  case assetEvent(AssetEvent)

  public var date: Date {
    switch self {
    case .transaction(let t): t.date
    case .assetEvent(let e): e.date
    }
  }

  public var asset: String {
    switch self {
    case .transaction(let t): t.asset
    case .assetEvent(let e): e.asset
    }
  }
}
