//
//  main.swift
//  cgtcalc
//
//  Created by Matt Galloway on 06/06/2020.
//

import ArgumentParser
import CGTCalcCore
import Foundation

@main
struct CGTCalc: AsyncParsableCommand {
  static let VERSION = "0.1.0"

  @Argument(help: "The input data filename")
  var filename: String

  @Flag(name: .shortAndLong, help: "Enable verbose logging")
  var verbose = false

  @Option(name: .shortAndLong, help: "Output file")
  var outputFile: String?

  static let configuration = CommandConfiguration(commandName: "cgtcalc", version: Self.VERSION)

  func run() async throws {
    let logLevel: BasicLogger.Level
    if self.verbose {
      logLevel = .Debug
    } else {
      logLevel = .Info
    }
    let logger = BasicLogger(level: logLevel)

    do {
      let data = try String(contentsOfFile: filename, encoding: .utf8)
      let parser = DefaultParser()
      let input = try parser.calculatorInput(fromData: data)

      let calculator = try Calculator(input: input, logger: logger)
      let result = try await calculator.process()

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
