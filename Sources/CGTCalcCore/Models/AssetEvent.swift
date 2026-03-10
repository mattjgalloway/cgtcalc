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
  enum Kind {
    case capitalReturn(amount: Decimal, value: Decimal)
    case dividend(amount: Decimal, value: Decimal)
    case split(multiplier: Decimal)
    case unsplit(multiplier: Decimal)
    case restruct(oldUnits: Decimal, newUnits: Decimal)
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
