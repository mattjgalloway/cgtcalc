import Foundation

public enum CalculationInputError: Error, LocalizedError, Equatable {
  case invalidValue(rowType: String, asset: String, date: Date, field: String, reason: String)

  public var errorDescription: String? {
    switch self {
    case .invalidValue(let rowType, let asset, let date, let field, let reason):
      "Invalid \(rowType) input for \(asset.isEmpty ? "<empty asset>" : asset) on \(DateParser.format(date)): \(field) \(reason)"
    }
  }
}

public enum CalculationInputValidator {
  enum Requirement {
    case nonEmpty
    case positive
    case nonNegative
  }

  public static func validate(transactions: [Transaction], assetEvents: [AssetEvent]) throws {
    for transaction in transactions {
      try self.validate(
        transaction.asset,
        requirement: .nonEmpty,
        rowType: transaction.type.rawValue,
        asset: transaction.asset,
        date: transaction.date,
        field: "asset")
      try self.validate(
        transaction.quantity,
        requirement: .positive,
        rowType: transaction.type.rawValue,
        asset: transaction.asset,
        date: transaction.date,
        field: "quantity")
      try self.validate(
        transaction.price,
        requirement: .nonNegative,
        rowType: transaction.type.rawValue,
        asset: transaction.asset,
        date: transaction.date,
        field: "price")
      try self.validate(
        transaction.expenses,
        requirement: .nonNegative,
        rowType: transaction.type.rawValue,
        asset: transaction.asset,
        date: transaction.date,
        field: "expenses")
      if let explicitTotalCost = transaction.explicitTotalCost {
        try self.validate(
          explicitTotalCost,
          requirement: .nonNegative,
          rowType: transaction.type.rawValue,
          asset: transaction.asset,
          date: transaction.date,
          field: "explicit total cost")
      }
      if let explicitTotalValue = transaction.explicitTotalValue {
        try self.validate(
          explicitTotalValue,
          requirement: .nonNegative,
          rowType: transaction.type.rawValue,
          asset: transaction.asset,
          date: transaction.date,
          field: "explicit total value")
      }
    }

    for event in assetEvents {
      try self.validate(
        event.asset,
        requirement: .nonEmpty,
        rowType: event.type.rawValue,
        asset: event.asset,
        date: event.date,
        field: "asset")
      switch event.kind {
      case .capitalReturn(let amount, let value), .dividend(let amount, let value):
        try self.validate(
          amount,
          requirement: .positive,
          rowType: event.type.rawValue,
          asset: event.asset,
          date: event.date,
          field: "amount")
        try self.validate(
          value,
          requirement: .nonNegative,
          rowType: event.type.rawValue,
          asset: event.asset,
          date: event.date,
          field: "value")
      case .split(let multiplier), .unsplit(let multiplier):
        try self.validate(
          multiplier,
          requirement: .positive,
          rowType: event.type.rawValue,
          asset: event.asset,
          date: event.date,
          field: "multiplier")
      case .restruct(let oldUnits, let newUnits):
        try self.validate(
          oldUnits,
          requirement: .positive,
          rowType: event.type.rawValue,
          asset: event.asset,
          date: event.date,
          field: "ratio old units")
        try self.validate(
          newUnits,
          requirement: .positive,
          rowType: event.type.rawValue,
          asset: event.asset,
          date: event.date,
          field: "ratio new units")
      }
    }
  }

  static func validationReason(for value: Decimal, requirement: Requirement) -> String? {
    switch requirement {
    case .positive:
      value > 0 ? nil : "must be greater than zero"
    case .nonNegative:
      value >= 0 ? nil : "must not be negative"
    case .nonEmpty:
      nil
    }
  }

  static func validationReason(for value: String, requirement: Requirement) -> String? {
    switch requirement {
    case .nonEmpty:
      value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "must not be empty" : nil
    case .positive, .nonNegative:
      nil
    }
  }

  private static func validate(
    _ value: Decimal,
    requirement: Requirement,
    rowType: String,
    asset: String,
    date: Date,
    field: String) throws
  {
    if let reason = self.validationReason(for: value, requirement: requirement) {
      throw CalculationInputError.invalidValue(
        rowType: rowType,
        asset: asset,
        date: date,
        field: field,
        reason: reason)
    }
  }

  private static func validate(
    _ value: String,
    requirement: Requirement,
    rowType: String,
    asset: String,
    date: Date,
    field: String) throws
  {
    if let reason = self.validationReason(for: value, requirement: requirement) {
      throw CalculationInputError.invalidValue(
        rowType: rowType,
        asset: asset,
        date: date,
        field: field,
        reason: reason)
    }
  }
}
