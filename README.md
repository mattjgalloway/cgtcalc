# cgtcalc: UK capital gains tax calculator

![Build status](https://github.com/mattjgalloway/cgtcalc/actions/workflows/swift.yml/badge.svg)
[![codecov](https://codecov.io/gh/mattjgalloway/cgtcalc/branch/master/graph/badge.svg)](https://codecov.io/gh/mattjgalloway/cgtcalc)

> Note: This project was fully rewritten (AI natively) for the `0.2.0` release.

**DISCLAIMER: I am not a financial professional and cannot give tax advice. This calculator is intended for sample purposes only. Always do your own calculations for your self assessment. I accept no responsibility for any errors this calculator produces.**

`cgtcalc` is a command line application written in Swift which calculates UK capital gains tax based on a set of transactions. You feed it an input list of transactions and it outputs a summary of each tax year's gain (or loss) and the details for the disposal events that make up the gain (or loss).

## Why?

I developed this because I needed something that would take my transactions and calculate capitals gains tax. I wanted something which would check my manual working. I developed it in Swift because I wanted to see how building a console app in Swift was.

There are other excellent calculators out there, such as [CGTCalculator](http://www.cgtcalculator.com/), however I couldn't find one which did everything that I need. The missing piece seemed to be handling of fund equalisation payments and dividends that need to be accounted for in accumulation funds.

## What does it support?

Currently the calculator supports the following acquisition-to-disposal matching rules, in this order:

1. Same day trades.
2. Bed & breakfast trades where you purchase an asset within 30 days of selling the same asset.
3. Section 104 holding.

Important assumption:

- 30-day matching currently assumes the disposer is UK resident at the time of the later acquisition.

The calculator supports the post-6 April 2008 identification rules, and currently has annual exempt amount data for disposals in tax years `2013/2014` onwards.

It also supports handling of equalisation payments (capital return) for funds where those amounts should be subtracted from allowable cost, and accumulation distributions (dividend rows) where those amounts should increase allowable cost.

For interpretation choices and implementation policies that affect tax outcomes, see [TAX_DECISIONS.md](TAX_DECISIONS.md).

## What does it not support?

Currently there is no support for:

1. Transactions before 6th April 2008.
2. Disposal tax years before 2013/2014 (annual exempt amounts are not configured for earlier years).
3. The additional HMRC identification fallback where, if same-day + 30-day + Section 104 still do not fully identify a disposal, the remainder is matched with later acquisitions beyond the 30-day window.
4. Anything not represented by the supported input row types documented below.

### Unsupported Identification Cases

If an input requires share identification beyond:

1. same-day acquisitions
2. acquisitions in the following 30 days
3. Section 104 pooling

the calculator currently does not implement HMRC's further "later acquisitions" fallback stage. In those cases the engine raises an `unsupportedLaterAcquisitionIdentification` calculation error.

## Platforms

The library and console app both run on macOS and Linux.
Minimum macOS deployment target is macOS 15.
Text output works on both platforms. PDF output is currently available on macOS only.

## Usage

Using `cgtcalc` is simple. All you need to do is the following:

  1. Clone the repository.
  2. Put your transactions into a file, such as `data.txt`.
  3. Run `swift run cgtcalc data.txt`.

That's pretty much it. You'll then see output on your console showing the calculations and a summary for all tax years that have tax events in them.
By default the output format is text. You can select another formatter using `--format`.
For PDF output, use `--format pdf --output-file report.pdf` (available on macOS only).

Full usage can be found by running with `-h`:
```
USAGE: cgtcalc <filename> [--output-file <output-file>] [--format <format>]

ARGUMENTS:
  <filename>              The input data filename (use '-' for stdin)

OPTIONS:
  -o, --output-file <output-file>
                          Output file
  -f, --format <format>   Output format (text or pdf on macOS, text only on Linux)
  --version               Show the version.
  -h, --help              Show help information.
```

### Input data

Each row of the input file starts with the kind of data followed by details. For example a buy transaction, for 200 shares of LON:FOOBAR on 01/01/2020 at £1.50 with £20 expenses would be as follows:

```
BUY 01/01/2020 LON:FOOBAR 200 1.5 20
```

The full list of kinds of data are as follows:

| **Kind**    | **Category** | **Description** | **Fields** |
|-------------|--------------|-----------------|------------|
| `BUY`       | Transaction  | Buy transaction | `<DATE> <ASSET> <AMOUNT> <PRICE> <EXPENSES>` |
| `SELL`      | Transaction  | Sell transaction | `<DATE> <ASSET> <AMOUNT> <PRICE> <EXPENSES>` |
| `SPOUSEIN`  | Transaction  | No-gain/no-loss transfer in from spouse/civil partner (manual cost basis input) | `<DATE> <ASSET> <AMOUNT> <PRICE>` |
| `SPOUSEOUT` | Transaction  | No-gain/no-loss transfer out to spouse/civil partner (costed using normal share-identification ordering) | `<DATE> <ASSET> <AMOUNT>` |
| `CAPRETURN` | Asset event  | Capital return / equalisation event which reduces allowable cost | `<DATE> <ASSET> <AMOUNT> <VALUE>` |
| `DIVIDEND`  | Asset event  | Accumulation distribution which increases allowable cost | `<DATE> <ASSET> <AMOUNT> <VALUE>` |
| `SPLIT`     | Asset event  | Stock split     | `<DATE> <ASSET> <MULTIPLIER>` |
| `UNSPLIT`   | Asset event  | Stock un-split  | `<DATE> <ASSET> <MULTIPLIER>` |
| `RESTRUCT`  | Asset event  | Exact-ratio share restructure using old:new units | `<DATE> <ASSET> <OLD>:<NEW>` |

Rows must contain exactly the fields shown above; extra trailing fields are rejected.
Numeric tokens accept standard decimal numbers with optional `£` and valid thousands separators (for example `1234.56`, `1,234.56`, `£1,234.56`). Scientific notation is rejected.

Notes for spouse transfers:

- `SPOUSEOUT` does not take price or expenses. The calculator derives transferred allowable cost using normal share-identification ordering (same day, then following 30 days, then Section 104 fallback) and reports it in a dedicated `SPOUSE TRANSFERS OUT` section.
- `SPOUSEIN` should use the per-unit cost basis manually transcribed from the transfer-out calculation run for the other person.
- This tool calculates one person at a time; use separate input files/runs for each spouse/civil partner.

## Example

Given the following input in a file called `data.txt`:
```
BUY 05/12/2019 GB00B41YBW71 500 4.7012 2
SELL 28/11/2019 GB00B41YBW71 2000 4.6702 12.5
BUY 28/08/2018 GB00B41YBW71 1000 4.1565 12.5
BUY 01/03/2018 GB00B41YBW71 1000 3.6093 2
```

The tool can be invoked like so:
```
swift run cgtcalc data.txt
```

And will output the following:
```
# SUMMARY

Tax year    Gain    Proceeds   Exemption   Loss carry   Taxable gain
====================================================================
2019/2020   £1140   £9340      £12000      £0           £0
# TAX YEAR DETAILS

## TAX YEAR 2019/2020

1) SOLD 2000 of GB00B41YBW71 on 28/11/2019 for GAIN of £1140
Matches with:
  - BED & BREAKFAST: 500 bought on 05/12/2019 at £4.7012
  - SECTION 104: 2000 at cost basis of £3.89015
Calculation: (2000 * 4.6702 - 12.5) - ( (500 * 4.7012 + 2) + (1500 * 3.89015) ) = 1140


# TRANSACTIONS

05/12/2019 BOUGHT 500 of GB00B41YBW71 at £4.7012 with £2 expenses
28/11/2019 SOLD 2000 of GB00B41YBW71 at £4.6702 with £12.5 expenses
28/08/2018 BOUGHT 1000 of GB00B41YBW71 at £4.1565 with £12.5 expenses
01/03/2018 BOUGHT 1000 of GB00B41YBW71 at £3.6093 with £2 expenses


# ASSET EVENTS

NONE
```

## Accounting for dividends

**NOTE: The information in this section is my own interpretation. See disclaimer at the top of this README.**

Dividends in funds need special care when accounting for CGT. In both income and accumulation funds, there is an equalisation part of the first dividend payment after shares in the fund are acquired. This part is classed as a return of capital on the initial investment. This therefore means the cost basis of the acquisition needs to be lowered. The remainder of that first dividend (and all of subsequent dividends) are treated as normal income. That normal income doesn't need to be accounted for in income fund classes, but does in accumulation funds because that income is re-invested and so does not need to attract CGT as it will have attracted income tax already.

`cgtcalc` can handle both the equalisation portion of dividends (for income and accumulation fund share classes) and the accumulation-distribution portion of dividends (for accumulation fund share classes).

The equalisation portion is a `CAPRETURN` asset event. The income portion is a `DIVIDEND` asset event.

Important semantics:

- `DIVIDEND` means an accumulation distribution. It does not mean an ordinary cash dividend.
- `CAPRETURN` and `DIVIDEND` should be dated using the effective / entitlement date for the holding, not merely the later cash reporting date.
- Same-day `DIVIDEND` rows for one asset/date are validated by their summed amount, which must match the holding quantity on that date.
- Same-day `CAPRETURN` rows for one asset/date are validated by their summed amount, which must match the Group II tranche for that distribution period, i.e. the units bought since the last distribution date and still held at the event date.
- Asset-event amount validation allows a very small decimal tolerance to avoid rejecting mathematically equal split rows because of `Decimal` representation noise.
- Same-day same-asset sells are merged into one effective disposal for calculation and rounding.

### Excess Reportable Income (ERI) on reporting offshore funds

`cgtcalc` does not currently have a dedicated `ERI` input row type.

To model ERI for CGT cost-basis purposes, enter it as a `DIVIDEND` asset event:

- `AMOUNT`: the units that the ERI amount applies to
- `VALUE`: the total ERI amount for those units

Date the row using the holding entitlement / effective date for CGT cost basis (typically the fund period-end entitlement basis), not a later broker payment or statement date.

Why this matters:

- in this tool, `DIVIDEND` increases allowable cost to prevent double taxation in CGT calculations
- event-date holding validation uses the row date, so incorrect dating can fail validation or misallocate the adjustment

Important: income-tax reporting of ERI (for example SA106 timing) is separate and follows HMRC offshore-fund rules; this section is only about the CGT cost-basis treatment in this calculator.

## Extending

`cgtcalc` is broken into two parts:
  1. A library called `CGTCalcCore` which contains all of the calculation logic.
  2. A simple console app called `cgtcalc` which uses `CGTCalcCore`.

## Tests

`cgtcalc` includes a layered test suite. There are focused unit tests for smaller calculator components, engine smoke tests, and end-to-end example tests which assert that the rendered output matches expectations.

### Input/output tests

The tests that take sample input and assert on the required output are the most interesting ones because you can see what the output of the tool is for a given input. These are full end-to-end tests.

The test that controls these tests can be found here: [Tests/CGTCalcCoreTests/ExamplesTests.swift](Tests/CGTCalcCoreTests/ExamplesTests.swift)

First the test looks for all the [input data files](Tests/CGTCalcCoreTests/TestData/Examples/Inputs). Then it iterates over each of them and runs `cgtcalc` on the file. It finds the corresponding file in the [output files](Tests/CGTCalcCoreTests/TestData/Examples/Outputs) and checks that the output is identical. Any difference is reported and the test failed.

It is also possible to have private tests which according to `.gitignore` will not be added to the repo. These live in [Tests/CGTCalcCoreTests/TestData/PrivateExamples/](Tests/CGTCalcCoreTests/TestData/PrivateExamples/). They can be used to have additional tests just on your local checkout. You might want to use this to put your inputs/outputs used for Self Assessment. Then each year when you update the software, you can check that nothing has changed.

Finally, if you want to re-record the tests, then you can set `record` to `true` when calling `runTests` in `testExamples` and `testPrivateExamples`. Note that if the output file doesn't exist then the output is recorded even if record mode is off.

There is also a CLI-level formatter test target at [Tests/cgtcalcTests/](Tests/cgtcalcTests/) which covers report-formatting behavior (including PDF formatting on macOS).

## Donate

If you like this and you'd like to buy me a coffee or a beer then I would say thank you and ask you to [send to my PayPal](https://paypal.me/mattjgalloway?locale.x=en_GB).
