import Foundation

public enum FormattedReport {
  case text(String)
  case binary(Data)
}

public protocol ReportFormatter {
  func render(_ result: CalculationResult) throws -> FormattedReport
}

extension TextReportFormatter: ReportFormatter {
  public func render(_ result: CalculationResult) throws -> FormattedReport {
    .text(self.format(result))
  }
}
