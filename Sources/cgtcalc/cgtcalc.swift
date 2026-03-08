import ArgumentParser
import CGTCalcCore
import Foundation

private func writeStderr(_ message: String) {
  let line = message.hasSuffix("\n") ? message : message + "\n"
  guard let data = line.data(using: .utf8) else { return }
  FileHandle.standardError.write(data)
}

@main
struct CGTCalcCommand: ParsableCommand {
  enum OutputFormat: String, ExpressibleByArgument {
    case text
    #if os(macOS)
    case pdf
    #endif
  }

  static let VERSION = "0.2.0"

  static let configuration = CommandConfiguration(
    commandName: "cgtcalc",
    abstract: "UK Capital Gains Tax Calculator",
    version: VERSION)

  @Argument(help: "The input data filename (use '-' for stdin)")
  var filename: String

  @Option(name: .shortAndLong, help: "Output file")
  var outputFile: String?

  @Option(name: .shortAndLong, help: "Output format")
  var format: OutputFormat = .text

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
      writeStderr("Error parsing input: \(error)")
      throw ExitCode(1)
    } catch {
      writeStderr("Error parsing input: \(error)")
      throw ExitCode(1)
    }

    // Calculate
    let result: CalculationResult
    do {
      result = try CGTEngine.calculate(inputData: inputData)
    } catch {
      writeStderr("Error calculating CGT: \(error)")
      throw ExitCode(1)
    }

    let formatter: any ReportFormatter
    switch self.format {
    case .text:
      formatter = TextReportFormatter()
    #if os(macOS)
    case .pdf:
      formatter = PDFReportFormatter()
    #endif
    }

    let rendered: FormattedReport
    do {
      rendered = try formatter.render(result)
    } catch {
      writeStderr("Error formatting output: \(error)")
      throw ExitCode(1)
    }

    switch rendered {
    case let .text(output):
      if let outputFile {
        do {
          try output.write(toFile: outputFile, atomically: true, encoding: .utf8)
        } catch {
          writeStderr("Error writing output file: \(error)")
          throw ExitCode(1)
        }
      } else {
        print(output)
      }
    case let .binary(data):
      guard let outputFile else {
        throw ValidationError("`--format \(self.format.rawValue)` requires `--output-file <path>`.")
      }
      do {
        try data.write(to: URL(fileURLWithPath: outputFile), options: .atomic)
      } catch {
        writeStderr("Error writing output file: \(error)")
        throw ExitCode(1)
      }
    }
  }
}
