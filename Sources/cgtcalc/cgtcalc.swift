import ArgumentParser
import CGTCalcCore
import Foundation

@main
struct CGTCalcCommand: ParsableCommand {
  static let VERSION = "0.2.0"

  static let configuration = CommandConfiguration(
    commandName: "cgtcalc",
    abstract: "UK Capital Gains Tax Calculator",
    version: VERSION)

  @Argument(help: "The input data filename (use '-' for stdin)")
  var filename: String

  @Option(name: .shortAndLong, help: "Output file")
  var outputFile: String?

  /// Parses input, runs the calculator, and writes the formatted report to stdout or a file.
  mutating func run() throws {
    // Parse input from file or stdin
    let inputData: [InputData]
    do {
      if self.filename == "-" {
        // Read from stdin
        let content = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
        inputData = try InputParser.parse(content: content)
      } else {
        let fileURL = URL(fileURLWithPath: filename)
        inputData = try InputParser.parse(fileURL: fileURL)
      }
    } catch let error as ParserError {
      fputs("Error parsing input: \(error)\n", stderr)
      throw ExitCode(1)
    } catch {
      fputs("Error parsing input: \(error)\n", stderr)
      throw ExitCode(1)
    }

    // Calculate
    let result: CalculationResult
    do {
      result = try CGTEngine.calculate(inputData: inputData)
    } catch {
      fputs("Error calculating CGT: \(error)\n", stderr)
      throw ExitCode(1)
    }

    // Format output
    let formatter = OutputFormatter()
    let output = formatter.format(result)

    // Write output
    if let outputFile {
      do {
        try output.write(toFile: outputFile, atomically: true, encoding: String.Encoding.utf8)
      } catch {
        fputs("Error writing output file: \(error)\n", stderr)
        throw ExitCode(1)
      }
    } else {
      print(output)
    }
  }
}
