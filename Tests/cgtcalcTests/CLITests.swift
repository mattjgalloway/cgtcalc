import Foundation
import XCTest

final class CLITests: XCTestCase {
  func testHelpOutputContainsUsage() throws {
    let result = try self.runCLI(arguments: ["-h"])
    XCTAssertEqual(result.status, 0)
    XCTAssertTrue(result.stdout.contains("USAGE: cgtcalc"))
  }

  func testCLIReadsFromStdin() throws {
    let input = """
    BUY 01/01/2020 TEST 10 1 0
    SELL 02/01/2020 TEST 10 2 0
    """

    let result = try self.runCLI(arguments: ["-"], stdin: input)
    XCTAssertEqual(result.status, 0)
    XCTAssertTrue(result.stdout.contains("# SUMMARY"))
    XCTAssertTrue(result.stdout.contains("# TRANSACTIONS"))
  }

  func testCLIReportsParseErrors() throws {
    let input = """
    BUY invalid_date TEST 10 1 0
    """
    let inputURL = try self.writeTempInputFile(contents: input)
    defer { try? FileManager.default.removeItem(at: inputURL) }

    let result = try self.runCLI(arguments: [inputURL.path])
    XCTAssertNotEqual(result.status, 0)
    XCTAssertTrue(result.stderr.contains("Error parsing input:"))
  }

  func testCLIReportsCalculationErrors() throws {
    let input = """
    SELL 01/06/2019 TEST 50 15 0
    """
    let inputURL = try self.writeTempInputFile(contents: input)
    defer { try? FileManager.default.removeItem(at: inputURL) }

    let result = try self.runCLI(arguments: [inputURL.path])
    XCTAssertNotEqual(result.status, 0)
    XCTAssertTrue(result.stderr.contains("Error calculating CGT:"))
    XCTAssertTrue(result.stderr.contains("Insufficient shares"))
  }

  func testCLIReportsTextOutputWriteErrors() throws {
    let input = """
    BUY 01/01/2020 TEST 10 1 0
    SELL 02/01/2020 TEST 10 2 0
    """
    let inputURL = try self.writeTempInputFile(contents: input)
    defer { try? FileManager.default.removeItem(at: inputURL) }

    let directoryOutputPath = FileManager.default.temporaryDirectory.path
    let result = try self.runCLI(arguments: [inputURL.path, "--output-file", directoryOutputPath])
    XCTAssertNotEqual(result.status, 0)
    XCTAssertTrue(result.stderr.contains("Error writing output file:"))
  }

  #if os(macOS)
    func testPDFFormatRequiresOutputFile() throws {
      let input = """
      BUY 01/01/2020 TEST 10 1 0
      SELL 02/01/2020 TEST 10 2 0
      """
      let inputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("cgtcalc_cli_pdf_test_\(UUID().uuidString).txt")
      try input.write(to: inputURL, atomically: true, encoding: .utf8)
      defer { try? FileManager.default.removeItem(at: inputURL) }

      let result = try self.runCLI(arguments: [inputURL.path, "--format", "pdf"])
      XCTAssertNotEqual(result.status, 0)
      XCTAssertTrue(result.stderr.contains("requires `--output-file <path>`"))
    }

    func testCLIReportsBinaryOutputWriteErrors() throws {
      let input = """
      BUY 01/01/2020 TEST 10 1 0
      SELL 02/01/2020 TEST 10 2 0
      """
      let inputURL = try self.writeTempInputFile(contents: input)
      defer { try? FileManager.default.removeItem(at: inputURL) }

      let directoryOutputPath = FileManager.default.temporaryDirectory.path
      let result = try self.runCLI(arguments: [
        inputURL.path,
        "--format",
        "pdf",
        "--output-file",
        directoryOutputPath
      ])
      XCTAssertNotEqual(result.status, 0)
      XCTAssertTrue(result.stderr.contains("Error writing output file:"))
    }
  #endif

  private struct CLIResult {
    let status: Int32
    let stdout: String
    let stderr: String
  }

  private func runCLI(arguments: [String], stdin: String? = nil) throws -> CLIResult {
    let process = Process()
    process.executableURL = try self.cliBinaryURL()
    process.arguments = arguments

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    if let stdin {
      let stdinPipe = Pipe()
      process.standardInput = stdinPipe
      try process.run()
      if let data = stdin.data(using: .utf8) {
        stdinPipe.fileHandleForWriting.write(data)
      }
      stdinPipe.fileHandleForWriting.closeFile()
    } else {
      try process.run()
    }

    process.waitUntilExit()
    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    return CLIResult(
      status: process.terminationStatus,
      stdout: String(data: stdoutData, encoding: .utf8) ?? "",
      stderr: String(data: stderrData, encoding: .utf8) ?? "")
  }

  private func cliBinaryURL() throws -> URL {
    let fileManager = FileManager.default
    var current = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()

    for _ in 0 ..< 12 {
      let candidate = current.appendingPathComponent("cgtcalc")
      if fileManager.isExecutableFile(atPath: candidate.path) {
        return candidate
      }
      current = current.deletingLastPathComponent()
    }

    let repoRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent() // cgtcalcTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // repo root

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["swift", "build", "--show-bin-path"]
    process.currentDirectoryURL = repoRoot
    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      throw XCTSkip("Unable to locate cgtcalc executable.")
    }

    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let binPath = output.trimmingCharacters(in: .whitespacesAndNewlines)
    let candidate = URL(fileURLWithPath: binPath).appendingPathComponent("cgtcalc")
    guard fileManager.isExecutableFile(atPath: candidate.path) else {
      throw XCTSkip("Unable to locate cgtcalc executable.")
    }

    return candidate
  }

  private func writeTempInputFile(contents: String) throws -> URL {
    let inputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("cgtcalc_cli_test_\(UUID().uuidString).txt")
    try contents.write(to: inputURL, atomically: true, encoding: .utf8)
    return inputURL
  }
}
