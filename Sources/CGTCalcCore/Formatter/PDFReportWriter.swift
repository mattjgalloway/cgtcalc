#if os(macOS)
  import CoreGraphics
  import CoreText
  import Foundation

  enum PDFReportFormatterError: Error, CustomStringConvertible {
    case failedToCreatePDFData

    var description: String {
      switch self {
      case .failedToCreatePDFData:
        "Unable to create PDF data."
      }
    }
  }

  public struct PDFReportFormatter: ReportFormatter {
    struct TaxReturnEntry {
      let rows: [(label: String, value: String)]
      let specialLine: String?
    }

    private let pageWidth: CGFloat = 595
    private let pageHeight: CGFloat = 842
    private let margin: CGFloat = 36
    private let contentWidth: CGFloat = 523
    private let rowHeight: CGFloat = 20
    private let sectionSpacing: CGFloat = 18

    private let colorPrimary = CGColor(red: 0.08, green: 0.23, blue: 0.43, alpha: 1)
    private let colorHeaderFill = CGColor(red: 0.93, green: 0.96, blue: 1.0, alpha: 1)
    private let colorAltRowFill = CGColor(red: 0.98, green: 0.99, blue: 1.0, alpha: 1)
    private let colorBorder = CGColor(gray: 0.82, alpha: 1)
    private let colorText = CGColor(gray: 0.1, alpha: 1)
    private let colorMuted = CGColor(gray: 0.45, alpha: 1)

    private let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 20, nil)
    private let sectionFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 12, nil)
    private let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
    private let bodyBoldFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 10, nil)
    private let smallFont = CTFontCreateWithName("Helvetica" as CFString, 9, nil)
    private let monoFont = CTFontCreateWithName("Menlo-Regular" as CFString, 9.5, nil)
    private let utcCalendar: Calendar = {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
      return calendar
    }()

    public init() {}

    public func render(_ result: CalculationResult) throws -> FormattedReport {
      guard let data = CFDataCreateMutable(nil, 0),
            let consumer = CGDataConsumer(data: data)
      else {
        throw PDFReportFormatterError.failedToCreatePDFData
      }

      var mediaBox = CGRect(x: 0, y: 0, width: self.pageWidth, height: self.pageHeight)
      guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        throw PDFReportFormatterError.failedToCreatePDFData
      }

      var layout = PDFLayout(
        context: context,
        pageWidth: self.pageWidth,
        pageHeight: self.pageHeight,
        margin: self.margin)
      layout.beginPage()

      self.drawTitle(&layout)
      self.drawSummary(result.taxYearSummaries, layout: &layout)
      self.drawTaxYearDetails(result.taxYearSummaries, layout: &layout)
      self.drawTaxReturnInformation(result.taxYearSummaries, layout: &layout)
      self.drawHoldings(result.holdings, layout: &layout)
      self.drawTransactions(result.transactions, layout: &layout)
      self.drawAssetEvents(result.assetEvents, layout: &layout)

      layout.endDocument()
      return .binary(data as Data)
    }

    private func drawTitle(_ layout: inout PDFLayout) {
      layout.ensureSpace(70)
      let bandRect = CGRect(x: 0, y: 0, width: self.pageWidth, height: 56)
      layout.context.setFillColor(self.colorPrimary)
      layout.context.fill(bandRect)
      layout.drawText(
        "Capital Gains Tax Report",
        x: self.margin,
        y: 18,
        font: self.titleFont,
        color: CGColor(gray: 1, alpha: 1))
      let generatedLine = "Generated \(DateParser.format(Date()))"
      layout.drawText(generatedLine, x: self.margin, y: 42, font: self.smallFont, color: CGColor(gray: 1, alpha: 0.85))
      layout.y = 72
    }

    private func drawSummary(_ summaries: [TaxYearSummary], layout: inout PDFLayout) {
      self.drawSectionHeader("Summary", layout: &layout)

      let header = ["Tax year", "Gain", "Proceeds", "Exemption", "Loss carry", "Taxable gain"]
      let widths: [CGFloat] = [0.16, 0.14, 0.16, 0.16, 0.16, 0.22]
      var rows: [[String]] = []
      for summary in summaries {
        rows.append([
          summary.taxYear.label,
          self.currency(summary.netGain),
          self.currency(self.roundedGain(summary.disposals.reduce(0) { $0 + $1.sellTransaction.proceeds })),
          self.currency(summary.exemption),
          self.currency(summary.lossCarryForward),
          self.currency(summary.taxableGain)
        ])
      }
      if rows.isEmpty {
        rows = [["-", "-", "-", "-", "-", "-"]]
      }
      self.drawTable(header: header, rows: rows, widthRatios: widths, layout: &layout)
    }

    private func drawTaxYearDetails(_ summaries: [TaxYearSummary], layout: inout PDFLayout) {
      self.drawSectionHeader("Tax Year Details", layout: &layout)
      let ordered = summaries.sorted { $0.taxYear < $1.taxYear }
      if ordered.isEmpty {
        layout.drawText("No disposals.", x: self.margin, y: layout.y, font: self.bodyFont, color: self.colorMuted)
        layout.y += self.sectionSpacing
        return
      }

      for summary in ordered {
        layout.ensureSpace(56)
        layout.drawText(
          "Tax Year \(summary.taxYear.label)",
          x: self.margin,
          y: layout.y,
          font: self.bodyBoldFont,
          color: self.colorPrimary)
        layout.y += 15

        let gainsCount = summary.disposals.filter { $0.gain >= 0 }.count
        let lossesCount = summary.disposals.filter { $0.gain < 0 }.count
        let totalGains = summary.disposals.filter { $0.gain > 0 }.reduce(Decimal(0)) { $0 + $1.gain }
        let totalLosses = summary.disposals.filter { $0.gain < 0 }.reduce(Decimal(0)) { $0 + abs($1.gain) }
        let summaryHeight = layout.drawWrappedText(
          "\(gainsCount) gains with total \(self.currency(totalGains)); \(lossesCount) losses with total \(self.currency(totalLosses)).",
          x: self.margin,
          y: layout.y,
          width: self.contentWidth,
          lineHeight: 12,
          font: self.bodyFont,
          color: self.colorText)
        layout.y += summaryHeight + 6

        for (index, disposal) in summary.disposals.enumerated() {
          let prefix = disposal.gain >= 0 ? "GAIN" : "LOSS"
          let title = "\(index + 1). SOLD \(disposal.sellTransaction.quantity) \(disposal.sellTransaction.asset) on \(DateParser.format(disposal.sellTransaction.date)) - \(prefix) \(self.currency(abs(disposal.gain)))"
          var detailLines: [String] = []
          for match in disposal.bedAndBreakfastMatches {
            let label = self.utcCalendar
              .isDate(match.buyTransaction.date, inSameDayAs: disposal.sellTransaction.date) ? "Same day" : "Bed & breakfast"
            let restructureSuffix = match.restructureMultiplier != 1 ?
              " with restructure multiplier \(self.decimalString(self.rounded(match.restructureMultiplier, scale: 5)))" :
              ""
            let offsetSuffix = match.eventAdjustment != 0 ?
              " with offset of \(self.currency(abs(match.eventAdjustment)))" : ""
            detailLines.append(
              "\(label): \(match.buyDateQuantity) at \(self.currency(match.buyTransaction.price)) on \(DateParser.format(match.buyTransaction.date))\(restructureSuffix)\(offsetSuffix)")
          }

          if !disposal.section104Matches.isEmpty {
            let poolQty = disposal.section104Matches[0].poolQuantity
            let poolCost = disposal.section104Matches[0].poolCost
            let avgCost = poolQty > 0 ? poolCost / poolQty : 0
            detailLines.append(
              "Section 104: \(poolQty) units at average cost \(self.currency(self.rounded(avgCost, scale: 5)))")
          }

          let calculationLine = self.detailedCalculationLine(for: disposal)
          let measuredCardHeight = self.measureDisposalCardHeight(
            title: title,
            detailLines: detailLines,
            calculationLine: calculationLine,
            layout: layout)
          let maxCardHeight = layout.pageHeight - (layout.margin * 2)

          if measuredCardHeight > maxCardHeight {
            layout.ensureSpace(30)
            self.drawUnboxedDisposal(
              title: title,
              detailLines: detailLines,
              calculationLine: calculationLine,
              layout: &layout)
            layout.y += 8
            continue
          }

          layout.ensureSpace(measuredCardHeight + 2)
          let cardStart = layout.y
          layout.drawWrappedText(
            title,
            x: self.margin + 8,
            y: layout.y + 8,
            width: self.contentWidth - 16,
            lineHeight: 12,
            font: self.bodyBoldFont,
            color: self.colorText)
          layout.y += layout.measureWrappedTextHeight(title, width: self.contentWidth - 16, lineHeight: 12) + 12

          for line in detailLines {
            let h = layout.drawWrappedText(
              line,
              x: self.margin + 16,
              y: layout.y,
              width: self.contentWidth - 24,
              lineHeight: 11,
              font: self.bodyFont,
              color: self.colorText)
            layout.y += h + 2
          }

          let calculationHeight = layout.drawWrappedText(
            calculationLine,
            x: self.margin + 16,
            y: layout.y,
            width: self.contentWidth - 24,
            lineHeight: 11,
            font: self.bodyFont,
            color: self.colorMuted)
          layout.y += calculationHeight + 8

          let cardHeight = layout.y - cardStart
          layout.context.setStrokeColor(self.colorBorder)
          layout.context.stroke(CGRect(x: self.margin, y: cardStart, width: self.contentWidth, height: cardHeight))
          layout.y += 8
        }

        layout.y += 4
      }
    }

    private func drawTaxReturnInformation(_ summaries: [TaxYearSummary], layout: inout PDFLayout) {
      self.drawSectionHeader("Tax Return Information", layout: &layout)
      let ordered = summaries.sorted { $0.taxYear < $1.taxYear }
      if ordered.isEmpty {
        layout.drawText("None.", x: self.margin, y: layout.y, font: self.bodyFont, color: self.colorMuted)
        layout.y += self.sectionSpacing
        return
      }

      let introHeight = layout.drawWrappedText(
        "Values below are laid out for HMRC Self Assessment entry.",
        x: self.margin,
        y: layout.y,
        width: self.contentWidth,
        lineHeight: 11,
        font: self.smallFont,
        color: self.colorMuted)
      layout.y += introHeight + 8

      for summary in ordered {
        let disposalsCount = summary.disposals.count
        let entry = self.taxReturnEntry(for: summary, disposalsCount: disposalsCount)
        let rows = entry.rows
        let specialLine = entry.specialLine

        let rowHeight: CGFloat = 18
        let headerHeight: CGFloat = 20
        let specialHeight: CGFloat = specialLine.map { layout.measureWrappedTextHeight(
          $0,
          width: self.contentWidth - 20,
          lineHeight: 11) + 8 } ?? 0
        let cardHeight = headerHeight + (CGFloat(rows.count) * rowHeight) + specialHeight + 8
        layout.ensureSpace(cardHeight + 8)

        let cardX = self.margin
        let cardY = layout.y
        let cardRect = CGRect(x: cardX, y: cardY, width: self.contentWidth, height: cardHeight)
        layout.context.setFillColor(CGColor(gray: 1, alpha: 1))
        layout.context.fill(cardRect)
        layout.context.setStrokeColor(self.colorBorder)
        layout.context.stroke(cardRect)

        let headRect = CGRect(x: cardX, y: cardY, width: self.contentWidth, height: headerHeight)
        layout.context.setFillColor(self.colorHeaderFill)
        layout.context.fill(headRect)
        layout.context.setStrokeColor(self.colorBorder)
        layout.context.stroke(headRect)
        layout.drawText(
          "Tax Year \(summary.taxYear.label)",
          x: cardX + 8,
          y: cardY + 4,
          font: self.bodyBoldFont,
          color: self.colorPrimary)

        var rowY = cardY + headerHeight
        for (index, row) in rows.enumerated() {
          let rowRect = CGRect(x: cardX, y: rowY, width: self.contentWidth, height: rowHeight)
          if index.isMultiple(of: 2) {
            layout.context.setFillColor(self.colorAltRowFill)
            layout.context.fill(rowRect)
          }
          layout.context.setStrokeColor(self.colorBorder)
          layout.context.stroke(rowRect)

          layout.drawText(row.label, x: cardX + 8, y: rowY + 3, font: self.bodyFont, color: self.colorText)
          layout.drawRightAlignedText(
            row.value,
            maxX: cardX + self.contentWidth - 8,
            y: rowY + 3,
            font: self.bodyBoldFont,
            color: self.colorText)
          rowY += rowHeight
        }

        if let specialLine {
          let noteHeight = layout.drawWrappedText(
            specialLine,
            x: cardX + 10,
            y: rowY + 4,
            width: self.contentWidth - 20,
            lineHeight: 11,
            font: self.smallFont,
            color: self.colorMuted)
          rowY += noteHeight + 8
        }

        layout.y = max(layout.y + cardHeight, rowY) + 8
      }
      layout.y += 4
    }

    private func drawHoldings(_ holdings: [String: Section104Holding], layout: inout PDFLayout) {
      self.drawSectionHeader("Holdings", layout: &layout)
      let active = holdings.filter { $0.value.quantity > 0 }.sorted { $0.key < $1.key }
      if active.isEmpty {
        layout.drawText("None.", x: self.margin, y: layout.y, font: self.bodyFont, color: self.colorMuted)
        layout.y += self.sectionSpacing
        return
      }

      let header = ["Asset", "Quantity", "Average cost basis"]
      let widths: [CGFloat] = [0.46, 0.24, 0.30]
      let rows = active.map { asset, holding in
        let avg = holding.quantity > 0 ? holding.costBasis / holding.quantity : 0
        return [asset, self.decimalString(holding.quantity), self.currency(self.rounded(avg, scale: 5))]
      }
      self.drawTable(header: header, rows: rows, widthRatios: widths, layout: &layout)
    }

    private func drawTransactions(_ transactions: [Transaction], layout: inout PDFLayout) {
      self.drawSectionHeader("Transactions", layout: &layout)
      if transactions.isEmpty {
        layout.drawText("NONE", x: self.margin, y: layout.y, font: self.monoFont, color: self.colorMuted)
        layout.y += self.sectionSpacing
        return
      }

      let lines = transactions.map { tx in
        let type = tx.type == .buy ? "BOUGHT" : "SOLD"
        return "\(DateParser.format(tx.date)) \(type) \(self.decimalString(tx.quantity)) of \(tx.asset) at \(self.currency(tx.price)) with \(self.currency(tx.expenses)) expenses"
      }
      self.drawMonospaceLines(lines, sectionTitle: "Transactions", layout: &layout)
    }

    private func drawAssetEvents(_ events: [AssetEvent], layout: inout PDFLayout) {
      self.drawSectionHeader("Asset Events", layout: &layout)
      if events.isEmpty {
        layout.drawText("NONE", x: self.margin, y: layout.y, font: self.monoFont, color: self.colorMuted)
        layout.y += self.sectionSpacing
        return
      }

      let lines = events.map { event in
        let date = DateParser.format(event.date)
        switch event.type {
        case .split:
          return "\(date) \(event.asset) SPLIT by \(self.decimalString(event.amount))"
        case .unsplit:
          return "\(date) \(event.asset) UNSPLIT by \(self.decimalString(event.amount))"
        case .capitalReturn:
          return "\(date) \(event.asset) CAPITAL RETURN on \(self.decimalString(event.amount)) for \(self.currency(event.value))"
        case .dividend:
          return "\(date) \(event.asset) DIVIDEND on \(self.decimalString(event.amount)) for \(self.currency(event.value))"
        }
      }
      self.drawMonospaceLines(lines, sectionTitle: "Asset Events", layout: &layout)
    }

    private func drawSectionHeader(_ title: String, layout: inout PDFLayout) {
      layout.ensureSpace(26)
      layout.context.setFillColor(self.colorHeaderFill)
      layout.context.fill(CGRect(x: self.margin, y: layout.y, width: self.contentWidth, height: 20))
      layout.drawText(title, x: self.margin + 8, y: layout.y + 5, font: self.sectionFont, color: self.colorPrimary)
      layout.y += 24
    }

    private func drawTable(
      header: [String],
      rows: [[String]],
      widthRatios: [CGFloat],
      layout: inout PDFLayout)
    {
      precondition(header.count == widthRatios.count)
      let widths = widthRatios.map { self.contentWidth * $0 }
      let minimumSpace = self.rowHeight * CGFloat(rows.count + 1) + 6
      layout.ensureSpace(minimumSpace)
      self.drawTableHeader(header: header, widths: widths, layout: &layout)

      for (rowIndex, row) in rows.enumerated() {
        let pageBreak = layout.ensureSpace(self.rowHeight + 2)
        if pageBreak {
          self.drawTableHeader(header: header, widths: widths, layout: &layout)
        }
        var x = self.margin
        if rowIndex.isMultiple(of: 2) {
          layout.context.setFillColor(self.colorAltRowFill)
          layout.context.fill(CGRect(x: self.margin, y: layout.y, width: self.contentWidth, height: self.rowHeight))
        }
        for (columnIndex, value) in row.enumerated() {
          let rect = CGRect(x: x, y: layout.y, width: widths[columnIndex], height: self.rowHeight)
          layout.context.setStrokeColor(self.colorBorder)
          layout.context.stroke(rect)
          layout.drawTruncatedText(value, in: rect.insetBy(dx: 6, dy: 4), font: self.bodyFont, color: self.colorText)
          x += widths[columnIndex]
        }
        layout.y += self.rowHeight
      }

      layout.y += self.sectionSpacing - 4
    }

    private func drawTableHeader(header: [String], widths: [CGFloat], layout: inout PDFLayout) {
      var x = self.margin
      for (index, column) in header.enumerated() {
        let rect = CGRect(x: x, y: layout.y, width: widths[index], height: self.rowHeight)
        layout.context.setFillColor(self.colorHeaderFill)
        layout.context.fill(rect)
        layout.context.setStrokeColor(self.colorBorder)
        layout.context.stroke(rect)
        layout.drawTruncatedText(column, in: rect.insetBy(dx: 6, dy: 4), font: self.bodyBoldFont, color: self.colorText)
        x += widths[index]
      }
      layout.y += self.rowHeight
    }

    private func measureDisposalCardHeight(
      title: String,
      detailLines: [String],
      calculationLine: String,
      layout: PDFLayout) -> CGFloat
    {
      var total: CGFloat = 0
      total += 8
      total += layout.measureWrappedTextHeight(title, width: self.contentWidth - 16, lineHeight: 12)
      total += 12
      for line in detailLines {
        total += layout.measureWrappedTextHeight(line, width: self.contentWidth - 24, lineHeight: 11)
        total += 2
      }
      total += layout.measureWrappedTextHeight(calculationLine, width: self.contentWidth - 24, lineHeight: 11)
      total += 8
      return total
    }

    private func drawUnboxedDisposal(
      title: String,
      detailLines: [String],
      calculationLine: String,
      layout: inout PDFLayout)
    {
      layout.ensureSpace(16)
      layout.drawWrappedText(
        title,
        x: self.margin,
        y: layout.y,
        width: self.contentWidth,
        lineHeight: 12,
        font: self.bodyBoldFont,
        color: self.colorText)
      layout.y += layout.measureWrappedTextHeight(title, width: self.contentWidth, lineHeight: 12) + 4

      for line in detailLines {
        let h = layout.drawWrappedText(
          line,
          x: self.margin + 8,
          y: layout.y,
          width: self.contentWidth - 8,
          lineHeight: 11,
          font: self.bodyFont,
          color: self.colorText)
        layout.y += h + 2
        _ = layout.ensureSpace(14)
      }

      let calculationHeight = layout.drawWrappedText(
        calculationLine,
        x: self.margin + 8,
        y: layout.y,
        width: self.contentWidth - 8,
        lineHeight: 11,
        font: self.bodyFont,
        color: self.colorMuted)
      layout.y += calculationHeight + 4
      layout.context.setStrokeColor(self.colorBorder)
      layout.context.strokeLineSegments(
        between: [
          CGPoint(x: self.margin, y: layout.y),
          CGPoint(x: self.margin + self.contentWidth, y: layout.y)
        ])
    }

    func detailedCalculationLine(for disposal: Disposal) -> String {
      let saleExpenses = disposal.sellTransaction.expenses
      var costParts: [String] = []

      if !disposal.bedAndBreakfastMatches.isEmpty {
        for match in disposal.bedAndBreakfastMatches {
          let purchasePrice = self.rounded(match.buyTransaction.price, scale: 5)
          let purchaseExpenses = match.buyTransaction.expenses * match.buyDateQuantity / match.buyTransaction.quantity
          let roundedExpenses = self.rounded(purchaseExpenses, scale: 2)
          let eventAdjustmentPart = match
            .eventAdjustment != 0 ? " + \(self.decimalString(self.rounded(match.eventAdjustment, scale: 2)))" : ""
          let part = "(\(self.decimalString(match.buyDateQuantity)) * \(self.decimalString(purchasePrice)) + \(self.decimalString(roundedExpenses))\(eventAdjustmentPart))"
          costParts.append(part)
        }
      }

      if !disposal.section104Matches.isEmpty {
        let poolQty = disposal.section104Matches[0].poolQuantity
        let poolCost = disposal.section104Matches[0].poolCost
        let poolAvgCost = poolQty > 0 ? poolCost / poolQty : 0
        let section104MatchedQuantity = disposal.section104Matches.reduce(Decimal(0)) { $0 + $1.quantity }
        let part = "(\(self.decimalString(section104MatchedQuantity)) * \(self.decimalString(self.rounded(poolAvgCost, scale: 5))))"
        costParts.append(part)
      }

      let costExpression = "( " + costParts.joined(separator: " + ") + " )"
      return "Calculation: (\(self.decimalString(disposal.sellTransaction.quantity)) * \(self.decimalString(disposal.sellTransaction.price)) - \(self.decimalString(saleExpenses))) - \(costExpression) = \(self.decimalString(disposal.gain))"
    }

    func taxReturnEntry(for summary: TaxYearSummary, disposalsCount: Int? = nil) -> TaxReturnEntry {
      let count = disposalsCount ?? summary.disposals.count
      let proceeds = summary.disposals.reduce(Decimal(0)) { $0 + self.roundedGain($1.sellTransaction.proceeds) }
      let allowable = summary.disposals.reduce(Decimal(0)) {
        let roundedProceeds = self.roundedGain($1.sellTransaction.proceeds)
        return $0 + (roundedProceeds - $1.gain)
      }
      let gains = summary.disposals.filter { $0.gain > 0 }.reduce(Decimal(0)) { $0 + $1.gain }
      let losses = summary.disposals.filter { $0.gain < 0 }.reduce(Decimal(0)) { $0 + abs($1.gain) }

      let rows: [(label: String, value: String)] = [
        ("Disposals", String(count)),
        ("Proceeds", self.decimalString(proceeds)),
        ("Allowable costs", self.decimalString(allowable)),
        ("Total gains", self.decimalString(gains)),
        ("Total losses", self.decimalString(losses))
      ]

      var specialLine: String?
      if let cutoff = summary.taxYear.specialCapitalGainsRateChangeLastOldRateDate,
         let label = summary.taxYear.specialCapitalGainsRateChangeLabel
      {
        let gainsTo = summary.disposals.filter { $0.gain > 0 && $0.sellTransaction.date <= cutoff }
          .reduce(Decimal(0)) { $0 + $1.gain }
        let gainsAfter = summary.disposals.filter { $0.gain > 0 && $0.sellTransaction.date > cutoff }
          .reduce(Decimal(0)) { $0 + $1.gain }
        specialLine = "Rate-change split: gains to \(label) = \(self.decimalString(gainsTo)); gains after \(label) = \(self.decimalString(gainsAfter))."
      }

      return TaxReturnEntry(rows: rows, specialLine: specialLine)
    }

    private func drawMonospaceLines(_ lines: [String], sectionTitle: String, layout: inout PDFLayout) {
      let lineHeight: CGFloat = 11.5
      for line in lines {
        let lineHeightNeeded = layout
          .measureWrappedTextHeight(line, width: self.contentWidth, lineHeight: lineHeight) + 2
        let pageBreak = layout.ensureSpace(lineHeightNeeded)
        if pageBreak {
          self.drawSectionHeader("\(sectionTitle) (cont.)", layout: &layout)
        }
        let drawn = layout.drawWrappedText(
          line,
          x: self.margin,
          y: layout.y,
          width: self.contentWidth,
          lineHeight: lineHeight,
          font: self.monoFont,
          color: self.colorText)
        layout.y += drawn + 2
      }
      layout.y += self.sectionSpacing - 6
    }

    private func rounded(_ value: Decimal, scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
      var input = value
      var out = Decimal.zero
      NSDecimalRound(&out, &input, scale, mode)
      return out
    }

    private func roundedGain(_ value: Decimal) -> Decimal {
      self.rounded(value, scale: 0, mode: .down)
    }

    private func decimalString(_ value: Decimal) -> String {
      var copy = value
      return NSDecimalString(&copy, Locale(identifier: "en_GB"))
    }

    private func currency(_ value: Decimal) -> String {
      "£" + self.decimalString(self.rounded(value, scale: 2))
    }
  }

  private struct PDFLayout {
    let context: CGContext
    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let margin: CGFloat
    var y: CGFloat = 0

    mutating func beginPage() {
      self.context.beginPDFPage(nil)
      self.context.saveGState()
      self.context.translateBy(x: 0, y: self.pageHeight)
      self.context.scaleBy(x: 1, y: -1)
      self.context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
      self.context.setFillColor(CGColor(gray: 1, alpha: 1))
      self.context.fill(CGRect(x: 0, y: 0, width: self.pageWidth, height: self.pageHeight))
      self.y = self.margin
    }

    @discardableResult
    mutating func ensureSpace(_ requiredHeight: CGFloat) -> Bool {
      let availableBottom = self.pageHeight - self.margin
      if self.y + requiredHeight <= availableBottom {
        return false
      }
      self.context.restoreGState()
      self.context.endPDFPage()
      self.beginPage()
      return true
    }

    mutating func endDocument() {
      self.context.restoreGState()
      self.context.endPDFPage()
      self.context.closePDF()
    }

    func drawText(_ text: String, x: CGFloat, y: CGFloat, font: CTFont, color: CGColor) {
      let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
      ]
      let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
      self.context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
      let baselineY = y + CTFontGetAscent(font)
      self.context.textPosition = CGPoint(x: x, y: baselineY)
      CTLineDraw(line, self.context)
    }

    @discardableResult
    func drawWrappedText(
      _ text: String,
      x: CGFloat,
      y: CGFloat,
      width: CGFloat,
      lineHeight: CGFloat,
      font: CTFont,
      color: CGColor) -> CGFloat
    {
      let approxCharsPerLine = max(24, Int(width / 5.4))
      let lines = self.wrap(text: text, maxChars: approxCharsPerLine)
      var currentY = y
      for line in lines {
        self.drawText(line, x: x, y: currentY, font: font, color: color)
        currentY += lineHeight
      }
      return CGFloat(lines.count) * lineHeight
    }

    func drawTruncatedText(_ text: String, in rect: CGRect, font: CTFont, color: CGColor) {
      var out = text
      while out.count > 1 {
        let attrs: [NSAttributedString.Key: Any] = [
          NSAttributedString.Key(kCTFontAttributeName as String): font
        ]
        let ns = NSAttributedString(string: out, attributes: attrs)
        let line = CTLineCreateWithAttributedString(ns)
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        if lineWidth <= rect.width { break }
        out.removeLast()
      }
      if out.count < text.count, out.count > 1 {
        out.removeLast()
        out += "…"
      }
      self.drawText(out, x: rect.minX, y: rect.minY, font: font, color: color)
    }

    func drawRightAlignedText(_ text: String, maxX: CGFloat, y: CGFloat, font: CTFont, color: CGColor) {
      let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font
      ]
      let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
      let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
      let x = max(self.margin, maxX - width)
      self.drawText(text, x: x, y: y, font: font, color: color)
    }

    func measureWrappedTextHeight(_ text: String, width: CGFloat, lineHeight: CGFloat) -> CGFloat {
      let approxCharsPerLine = max(24, Int(width / 5.4))
      let lines = self.wrap(text: text, maxChars: approxCharsPerLine)
      return CGFloat(lines.count) * lineHeight
    }

    private func wrap(text: String, maxChars: Int) -> [String] {
      if text.count <= maxChars { return [text] }
      var lines: [String] = []
      var current = ""
      for word in text.split(separator: " ") {
        let candidate = current.isEmpty ? String(word) : current + " " + word
        if candidate.count <= maxChars {
          current = candidate
        } else {
          if !current.isEmpty { lines.append(current) }
          current = String(word)
        }
      }
      if !current.isEmpty { lines.append(current) }
      return lines
    }
  }
#endif
