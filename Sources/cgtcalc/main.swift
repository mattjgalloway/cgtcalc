//
//  Transaction.swift
//  cgtcalc
//
//  Created by Matt Galloway on 06/06/2020.
//

import ArgumentParser
import CGTCalcCore

struct CGTCalc: ParsableCommand {
  @Argument(help: "The input data filename")
  var filename: String

  @Flag(name: .shortAndLong, help: "Enable verbose logging")
  var verbose: Bool

  func run() throws {
    do {
      let logger = BasicLogger()
      if self.verbose {
        logger.level = .Debug
      }

      let data = try String(contentsOfFile: filename)
      let parser = DefaultParser()
      let transactions = try parser.transactions(fromData: data)

      let calculator = try Calculator(transactions: transactions, logger: logger)
      let result = try calculator.process()

      let presenter = TextPresenter(result: result)
      let output = try presenter.process()
      print("\n")
      print(output)
    } catch {
      print("Failed: \(error)")
    }
  }
}

CGTCalc.main()
