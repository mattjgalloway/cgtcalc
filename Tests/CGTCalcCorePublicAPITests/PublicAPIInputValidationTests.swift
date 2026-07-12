import CGTCalcCore
import Foundation
import XCTest

final class PublicAPIInputValidationTests: XCTestCase {
  private let date = try! DateParser.parse("01/01/2020")

  func testRejectsInvalidTransactionValues() {
    let invalidTransactions = [
      Transaction(type: .buy, date: self.date, asset: "TEST", quantity: 0, price: 1, expenses: 0),
      Transaction(type: .buy, date: self.date, asset: "TEST", quantity: -1, price: 1, expenses: 0),
      Transaction(type: .buy, date: self.date, asset: "TEST", quantity: 1, price: -1, expenses: 0),
      Transaction(type: .buy, date: self.date, asset: "TEST", quantity: 1, price: 1, expenses: -1),
      Transaction(
        type: .spouseIn,
        date: self.date,
        asset: "TEST",
        quantity: 1,
        price: 0,
        expenses: 0,
        explicitTotalCost: -1),
      Transaction(
        type: .sell,
        date: self.date,
        asset: "TEST",
        quantity: 1,
        price: 0,
        expenses: 0,
        explicitTotalValue: -1),
      Transaction(type: .buy, date: self.date, asset: "", quantity: 1, price: 1, expenses: 0),
      Transaction(type: .buy, date: self.date, asset: "   ", quantity: 1, price: 1, expenses: 0)
    ]

    for transaction in invalidTransactions {
      self.assertInvalid(transactions: [transaction], assetEvents: [])
    }
  }

  func testRejectsInvalidDistributionValues() {
    let invalidEvents = [
      AssetEvent(date: self.date, asset: "TEST", kind: .dividend(amount: 0, value: 1)),
      AssetEvent(date: self.date, asset: "TEST", kind: .capitalReturn(amount: -1, value: 1)),
      AssetEvent(date: self.date, asset: "TEST", kind: .dividend(amount: 1, value: -1)),
      AssetEvent(date: self.date, asset: "", kind: .dividend(amount: 1, value: 0))
    ]

    for event in invalidEvents {
      self.assertInvalid(transactions: [], assetEvents: [event])
    }
  }

  func testRejectsInvalidRestructureValues() {
    let invalidEvents = [
      AssetEvent(date: self.date, asset: "TEST", kind: .split(multiplier: 0)),
      AssetEvent(date: self.date, asset: "TEST", kind: .unsplit(multiplier: -1)),
      AssetEvent(date: self.date, asset: "TEST", kind: .restruct(oldUnits: 0, newUnits: 1)),
      AssetEvent(date: self.date, asset: "TEST", kind: .restruct(oldUnits: 1, newUnits: -1))
    ]

    for event in invalidEvents {
      self.assertInvalid(transactions: [], assetEvents: [event])
    }
  }

  func testValidDirectInputStillCalculates() throws {
    let transactions = try [
      Transaction(type: .buy, date: self.date, asset: "TEST", quantity: 10, price: 2, expenses: 1),
      Transaction(
        type: .sell,
        date: DateParser.parse("01/06/2020"),
        asset: "TEST",
        quantity: 10,
        price: 3,
        expenses: 1)
    ]

    let result = try CGTEngine.calculate(transactions: transactions, assetEvents: [])

    XCTAssertEqual(result.taxYearSummaries.first?.disposals.first?.rawGain, 8)
  }

  private func assertInvalid(transactions: [Transaction], assetEvents: [AssetEvent]) {
    XCTAssertThrowsError(try CGTEngine.calculate(transactions: transactions, assetEvents: assetEvents)) { error in
      guard error is CalculationInputError else {
        return XCTFail("Unexpected error: \(error)")
      }
    }
  }
}
