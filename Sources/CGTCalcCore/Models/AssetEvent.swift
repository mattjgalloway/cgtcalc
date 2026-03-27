import Foundation

// MARK: - Asset Event

public enum AssetEventType: String, CaseIterable, Sendable {
  case capitalReturn = "CAPRETURN"
  case dividend = "DIVIDEND"
  case split = "SPLIT"
  case unsplit = "UNSPLIT"
  case restruct = "RESTRUCT"
}

public struct AssetEvent {
  public enum InitializationError: Error, LocalizedError, Equatable {
    case invalidRestructureType(AssetEventType)
    case invalidDistributionType(AssetEventType)

    public var errorDescription: String? {
      switch self {
      case .invalidRestructureType(let type):
        "Invalid restructure initializer type: \(type.rawValue). Expected SPLIT or UNSPLIT."
      case .invalidDistributionType(let type):
        "Invalid distribution initializer type: \(type.rawValue). Expected CAPRETURN or DIVIDEND."
      }
    }
  }

  public enum Kind {
    case capitalReturn(amount: Decimal, value: Decimal)
    case dividend(amount: Decimal, value: Decimal)
    case split(multiplier: Decimal)
    case unsplit(multiplier: Decimal)
    case restruct(oldUnits: Decimal, newUnits: Decimal)
  }

  public let id: UUID
  public let sourceOrder: Int?
  public let date: Date
  public let asset: String
  public let kind: Kind

  /// Creates an asset event from shared metadata plus specific kind payload.
  public init(
    id: UUID = UUID(),
    sourceOrder: Int? = nil,
    date: Date,
    asset: String,
    kind: Kind)
  {
    self.id = id
    self.sourceOrder = sourceOrder
    self.date = date
    self.asset = asset
    self.kind = kind
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
    multiplier: Decimal) throws
  {
    switch type {
    case .split:
      self.init(id: id, sourceOrder: sourceOrder, date: date, asset: asset, kind: .split(multiplier: multiplier))
    case .unsplit:
      self.init(id: id, sourceOrder: sourceOrder, date: date, asset: asset, kind: .unsplit(multiplier: multiplier))
    case .capitalReturn, .dividend, .restruct:
      throw InitializationError.invalidRestructureType(type)
    }
  }

  /// Convenience initializer for exact-ratio restructures.
  /// - Parameters:
  ///   - id: Stable identifier for matching and encoding.
  ///   - sourceOrder: Zero-based parsed row order, if known.
  ///   - date: Effective date of the restructure.
  ///   - asset: Asset identifier.
  ///   - oldUnits: Existing units in the ratio.
  ///   - newUnits: Replacement units in the ratio.
  public init(
    id: UUID = UUID(),
    sourceOrder: Int? = nil,
    date: Date,
    asset: String,
    oldUnits: Decimal,
    newUnits: Decimal)
  {
    self.init(
      id: id,
      sourceOrder: sourceOrder,
      date: date,
      asset: asset,
      kind: .restruct(oldUnits: oldUnits, newUnits: newUnits))
  }

  /// Convenience initializer for CAPRETURN and DIVIDEND events.
  public init(
    id: UUID = UUID(),
    sourceOrder: Int? = nil,
    type: AssetEventType,
    date: Date,
    asset: String,
    distributionAmount: Decimal,
    distributionValue: Decimal) throws
  {
    switch type {
    case .capitalReturn:
      self.init(
        id: id,
        sourceOrder: sourceOrder,
        date: date,
        asset: asset,
        kind: .capitalReturn(amount: distributionAmount, value: distributionValue))
    case .dividend:
      self.init(
        id: id,
        sourceOrder: sourceOrder,
        date: date,
        asset: asset,
        kind: .dividend(amount: distributionAmount, value: distributionValue))
    case .split, .unsplit, .restruct:
      throw InitializationError.invalidDistributionType(type)
    }
  }
}
