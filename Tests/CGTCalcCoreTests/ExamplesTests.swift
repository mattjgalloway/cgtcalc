@testable import CGTCalcCore
import Foundation
import XCTest

final class ExamplesTests: XCTestCase {
  /// Set this true to re-record all expected outputs, then set back to false.
  private let recordMode = false

  func testAllExamples() throws {
    let (inputsDir, outputsDir) = try self.fixtureDirectories(
      suiteName: "Examples",
      privateSuite: false)
    try self.runFixtureSuite(
      inputsDir: inputsDir,
      outputsDir: outputsDir,
      runLikeCLI: false,
      failureLabel: "FAILED")
  }

  func testAllInvalidExamples() throws {
    let (inputsDir, outputsDir) = try self.fixtureDirectories(
      suiteName: "InvalidExamples",
      privateSuite: false)
    try self.runFixtureSuite(
      inputsDir: inputsDir,
      outputsDir: outputsDir,
      runLikeCLI: true,
      failureLabel: "FAILED INVALID EXAMPLE")
  }

  func testAllPrivateExamples() throws {
    let (inputsDir, outputsDir) = try self.fixtureDirectories(
      suiteName: "PrivateExamples",
      privateSuite: true)
    try self.runFixtureSuite(
      inputsDir: inputsDir,
      outputsDir: outputsDir,
      runLikeCLI: false,
      failureLabel: "FAILED PRIVATE EXAMPLE")
  }

  /// Executes one fixture suite by reading inputs, producing output, and either recording or asserting.
  private func runFixtureSuite(
    inputsDir: URL,
    outputsDir: URL,
    runLikeCLI: Bool,
    failureLabel: String) throws
  {
    let fileManager = FileManager.default
    let inputFiles = try fileManager.contentsOfDirectory(at: inputsDir, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "txt" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }

    for inputFile in inputFiles {
      let filename = inputFile.lastPathComponent
      let outputFile = outputsDir.appendingPathComponent(filename)

      let input = try String(contentsOf: inputFile, encoding: .utf8)
      let actualOutput = runLikeCLI ? self.runLikeCLI(content: input) : try self.runStandard(content: input)

      if self.recordMode {
        try actualOutput.write(to: outputFile, atomically: true, encoding: .utf8)
        continue
      }

      guard fileManager.fileExists(atPath: outputFile.path) else {
        XCTFail("Missing expected output file: \(outputFile.lastPathComponent)")
        continue
      }

      let expectedOutput = try String(contentsOf: outputFile, encoding: .utf8)

      if actualOutput != expectedOutput {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("cgtcalc_actual_\(filename)")
        try actualOutput.write(to: tempFile, atomically: true, encoding: .utf8)

        let diffProcess = Process()
        diffProcess.executableURL = URL(fileURLWithPath: "/usr/bin/diff")
        diffProcess.arguments = ["-u", outputFile.path, tempFile.path]

        let diffPipe = Pipe()
        diffProcess.standardOutput = diffPipe
        diffProcess.standardError = diffPipe

        try diffProcess.run()
        diffProcess.waitUntilExit()

        let diffData = diffPipe.fileHandleForReading.readDataToEndOfFile()
        let diffOutput = String(data: diffData, encoding: .utf8) ?? ""

        print("=== \(failureLabel): \(filename) ===")
        print("=== Unified Diff: ===")
        print(diffOutput)

        XCTAssertEqual(actualOutput, expectedOutput, "Output mismatch for \(filename)")
      }
    }
  }

  private func runStandard(content: String) throws -> String {
    let data = try InputParser.parse(content: content)
    let result = try CGTEngine.calculate(inputData: data)
    return TextReportFormatter().format(result)
  }

  /// Mirrors CLI parse/calculate/format behavior for invalid fixture expectations.
  private func runLikeCLI(content: String) -> String {
    let inputData: [InputData]
    do {
      inputData = try InputParser.parse(content: content)
    } catch {
      return "Error parsing input: \(error)\n"
    }

    let result: CalculationResult
    do {
      result = try CGTEngine.calculate(inputData: inputData)
    } catch {
      return "Error calculating CGT: \(error)\n"
    }

    return TextReportFormatter().format(result)
  }

  /// Resolves fixture directories for standard, invalid, and private suites.
  private func fixtureDirectories(suiteName: String, privateSuite: Bool) throws -> (inputs: URL, outputs: URL) {
    let testFileURL = URL(fileURLWithPath: #filePath)
    let testDir = testFileURL.deletingLastPathComponent()
    let sourceSuiteDir = testDir.appendingPathComponent("TestData/\(suiteName)", isDirectory: true)

    if privateSuite {
      // Private fixtures are local-only and may be untracked, so always resolve from source paths
      // instead of bundle resources.
      let inputs = sourceSuiteDir.appendingPathComponent("Inputs", isDirectory: true)
      let outputs = sourceSuiteDir.appendingPathComponent("Outputs", isDirectory: true)
      var isDir: ObjCBool = false
      guard FileManager.default.fileExists(atPath: inputs.path, isDirectory: &isDir), isDir.boolValue else {
        throw XCTSkip("Skipping \(suiteName): no Inputs directory at \(inputs.path)")
      }

      if self.recordMode {
        try FileManager.default.createDirectory(at: outputs, withIntermediateDirectories: true)
        return (inputs: inputs, outputs: outputs)
      }

      guard FileManager.default.fileExists(atPath: outputs.path, isDirectory: &isDir), isDir.boolValue else {
        throw XCTSkip("Skipping \(suiteName): no Outputs directory at \(outputs.path)")
      }
      return (inputs: inputs, outputs: outputs)
    }

    if self.recordMode {
      return (
        inputs: sourceSuiteDir.appendingPathComponent("Inputs", isDirectory: true),
        outputs: sourceSuiteDir.appendingPathComponent("Outputs", isDirectory: true))
    }

    let bundleSuiteDir = try XCTUnwrap(
      Bundle.module.resourceURL?.appendingPathComponent("TestData/\(suiteName)", isDirectory: true))
    return (
      inputs: bundleSuiteDir.appendingPathComponent("Inputs", isDirectory: true),
      outputs: bundleSuiteDir.appendingPathComponent("Outputs", isDirectory: true))
  }
}
