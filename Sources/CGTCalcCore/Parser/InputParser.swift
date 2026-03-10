import Foundation

// MARK: - Date Formatter

public enum DateParser {
  private static let formatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd/MM/yyyy"
    formatter.locale = Locale(identifier: "en_GB")
    formatter.calendar = UTC.calendar
    formatter.timeZone = UTC.timeZone
    return formatter
  }()

  /// Parses a `dd/MM/yyyy` date string into a `Date`.
  /// - Parameter string: The raw date string from input.
  /// - Returns: The parsed date.
  public static func parse(_ string: String) throws -> Date {
    guard let date = formatter.date(from: string) else {
      throw ParserError.invalidDate(string)
    }
    guard self.format(date) == string else {
      throw ParserError.invalidDate(string)
    }
    return date
  }

  /// Formats a `Date` using the project input/output date format.
  /// - Parameter date: The date to render.
  /// - Returns: A `dd/MM/yyyy` string.
  public static func format(_ date: Date) -> String {
    self.formatter.string(from: date)
  }
}

// MARK: - Parser Error

public enum ParserError: Error, LocalizedError {
  case invalidDate(String)
  case invalidNumber(String)
  case invalidField(line: Int, field: String, reason: String)
  case insufficientFields(line: Int, expected: Int, got: Int)
  case unknownLineType(line: Int)

  public var errorDescription: String? {
    switch self {
    case .invalidDate(let string):
      "Invalid date: \(string)"
    case .invalidNumber(let string):
      "Invalid number: \(string)"
    case .invalidField(let line, let field, let reason):
      "Line \(line): Invalid \(field): \(reason)"
    case .insufficientFields(let line, let expected, let got):
      "Line \(line): Expected \(expected) fields, got \(got)"
    case .unknownLineType(let line):
      "Line \(line): Unknown line type"
    }
  }
}

// MARK: - Input Parser

public enum InputParser {
  /// Loads and parses calculator input rows from a UTF-8 file.
  /// - Parameter fileURL: File location for the input text.
  /// - Returns: Parsed transactions and asset events in input order.
  public static func parse(fileURL: URL) throws -> [InputData] {
    let content = try String(contentsOf: fileURL, encoding: .utf8)
    return try self.parse(content: content)
  }

  /// Parses calculator input text into transactions and asset events.
  /// - Parameter content: Raw input file contents.
  /// - Returns: Parsed rows in source order, excluding comments and blank lines.
  public static func parse(content: String) throws -> [InputData] {
    var results: [InputData] = []
    let lines = content.components(separatedBy: .newlines)
    var sourceOrder = 0

    for (index, line) in lines.enumerated() {
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      // Skip empty lines and comments
      if trimmed.isEmpty || trimmed.hasPrefix("#") {
        continue
      }

      let fields = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
      guard !fields.isEmpty else { continue }

      let data = try parseLine(fields: fields, lineNumber: index + 1, sourceOrder: sourceOrder)
      results.append(data)
      sourceOrder += 1
    }

    return results
  }

  /// Parses one tokenized input line into a typed row.
  /// - Parameters:
  ///   - fields: Whitespace-split input fields.
  ///   - lineNumber: Source line number for diagnostics.
  ///   - sourceOrder: Zero-based order among parsed rows.
  /// - Returns: A transaction or asset event.
  private static func parseLine(fields: [String], lineNumber: Int, sourceOrder: Int) throws -> InputData {
    let type = fields[0]

    switch type {
    case "BUY", "SELL":
      guard fields.count >= 6 else {
        throw ParserError.insufficientFields(line: lineNumber, expected: 6, got: fields.count)
      }
      let transaction = try parseTransaction(fields: fields, lineNumber: lineNumber, sourceOrder: sourceOrder)
      return .transaction(transaction)

    case "CAPRETURN", "DIVIDEND":
      guard fields.count >= 5 else {
        throw ParserError.insufficientFields(line: lineNumber, expected: 5, got: fields.count)
      }
      let event = try parseAssetEvent(fields: fields, lineNumber: lineNumber, sourceOrder: sourceOrder)
      return .assetEvent(event)

    case "SPLIT", "UNSPLIT", "RESTRUCT":
      guard fields.count >= 4 else {
        throw ParserError.insufficientFields(line: lineNumber, expected: 4, got: fields.count)
      }
      let event = try parseAssetEvent(fields: fields, lineNumber: lineNumber, sourceOrder: sourceOrder)
      return .assetEvent(event)

    default:
      throw ParserError.unknownLineType(line: lineNumber)
    }
  }

  /// Parses a BUY or SELL row into a transaction model.
  /// - Parameters:
  ///   - fields: Tokenized input fields.
  ///   - lineNumber: Source line number for diagnostics.
  ///   - sourceOrder: Zero-based order among parsed rows.
  /// - Returns: A populated transaction.
  private static func parseTransaction(fields: [String], lineNumber: Int, sourceOrder: Int) throws -> Transaction {
    let date = try DateParser.parse(fields[1])
    let asset = fields[2]
    let quantity = try parseDecimal(fields[3], lineNumber: lineNumber)
    let price = try parseDecimal(fields[4], lineNumber: lineNumber)
    let expenses = try parseDecimal(fields[5], lineNumber: lineNumber)

    try self.validatePositive(quantity, field: "quantity", lineNumber: lineNumber)
    try self.validateNonNegative(price, field: "price", lineNumber: lineNumber)
    try self.validateNonNegative(expenses, field: "expenses", lineNumber: lineNumber)

    return Transaction(
      sourceOrder: sourceOrder,
      type: fields[0] == "BUY" ? .buy : .sell,
      date: date,
      asset: asset,
      quantity: quantity,
      price: price,
      expenses: expenses)
  }

  /// Parses a CAPRETURN, DIVIDEND, SPLIT, UNSPLIT, or RESTRUCT row into an asset-event model.
  /// - Parameters:
  ///   - fields: Tokenized input fields.
  ///   - lineNumber: Source line number for diagnostics.
  ///   - sourceOrder: Zero-based order among parsed rows.
  /// - Returns: A populated asset event.
  private static func parseAssetEvent(fields: [String], lineNumber: Int, sourceOrder: Int) throws -> AssetEvent {
    let type: AssetEventType = switch fields[0] {
    case "CAPRETURN":
      .capitalReturn
    case "DIVIDEND":
      .dividend
    case "SPLIT":
      .split
    case "RESTRUCT":
      .restruct
    default:
      .unsplit
    }

    let date = try DateParser.parse(fields[1])
    let asset = fields[2]

    switch type {
    case .capitalReturn, .dividend:
      let amount = try parseDecimal(fields[3], lineNumber: lineNumber)
      let value = try parseDecimal(fields[4], lineNumber: lineNumber)
      try self.validatePositive(amount, field: "amount", lineNumber: lineNumber)
      try self.validateNonNegative(value, field: "value", lineNumber: lineNumber)
      return AssetEvent(
        sourceOrder: sourceOrder,
        type: type,
        date: date,
        asset: asset,
        distributionAmount: amount,
        distributionValue: value)

    case .split, .unsplit:
      let multiplier = try parseDecimal(fields[3], lineNumber: lineNumber)
      try self.validatePositive(multiplier, field: "multiplier", lineNumber: lineNumber)
      return AssetEvent(sourceOrder: sourceOrder, type: type, date: date, asset: asset, multiplier: multiplier)

    case .restruct:
      let (oldUnits, newUnits) = try self.parseRestructureRatio(fields[3], lineNumber: lineNumber)
      return AssetEvent(sourceOrder: sourceOrder, date: date, asset: asset, oldUnits: oldUnits, newUnits: newUnits)
    }
  }

  /// Parses an exact ratio in `<OLD>:<NEW>` form for RESTRUCT.
  private static func parseRestructureRatio(_ ratio: String,
                                            lineNumber: Int) throws -> (oldUnits: Decimal, newUnits: Decimal)
  {
    let components = ratio.split(separator: ":", omittingEmptySubsequences: false)
    guard components.count == 2 else {
      throw ParserError.invalidField(line: lineNumber, field: "ratio", reason: "must be in OLD:NEW format")
    }
    let oldUnits = try self.parseDecimal(String(components[0]), lineNumber: lineNumber)
    let newUnits = try self.parseDecimal(String(components[1]), lineNumber: lineNumber)
    try self.validatePositive(oldUnits, field: "ratio old units", lineNumber: lineNumber)
    try self.validatePositive(newUnits, field: "ratio new units", lineNumber: lineNumber)
    return (oldUnits, newUnits)
  }

  /// Parses a decimal field after stripping optional pound signs and thousands separators.
  /// - Parameters:
  ///   - string: Raw numeric field text.
  ///   - lineNumber: Source line number for diagnostics.
  /// - Returns: The parsed decimal value.
  private static func parseDecimal(_ string: String, lineNumber: Int) throws -> Decimal {
    // Handle £ symbol and commas
    let cleaned = string
      .replacingOccurrences(of: "£", with: "")
      .replacingOccurrences(of: ",", with: "")

    guard let decimal = Decimal(string: cleaned) else {
      throw ParserError.invalidNumber(string)
    }
    return decimal
  }

  /// Validates that a parsed field is strictly positive.
  /// - Parameters:
  ///   - value: Parsed decimal value.
  ///   - field: Field name for diagnostics.
  ///   - lineNumber: Source line number for diagnostics.
  private static func validatePositive(_ value: Decimal, field: String, lineNumber: Int) throws {
    guard value > 0 else {
      throw ParserError.invalidField(line: lineNumber, field: field, reason: "must be greater than zero")
    }
  }

  /// Validates that a parsed field is not negative.
  /// - Parameters:
  ///   - value: Parsed decimal value.
  ///   - field: Field name for diagnostics.
  ///   - lineNumber: Source line number for diagnostics.
  private static func validateNonNegative(_ value: Decimal, field: String, lineNumber: Int) throws {
    guard value >= 0 else {
      throw ParserError.invalidField(line: lineNumber, field: field, reason: "must not be negative")
    }
  }
}
