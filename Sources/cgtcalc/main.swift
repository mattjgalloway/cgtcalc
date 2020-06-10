//
//  Transaction.swift
//  cgtcalc
//
//  Created by Matt Galloway on 06/06/2020.
//

import ArgumentParser
import CGTCalcCore
import Foundation

struct CGTCalc: ParsableCommand {
  @Argument(help: "The input data filename")
  var filename: String

  @Flag(name: .shortAndLong, help: "Enable verbose logging")
  var verbose: Bool

  @Option(name: .shortAndLong, help: "Output file")
  var outputFile: String?

  static var configuration = CommandConfiguration(commandName: "cgtcalc")

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

      if let outputFile = self.outputFile, outputFile != "-" {
        let outputFileUrl = URL(fileURLWithPath: outputFile)
        try output.write(to: outputFileUrl, atomically: true, encoding: .utf8)
      } else {
        print(output)
      }
    } catch {
      print("Failed: \(error)")
    }
  }
}

CGTCalc.main()
