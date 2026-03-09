import Foundation

// MARK: - Transaction Types

public enum TransactionType: String, Codable {
  case buy = "BUY"
  case sell = "SELL"
}

// MARK: - Transaction

public struct Transaction: Identifiable, Codable {
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

public enum InputData: Codable {
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

  private enum CodingKeys: String, CodingKey {
    case type
    case data
  }

  /// Decodes a tagged input row into a transaction or asset-event case.
  /// - Parameter decoder: Decoder positioned at an `InputData` payload.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "BUY", "SELL":
      let transaction = try container.decode(Transaction.self, forKey: .data)
      self = .transaction(transaction)
    case "CAPRETURN", "DIVIDEND", "SPLIT", "UNSPLIT", "RESTRUCT":
      let event = try container.decode(AssetEvent.self, forKey: .data)
      self = .assetEvent(event)
    default:
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown type: \(type)"))
    }
  }

  /// Encodes an `InputData` case using the persisted row type plus payload.
  /// - Parameter encoder: Destination encoder.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .transaction(let t):
      try container.encode(t.type.rawValue, forKey: .type)
      try container.encode(t, forKey: .data)
    case .assetEvent(let e):
      let type = switch e.kind {
      case .capitalReturn:
        AssetEventType.capitalReturn.rawValue
      case .dividend:
        AssetEventType.dividend.rawValue
      case .split:
        AssetEventType.split.rawValue
      case .unsplit:
        AssetEventType.unsplit.rawValue
      case .restruct:
        AssetEventType.restruct.rawValue
      }
      try container.encode(type, forKey: .type)
      try container.encode(e, forKey: .data)
    }
  }
}
