@testable import CGTCalcCore
import XCTest

/// Tests for InputParser
final class ParserTests: XCTestCase {
  func testParseTransactions() throws {
    let input = """
    BUY 01/01/2020 TEST 100 10.0 5
    SELL 01/02/2020 TEST 50 12.0 3
    """

    let data = try InputParser.parse(content: input)
    XCTAssertEqual(data.count, 2)

    if case .transaction(let t) = data[0] {
      XCTAssertEqual(t.type, .buy)
      XCTAssertEqual(t.asset, "TEST")
      XCTAssertEqual(t.quantity, 100)
      XCTAssertEqual(t.sourceOrder, 0)
    } else {
      XCTFail("Expected transaction")
    }

    if case .transaction(let t) = data[1] {
      XCTAssertEqual(t.type, .sell)
      XCTAssertEqual(t.quantity, 50)
      XCTAssertEqual(t.sourceOrder, 1)
    } else {
      XCTFail("Expected transaction")
    }
  }

  func testParseAssetEvents() throws {
    let input = """
    CAPRETURN 01/01/2020 TEST 100 50.0
    DIVIDEND 01/02/2020 TEST 50 25.0
    SPLIT 01/03/2020 TEST 2
    UNSPLIT 01/04/2020 TEST 0.5
    RESTRUCT 01/05/2020 TEST 3:7
    """

    let data = try InputParser.parse(content: input)
    XCTAssertEqual(data.count, 5)

    if case .assetEvent(let e) = data[0] {
      if case .capitalReturn(let amount, let value) = e.kind {
        XCTAssertEqual(amount, 100)
        XCTAssertEqual(value, 50)
      } else {
        XCTFail("Expected capital return")
      }
      XCTAssertEqual(e.sourceOrder, 0)
    } else {
      XCTFail("Expected asset event")
    }

    if case .assetEvent(let e) = data[1] {
      if case .dividend(let amount, let value) = e.kind {
        XCTAssertEqual(amount, 50)
        XCTAssertEqual(value, 25)
      } else {
        XCTFail("Expected dividend")
      }
      XCTAssertEqual(e.sourceOrder, 1)
    } else {
      XCTFail("Expected asset event")
    }

    if case .assetEvent(let e) = data[2] {
      if case .split(let multiplier) = e.kind {
        XCTAssertEqual(multiplier, 2)
      } else {
        XCTFail("Expected split")
      }
    } else {
      XCTFail("Expected asset event")
    }

    if case .assetEvent(let e) = data[3] {
      if case .unsplit(let multiplier) = e.kind {
        XCTAssertEqual(multiplier, Decimal(string: "0.5"))
      } else {
        XCTFail("Expected unsplit")
      }
    } else {
      XCTFail("Expected asset event")
    }

    if case .assetEvent(let e) = data[4] {
      if case .restruct(let oldUnits, let newUnits) = e.kind {
        XCTAssertEqual(oldUnits, 3)
        XCTAssertEqual(newUnits, 7)
      } else {
        XCTFail("Expected restruct")
      }
    } else {
      XCTFail("Expected asset event")
    }
  }

  func testParseCommentsAndEmptyLines() throws {
    let input = """
    # This is a comment
    BUY 01/01/2020 TEST 100 10.0 5

    SELL 01/02/2020 TEST 50 12.0 3
    """

    let data = try InputParser.parse(content: input)
    XCTAssertEqual(data.count, 2)
  }

  func testParseInvalidDate() {
    let input = """
    BUY invalid_date TEST 100 10.0 5
    """

    XCTAssertThrowsError(try InputParser.parse(content: input))
  }


  func testParseRejectsNonPaddedDate() {
    let input = """
    BUY 1/1/2020 TEST 100 10.0 5
    """

    XCTAssertThrowsError(try InputParser.parse(content: input)) { error in
      guard case ParserError.invalidDate(let invalidDate) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(invalidDate, "1/1/2020")
    }
  }

  func testParseInvalidNumber() {
    let input = """
    BUY 01/01/2020 TEST not_a_number 10.0 5
    """

    XCTAssertThrowsError(try InputParser.parse(content: input))
  }

  func testParseRejectsZeroTransactionQuantity() {
    let input = """
    BUY 01/01/2020 TEST 0 10.0 5
    """

    XCTAssertThrowsError(try InputParser.parse(content: input)) { error in
      guard case ParserError.invalidField(let line, let field, let reason) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(line, 1)
      XCTAssertEqual(field, "quantity")
      XCTAssertEqual(reason, "must be greater than zero")
    }
  }

  func testParseRejectsNegativeExpenses() {
    let input = """
    BUY 01/01/2020 TEST 100 10.0 -5
    """

    XCTAssertThrowsError(try InputParser.parse(content: input)) { error in
      guard case ParserError.invalidField(let line, let field, let reason) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(line, 1)
      XCTAssertEqual(field, "expenses")
      XCTAssertEqual(reason, "must not be negative")
    }
  }

  func testParseRejectsZeroSplitMultiplier() {
    let input = """
    SPLIT 01/03/2020 TEST 0
    """

    XCTAssertThrowsError(try InputParser.parse(content: input)) { error in
      guard case ParserError.invalidField(let line, let field, let reason) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(line, 1)
      XCTAssertEqual(field, "multiplier")
      XCTAssertEqual(reason, "must be greater than zero")
    }
  }

  func testParseRejectsInvalidRestructureRatio() {
    let input = """
    RESTRUCT 01/03/2020 TEST 3-7
    """

    XCTAssertThrowsError(try InputParser.parse(content: input)) { error in
      guard case ParserError.invalidField(let line, let field, let reason) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(line, 1)
      XCTAssertEqual(field, "ratio")
      XCTAssertEqual(reason, "must be in OLD:NEW format")
    }
  }

  func testParseRejectsNegativeAssetEventValue() {
    let input = """
    DIVIDEND 01/02/2020 TEST 50 -25.0
    """

    XCTAssertThrowsError(try InputParser.parse(content: input)) { error in
      guard case ParserError.invalidField(let line, let field, let reason) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(line, 1)
      XCTAssertEqual(field, "value")
      XCTAssertEqual(reason, "must not be negative")
    }
  }

  func testParseInvalidTransactionType() {
    let input = """
    INVALID 01/01/2020 TEST 100 10.0 5
    """

    XCTAssertThrowsError(try InputParser.parse(content: input)) { error in
      guard case ParserError.unknownLineType(let line) = error else {
        return XCTFail("Unexpected error: \(error)")
      }
      XCTAssertEqual(line, 1)
    }
  }

  func testParseInsufficientFields() {
    let input = """
    BUY 01/01/2020 TEST
    """

    XCTAssertThrowsError(try InputParser.parse(content: input))
  }

  func testParseWithPoundSymbol() throws {
    let input = """
    BUY 01/01/2020 TEST 100 10.50 5.00
    """

    let data = try InputParser.parse(content: input)
    XCTAssertEqual(data.count, 1)

    if case .transaction(let t) = data[0] {
      XCTAssertEqual(t.price, 10.50)
      XCTAssertEqual(t.expenses, 5.00)
    }
  }

  func testParseAssignsSourceOrderIgnoringCommentsAndBlankLines() throws {
    let input = """
    # comment

    BUY 01/01/2020 TEST 100 10.0 5
    DIVIDEND 01/02/2020 TEST 100 25.0
    """

    let data = try InputParser.parse(content: input)
    XCTAssertEqual(data.count, 2)

    if case .transaction(let transaction) = data[0] {
      XCTAssertEqual(transaction.sourceOrder, 0)
    } else {
      XCTFail("Expected transaction")
    }

    if case .assetEvent(let event) = data[1] {
      XCTAssertEqual(event.sourceOrder, 1)
    } else {
      XCTFail("Expected asset event")
    }
  }

  func testParseFileURL() throws {
    let content = "BUY 01/01/2020 TEST 10 2.5 1"
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("cgtcalc_parser_test_\(UUID().uuidString).txt")
    try content.write(to: fileURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let data = try InputParser.parse(fileURL: fileURL)
    XCTAssertEqual(data.count, 1)
    guard case .transaction(let transaction) = data[0] else {
      return XCTFail("Expected transaction")
    }
    XCTAssertEqual(transaction.type, .buy)
    XCTAssertEqual(transaction.asset, "TEST")
  }

  func testParserErrorDescriptions() {
    XCTAssertEqual(ParserError.invalidDate("x").errorDescription, "Invalid date: x")
    XCTAssertEqual(ParserError.invalidNumber("x").errorDescription, "Invalid number: x")
    XCTAssertEqual(
      ParserError.invalidField(line: 2, field: "quantity", reason: "must be greater than zero").errorDescription,
      "Line 2: Invalid quantity: must be greater than zero")
    XCTAssertEqual(
      ParserError.insufficientFields(line: 3, expected: 6, got: 4).errorDescription,
      "Line 3: Expected 6 fields, got 4")
    XCTAssertEqual(ParserError.unknownLineType(line: 9).errorDescription, "Line 9: Unknown line type")
  }
}
