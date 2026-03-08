import CGTCalcCore
import Foundation

enum FormattedReport {
  case text(String)
  case binary(Data)
}

protocol ReportFormatter {
  func render(_ result: CalculationResult) throws -> FormattedReport
}

extension TextReportFormatter: ReportFormatter {
  func render(_ result: CalculationResult) throws -> FormattedReport {
    .text(self.format(result))
  }
}
