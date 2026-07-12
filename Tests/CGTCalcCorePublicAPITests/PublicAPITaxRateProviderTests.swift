import CGTCalcCore
import Foundation
import XCTest

final class PublicAPITaxRateProviderTests: XCTestCase {
  private struct FixedProvider: TaxRateProvider {
    let identifier: String
    let startYear: Int
    let exemption: Decimal

    func rates(for year: TaxYear) -> TaxRates? {
      year.startYear == self.startYear ? TaxRates(exemption: self.exemption) : nil
    }
  }

  func testCustomProviderSupportsFutureTaxYear() throws {
    let provider = FixedProvider(identifier: "future policy", startYear: 2030, exemption: 1000)
    let result = try CGTEngine.calculate(
      transactions: self.futureTransactions(),
      assetEvents: [],
      taxRateProvider: provider)

    XCTAssertEqual(result.taxYearSummaries.first?.exemption, 1000)
    XCTAssertEqual(result.taxYearSummaries.first?.taxableGain, 9000)
  }

  func testMissingYearIdentifiesProvider() throws {
    let provider = FixedProvider(identifier: "empty test policy", startYear: 2040, exemption: 1000)

    XCTAssertThrowsError(try CGTEngine.calculate(
      transactions: self.futureTransactions(),
      assetEvents: [],
      taxRateProvider: provider))
    { error in
      XCTAssertEqual(
        error as? TaxRateProviderError,
        .missingTaxRates(startYear: 2030, providerIdentifier: "empty test policy"))
    }
  }

  func testProvidersAreIsolatedBetweenCalculations() throws {
    let transactions = try self.futureTransactions()
    let first = try CGTEngine.calculate(
      transactions: transactions,
      assetEvents: [],
      taxRateProvider: FixedProvider(identifier: "first", startYear: 2030, exemption: 1000))
    let second = try CGTEngine.calculate(
      transactions: transactions,
      assetEvents: [],
      taxRateProvider: FixedProvider(identifier: "second", startYear: 2030, exemption: 2000))

    XCTAssertEqual(first.taxYearSummaries.first?.taxableGain, 9000)
    XCTAssertEqual(second.taxYearSummaries.first?.taxableGain, 8000)
  }

  private func futureTransactions() throws -> [Transaction] {
    try [
      Transaction(
        type: .buy,
        date: DateParser.parse("01/01/2031"),
        asset: "TEST",
        quantity: 100,
        price: 1,
        expenses: 0),
      Transaction(
        type: .sell,
        date: DateParser.parse("01/03/2031"),
        asset: "TEST",
        quantity: 100,
        price: 101,
        expenses: 0)
    ]
  }
}
