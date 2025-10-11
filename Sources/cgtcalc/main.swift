//
//  main.swift
//  cgtcalc
//
//  Created by Matt Galloway on 06/06/2020.
//

import ArgumentParser
import CGTCalcCore
import Foundation

let VERSION = "0.1.0"

struct CGTCalc: ParsableCommand {
  @Argument(help: "The input data filename")
  var filename: String

  @Flag(name: .shortAndLong, help: "Enable verbose logging")
  var verbose = false

  @Option(name: .shortAndLong, help: "Output file")
  var outputFile: String?

  static var configuration = CommandConfiguration(commandName: "cgtcalc", version: VERSION)

  func run() throws {
    let logger = BasicLogger()
    if self.verbose {
      logger.level = .Debug
    }

    do {
      let data = try String(contentsOfFile: filename)
      let parser = DefaultParser()
      let input = try parser.calculatorInput(fromData: data)

      let calculator = try Calculator(input: input, logger: logger)
      let result = try calculator.process()

      let presenter = TextPresenter(result: result)
      let output = try presenter.process()

      if let outputFile = self.outputFile, outputFile != "-" {
        let outputFileUrl = URL(fileURLWithPath: outputFile)
        switch output {
        case .data(let data):
          try data.write(to: outputFileUrl)
        case .string(let string):
          try string.write(to: outputFileUrl, atomically: true, encoding: .utf8)
        }
      } else {
        switch output {
        case .data:
          print("Cannot output to console for this presenter. Choose a file to write to instead.")
        case .string(let string):
          print(string)
        }
      }
    } catch {
      logger.error("Failed: \(error)")
    }
  }
}

CGTCalc.main()
