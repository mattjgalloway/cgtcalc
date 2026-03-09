import Foundation

// MARK: - Asset Event

public enum AssetEventType: String, Codable, CaseIterable, Sendable {
  case capitalReturn = "CAPRETURN"
  case dividend = "DIVIDEND"
  case split = "SPLIT"
  case unsplit = "UNSPLIT"
  case restruct = "RESTRUCT"
}

public struct AssetEvent: Codable {
  enum Kind: Codable {
    case capitalReturn(amount: Decimal, value: Decimal)
    case dividend(amount: Decimal, value: Decimal)
    case split(multiplier: Decimal)
    case unsplit(multiplier: Decimal)
    case restruct(oldUnits: Decimal, newUnits: Decimal)

    private enum CodingKeys: String, CodingKey {
      case type
      case amount
      case value
      case multiplier
      case oldUnits
      case newUnits
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let type = try container.decode(AssetEventType.self, forKey: .type)
      switch type {
      case .capitalReturn:
        self = try .capitalReturn(
          amount: container.decode(Decimal.self, forKey: .amount),
          value: container.decode(Decimal.self, forKey: .value))
      case .dividend:
        self = try .dividend(
          amount: container.decode(Decimal.self, forKey: .amount),
          value: container.decode(Decimal.self, forKey: .value))
      case .split:
        self = try .split(multiplier: container.decode(Decimal.self, forKey: .multiplier))
      case .unsplit:
        self = try .unsplit(multiplier: container.decode(Decimal.self, forKey: .multiplier))
      case .restruct:
        self = try .restruct(
          oldUnits: container.decode(Decimal.self, forKey: .oldUnits),
          newUnits: container.decode(Decimal.self, forKey: .newUnits))
      }
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      switch self {
      case .capitalReturn(let amount, let value):
        try container.encode(AssetEventType.capitalReturn, forKey: .type)
        try container.encode(amount, forKey: .amount)
        try container.encode(value, forKey: .value)
      case .dividend(let amount, let value):
        try container.encode(AssetEventType.dividend, forKey: .type)
        try container.encode(amount, forKey: .amount)
        try container.encode(value, forKey: .value)
      case .split(let multiplier):
        try container.encode(AssetEventType.split, forKey: .type)
        try container.encode(multiplier, forKey: .multiplier)
      case .unsplit(let multiplier):
        try container.encode(AssetEventType.unsplit, forKey: .type)
        try container.encode(multiplier, forKey: .multiplier)
      case .restruct(let oldUnits, let newUnits):
        try container.encode(AssetEventType.restruct, forKey: .type)
        try container.encode(oldUnits, forKey: .oldUnits)
        try container.encode(newUnits, forKey: .newUnits)
      }
    }
  }

  let id: UUID
  let sourceOrder: Int?
  let date: Date
  let asset: String
  let kind: Kind

  /// Creates an asset event from shared metadata plus specific kind payload.
  init(
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
  init(
    id: UUID = UUID(),
    sourceOrder: Int? = nil,
    type: AssetEventType,
    date: Date,
    asset: String,
    multiplier: Decimal)
  {
    switch type {
    case .split:
      self.init(id: id, sourceOrder: sourceOrder, date: date, asset: asset, kind: .split(multiplier: multiplier))
    case .unsplit:
      self.init(id: id, sourceOrder: sourceOrder, date: date, asset: asset, kind: .unsplit(multiplier: multiplier))
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
  init(
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
  init(
    id: UUID = UUID(),
    sourceOrder: Int? = nil,
    type: AssetEventType,
    date: Date,
    asset: String,
    distributionAmount: Decimal,
    distributionValue: Decimal)
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
      preconditionFailure("type must be CAPRETURN or DIVIDEND")
    }
  }
}
