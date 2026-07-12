import Foundation

struct ReportDocument {
  let result: CalculationResult
  let taxYears: [TaxYearReportSection]

  init(result: CalculationResult) {
    self.result = result
    self.taxYears = result.taxYearSummaries
      .sorted(by: { $0.taxYear < $1.taxYear })
      .map(TaxYearReportSection.init)
  }
}

struct TaxYearReportSection {
  let summary: TaxYearSummary
  let gainsCount: Int
  let lossesCount: Int
  let totalGains: Decimal
  let totalLosses: Decimal
  let disposals: [DisposalReportEntry]

  init(summary: TaxYearSummary) {
    self.summary = summary
    self.gainsCount = summary.disposals.filter { $0.gain >= 0 }.count
    self.lossesCount = summary.disposals.filter { $0.gain < 0 }.count
    self.totalGains = summary.disposals.filter { $0.gain > 0 }.reduce(0) { $0 + $1.gain }
    self.totalLosses = summary.disposals.filter { $0.gain < 0 }.reduce(0) { $0 + abs($1.gain) }
    self.disposals = summary.disposals.map(DisposalReportEntry.init)
  }
}

struct DisposalReportEntry {
  enum MatchKind: Equatable {
    case sameDay
    case bedAndBreakfast
  }

  struct AcquisitionMatch {
    let kind: MatchKind
    let quantity: Decimal
    let date: Date
    let purchasePrice: Decimal
    let purchaseExpenses: Decimal
    let restructureMultiplier: Decimal
    let eventAdjustment: Decimal
    let cost: Decimal
  }

  struct Section104Component {
    let poolQuantity: Decimal
    let poolCost: Decimal
    let averageCost: Decimal
    let matchedQuantity: Decimal
    let matchedCost: Decimal
  }

  let disposal: Disposal
  let acquisitionMatches: [AcquisitionMatch]
  let section104: Section104Component?

  init(disposal: Disposal) {
    self.disposal = disposal
    self.acquisitionMatches = disposal.bedAndBreakfastMatches.map { match in
      let purchaseExpenses = match.buyTransaction.expenses * match.buyDateQuantity / match.buyTransaction.quantity
      return AcquisitionMatch(
        kind: UTC.calendar.isDate(match.buyTransaction.date, inSameDayAs: disposal.sellTransaction.date)
          ? .sameDay
          : .bedAndBreakfast,
        quantity: match.buyDateQuantity,
        date: match.buyTransaction.date,
        purchasePrice: match.buyTransaction.price,
        purchaseExpenses: purchaseExpenses,
        restructureMultiplier: match.restructureMultiplier,
        eventAdjustment: match.eventAdjustment,
        cost: match.cost)
    }

    if let firstMatch = disposal.section104Matches.first {
      let averageCost = firstMatch.poolQuantity > 0 ? firstMatch.poolCost / firstMatch.poolQuantity : 0
      self.section104 = Section104Component(
        poolQuantity: firstMatch.poolQuantity,
        poolCost: firstMatch.poolCost,
        averageCost: averageCost,
        matchedQuantity: disposal.section104Matches.reduce(0) { $0 + $1.quantity },
        matchedCost: disposal.section104Matches.reduce(0) { $0 + $1.cost })
    } else {
      self.section104 = nil
    }
  }
}
