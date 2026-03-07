import Foundation

// MARK: - Asset Event

public enum AssetEventType: String, Codable, CaseIterable, Sendable {
  case capitalReturn = "CAPRETURN"
  case dividend = "DIVIDEND"
  case split = "SPLIT"
  case unsplit = "UNSPLIT"
}

public struct AssetEvent: Identifiable, Codable {
  public let id: UUID
  public let sourceOrder: Int?
  public let type: AssetEventType
  public let date: Date
  public let asset: String
  public let amount: Decimal
  public let value: Decimal

  /// Creates a CAPRETURN, DIVIDEND, SPLIT, or UNSPLIT asset event.
  /// - Parameters:
  ///   - id: Stable identifier for matching and encoding.
  ///   - sourceOrder: Zero-based parsed row order, if known.
  ///   - type: Event type.
  ///   - date: Effective date of the event.
  ///   - asset: Asset identifier.
  ///   - amount: Quantity or multiplier field from input.
  ///   - value: Money value used for cost-basis adjustments.
  public init(
    id: UUID = UUID(),
    sourceOrder: Int? = nil,
    type: AssetEventType,
    date: Date,
    asset: String,
    amount: Decimal,
    value: Decimal)
  {
    self.id = id
    self.sourceOrder = sourceOrder
    self.type = type
    self.date = date
    self.asset = asset
    self.amount = amount
    self.value = value
  }

  /// Convenience initializer for split and reverse-split events.
  /// - Parameters:
  ///   - id: Stable identifier for matching and encoding.
  ///   - sourceOrder: Zero-based parsed row order, if known.
  ///   - type: `SPLIT` or `UNSPLIT`.
  ///   - date: Effective date of the restructure.
  ///   - asset: Asset identifier.
  ///   - multiplier: Share-count multiplier for the restructure.
  public init(
    id: UUID = UUID(),
    sourceOrder: Int? = nil,
    type: AssetEventType,
    date: Date,
    asset: String,
    multiplier: Decimal)
  {
    self.id = id
    self.sourceOrder = sourceOrder
    self.type = type
    self.date = date
    self.asset = asset
    self.amount = multiplier
    self.value = multiplier // For split/unsplit, amount and value are the same (multiplier)
  }
}
