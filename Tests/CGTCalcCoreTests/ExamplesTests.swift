//
//  ExamplesTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 10/06/2020.
//

import XCTest
import Foundation
@testable import CGTCalcCore

class ExamplesTests: XCTestCase {

  let record = false
  let logger = StubLogger()

  func testExamples() throws {
    let thisFile = URL(fileURLWithPath: #file)
    let examplesDirectory = thisFile.deletingLastPathComponent().appendingPathComponent("Examples")
    let inputsDirectory = examplesDirectory.appendingPathComponent("Inputs")
    let outputsDirectory = examplesDirectory.appendingPathComponent("Outputs")

    let fileManager = FileManager()
    let inputs = try fileManager.contentsOfDirectory(at: inputsDirectory, includingPropertiesForKeys: nil, options: [])

    for inputFile in inputs {
      guard inputFile.pathExtension == "txt" else { continue }

      let testName = inputFile.deletingPathExtension().lastPathComponent
      let outputFile = outputsDirectory.appendingPathComponent(inputFile.lastPathComponent)

      guard record || fileManager.fileExists(atPath: outputFile.path) else {
        XCTFail("Failed to find output for test: \(testName)")
        return
      }

      guard let inputData = try? String(contentsOf: inputFile) else {
        XCTFail("Failed to read input for test: \(testName)")
        return
      }

      do {
        let parser = DefaultParser()
        let input = try parser.calculatorInput(fromData: inputData)
        let calculator = try Calculator(input: input, logger: self.logger)
        let result = try calculator.process()
        let presenter = TextPresenter(result: result)
        let outputData = try presenter.process()

        if record {
          do {
            try outputData.write(to: outputFile, atomically: true, encoding: .utf8)
          } catch {
            XCTFail("Failed to write output data: \(error)")
          }
        } else {
          let compareOutputData = try String(contentsOf: outputFile)
          if outputData != compareOutputData {
            XCTFail("\(testName) failed")
          }
        }
      } catch {
        XCTFail("Failed to process \(testName): \(error)")
      }
    }

    if record {
      XCTFail("Record mode")
    }
  }

  static let allTests = [
    ("testExamples", testExamples),
  ]
}
