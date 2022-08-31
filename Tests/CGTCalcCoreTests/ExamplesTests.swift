//
//  ExamplesTests.swift
//  CGTCalcCoreTests
//
//  Created by Matt Galloway on 10/06/2020.
//

@testable import CGTCalcCore
import Foundation
import XCTest

class ExamplesTests: XCTestCase {
  let logger = StubLogger()

  private func runTests(inDirectory directory: URL, record: Bool) throws {
    let inputsDirectory = directory.appendingPathComponent("Inputs")
    let outputsDirectory = directory.appendingPathComponent("Outputs")

    let fileManager = FileManager()
    let inputs = try fileManager.contentsOfDirectory(at: inputsDirectory, includingPropertiesForKeys: nil, options: [])

    for inputFile in inputs {
      guard inputFile.pathExtension == "txt" else { continue }

      let testName = inputFile.deletingPathExtension().lastPathComponent

      guard let inputData = try? String(contentsOf: inputFile) else {
        XCTFail("Failed to read input for test: \(testName)")
        return
      }

      let outputFile = outputsDirectory.appendingPathComponent(inputFile.lastPathComponent)
      let outputFileExists = fileManager.fileExists(atPath: outputFile.path)

      let allowRecord = record || !outputFileExists

      guard allowRecord || outputFileExists else {
        XCTFail("Failed to find output for test: \(testName)")
        return
      }

      do {
        let parser = DefaultParser()
        let input = try parser.calculatorInput(fromData: inputData)
        let calculator = try Calculator(input: input, logger: self.logger)
        let result = try calculator.process()
        let presenter = TextPresenter(result: result)
        let output = try presenter.process()

        let outputString: String
        switch output {
        case .data:
          XCTFail("Shouldn't return data")
          return
        case .string(let string):
          outputString = string
        }

        if allowRecord {
          do {
            try outputString.write(to: outputFile, atomically: true, encoding: .utf8)
          } catch {
            XCTFail("Failed to write output data: \(error)")
          }
        } else {
          let compareOutputData = try String(contentsOf: outputFile)
          if outputString != compareOutputData {
            let diffURL = URL(fileURLWithPath: "/usr/bin/diff")
            if fileManager.fileExists(atPath: diffURL.path) {
              let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
              let fileA = tempDirectory.appendingPathComponent(UUID().uuidString)
              let fileB = tempDirectory.appendingPathComponent(UUID().uuidString)

              try compareOutputData.write(to: fileA, atomically: true, encoding: .utf8)
              try outputString.write(to: fileB, atomically: true, encoding: .utf8)

              let stdout = Pipe()
              let diffProcess = Process()
              diffProcess.executableURL = diffURL
              diffProcess.standardOutput = stdout
              diffProcess.arguments = ["-u", fileA.path, fileB.path]
              try diffProcess.run()
              diffProcess.waitUntilExit()

              let output = stdout.fileHandleForReading.readDataToEndOfFile()
              if let string = String(data: output, encoding: .utf8) {
                print(string)
              }

              try fileManager.removeItem(at: fileA)
              try fileManager.removeItem(at: fileB)
            }
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

  func testExamples() throws {
    let thisFile = URL(fileURLWithPath: #file)
    let examplesDirectory = thisFile.deletingLastPathComponent().appendingPathComponent("Examples")
    try self.runTests(inDirectory: examplesDirectory, record: false)
  }

  func testPrivateExamples() throws {
    let thisFile = URL(fileURLWithPath: #file)
    let examplesDirectory = thisFile.deletingLastPathComponent().appendingPathComponent("PrivateExamples")
    if FileManager.default.fileExists(atPath: examplesDirectory.path) {
      try self.runTests(inDirectory: examplesDirectory, record: false)
    }
  }

  static let allTests = [
    ("testExamples", testExamples),
    ("testPrivateExamples", testPrivateExamples)
  ]
}
