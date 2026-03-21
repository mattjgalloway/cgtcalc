import Foundation

// MARK: - Tax Year

public struct TaxYear: Comparable, Hashable {
  public let startYear: Int // Year starting (e.g., 2019 for 2019/2020)

  /// Creates a UK tax year from its starting calendar year.
  /// - Parameter startYear: The year containing 6 April.
  public init(startYear: Int) {
    self.startYear = startYear
  }

  public var label: String {
    "\(self.startYear)/\(self.startYear + 1)"
  }

  public var startDate: Date {
    var components = DateComponents()
    components.year = self.startYear
    components.month = 4
    components.day = 6
    return UTC.calendar.date(from: components)!
  }

  public var endDate: Date {
    var components = DateComponents()
    components.year = self.startYear + 1
    components.month = 4
    components.day = 5
    return UTC.calendar.date(from: components)!
  }

  /// Checks whether a date falls within this tax year.
  /// - Parameter date: The date to test.
  /// - Returns: `true` when the date is between 6 April and the following 5 April.
  public func contains(_ date: Date) -> Bool {
    date >= self.startDate && date <= self.endDate
  }

  /// Derives the UK tax year containing a given date.
  /// - Parameter date: The date to convert.
  /// - Returns: The tax year that contains the date.
  public static func from(date: Date) -> TaxYear {
    let components = UTC.calendar.dateComponents([.month, .day], from: date)
    let year = UTC.calendar.component(.year, from: date)

    // If before April 6, use previous tax year
    if let month = components.month, let day = components.day {
      if month < 4 || (month == 4 && day < 6) {
        return TaxYear(startYear: year - 1)
      }
    }
    return TaxYear(startYear: year)
  }

  /// Compares tax years by their starting year.
  /// - Parameters:
  ///   - lhs: Left-hand tax year.
  ///   - rhs: Right-hand tax year.
  /// - Returns: `true` when `lhs` starts earlier than `rhs`.
  public static func < (lhs: TaxYear, rhs: TaxYear) -> Bool {
    lhs.startYear < rhs.startYear
  }

  public var specialCapitalGainsRateChangeLastOldRateDate: Date? {
    guard self.startYear == 2024 else { return nil }

    var components = DateComponents()
    components.year = 2024
    components.month = 10
    components.day = 29
    return UTC.calendar.date(from: components)
  }

  public var specialCapitalGainsRateChangeLabel: String? {
    guard self.specialCapitalGainsRateChangeLastOldRateDate != nil else { return nil }
    return "29th October"
  }
}

// MARK: - Tax Rates

public struct TaxRates: Sendable {
  public let exemption: Decimal

  /// Creates a CGT rate bundle for one tax year.
  /// - Parameters:
  ///   - exemption: Annual exempt amount.
  public init(exemption: Decimal) {
    self.exemption = exemption
  }
}

// MARK: - Tax Rates Lookup

public enum TaxRateLookup {
  public enum LookupError: Error, LocalizedError {
    case missingTaxRates(startYear: Int)

    public var errorDescription: String? {
      switch self {
      case .missingTaxRates(let startYear):
        "Missing tax rates for year \(startYear). Please add rates to TaxRateLookup."
      }
    }
  }

  // UK CGT rates by tax year
  // Source: HMRC https://www.gov.uk/government/publications/rates-and-allowances-for-capital-gains-tax/rates-and-allowances-for-capital-gains-tax
  private static let rates: [Int: TaxRates] = [
    2026: TaxRates(exemption: 3000), // 2026/2027
    2025: TaxRates(exemption: 3000), // 2025/2026
    2024: TaxRates(exemption: 3000), // 2024/2025
    2023: TaxRates(exemption: 6000), // 2023/2024
    2022: TaxRates(exemption: 12300), // 2022/2023
    2021: TaxRates(exemption: 12300), // 2021/2022
    2020: TaxRates(exemption: 12300), // 2020/2021
    2019: TaxRates(exemption: 12000), // 2019/2020
    2018: TaxRates(exemption: 11700), // 2018/2019
    2017: TaxRates(exemption: 11300), // 2017/2018
    2016: TaxRates(exemption: 11100), // 2016/2017
    2015: TaxRates(exemption: 11100), // 2015/2016
    2014: TaxRates(exemption: 11000), // 2014/2015
    2013: TaxRates(exemption: 10900) // 2013/2014
  ]

  /// Returns the configured CGT rates for a tax year.
  /// - Parameter year: The tax year to look up.
  /// - Returns: The exemption and rate bundle for that year.
  public static func rates(for year: TaxYear) throws -> TaxRates {
    guard let rates = rates[year.startYear] else {
      throw LookupError.missingTaxRates(startYear: year.startYear)
    }
    return rates
  }
}
