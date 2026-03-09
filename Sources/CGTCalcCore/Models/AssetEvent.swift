import Foundation

// MARK: - Asset Event

public enum AssetEventType: String, Codable, CaseIterable, Sendable {
  case capitalReturn = "CAPRETURN"
  case dividend = "DIVIDEND"
  case split = "SPLIT"
  case unsplit = "UNSPLIT"
  case restruct = "RESTRUCT"
}

public struct AssetEvent: Identifiable, Codable {
  public let id: UUID
  public let sourceOrder: Int?
  public let type: AssetEventType
  public let date: Date
  public let asset: String
  public let distributionAmount: Decimal?
  public let distributionValue: Decimal?
  public let restructureOldUnits: Decimal?
  public let restructureNewUnits: Decimal?

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
    self.distributionAmount = nil
    self.distributionValue = nil
    switch type {
    case .split:
      self.restructureOldUnits = 1
      self.restructureNewUnits = multiplier
    case .unsplit:
      self.restructureOldUnits = multiplier
      self.restructureNewUnits = 1
    case .capitalReturn, .dividend, .restruct:
      preconditionFailure("type must be SPLIT or UNSPLIT")
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
    self.id = id
    self.sourceOrder = sourceOrder
    self.type = .restruct
    self.date = date
    self.asset = asset
    self.distributionAmount = nil
    self.distributionValue = nil
    self.restructureOldUnits = oldUnits
    self.restructureNewUnits = newUnits
  }

  /// Convenience initializer for CAPRETURN and DIVIDEND events.
  public init(
    id: UUID = UUID(),
    sourceOrder: Int? = nil,
    type: AssetEventType,
    date: Date,
    asset: String,
    distributionAmount: Decimal,
    distributionValue: Decimal)
  {
    precondition(type == .capitalReturn || type == .dividend, "type must be CAPRETURN or DIVIDEND")
    self.id = id
    self.sourceOrder = sourceOrder
    self.type = type
    self.date = date
    self.asset = asset
    self.distributionAmount = distributionAmount
    self.distributionValue = distributionValue
    self.restructureOldUnits = nil
    self.restructureNewUnits = nil
  }

  public var distribution: (amount: Decimal, value: Decimal)? {
    guard
      let distributionAmount,
      let distributionValue
    else {
      return nil
    }
    return (distributionAmount, distributionValue)
  }

  public var isRestructure: Bool {
    switch self.type {
    case .split, .unsplit, .restruct:
      true
    case .capitalReturn, .dividend:
      false
    }
  }

  /// Returns restructure ratio as old:new units.
  public var restructureRatio: (oldUnits: Decimal, newUnits: Decimal)? {
    guard
      let restructureOldUnits,
      let restructureNewUnits
    else {
      return nil
    }
    return (restructureOldUnits, restructureNewUnits)
  }

  public var splitOrUnsplitMultiplier: Decimal? {
    switch self.type {
    case .split:
      self.restructureNewUnits
    case .unsplit:
      self.restructureOldUnits
    case .capitalReturn, .dividend, .restruct:
      nil
    }
  }
}
