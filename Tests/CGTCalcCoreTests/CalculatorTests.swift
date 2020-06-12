//
//  CalculatorTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 09/06/2020.
//

import XCTest
@testable import CGTCalcCore

class CalculatorTests: XCTestCase {

  let logger = StubLogger()

  func testSamples() throws {
    SampleData.samples.forEach { sample in
      do {
        let input = CalculatorInput(transactions: sample.transactions, assetEvents: sample.assetEvents)
        let calculator = try Calculator(input: input, logger: self.logger)

        let result: CalculatorResult
        if sample.shouldThrow {
          XCTAssertThrowsError(try calculator.process())
          return
        } else {
          result = try calculator.process()
        }

        XCTAssertEqual(result.taxYearSummaries.count, sample.gains.count)
        result.taxYearSummaries.forEach { taxYearSummary in
          guard let gain = sample.gains[taxYearSummary.taxYear] else {
            XCTFail("Unexpected tax year found")
            return
          }
          XCTAssertEqual(gain, taxYearSummary.gain)
        }
      } catch {
        XCTFail("Failed to calculate \(sample.name): \(error)")
      }
    }
  }

  func testDateBefore20080406Throws() throws {
    let transaction = ModelCreation.transaction(1, .Buy, "05/04/2008", "Foo", "1", "1", "0")
    let input = CalculatorInput(transactions: [transaction], assetEvents: [])
    let calculator = try Calculator(input: input, logger: self.logger)
    XCTAssertThrowsError(try calculator.process())
  }

}
