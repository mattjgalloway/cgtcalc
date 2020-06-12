# cgtcalc: UK capital gains tax calculator

[![Build Status](https://travis-ci.org/mattjgalloway/cgtcalc.svg?branch=master)](https://travis-ci.org/mattjgalloway/cgtcalc)
[![codecov](https://codecov.io/gh/mattjgalloway/cgtcalc/branch/master/graph/badge.svg)](https://codecov.io/gh/mattjgalloway/cgtcalc)

**DISCLAIMER: I am not a financial professional and cannot give tax advice. This calculator is intended for sample purposes only. Always do your own calculations for your self assessment. I accept no responsibility for any errors this calculator produces.**

`cgtcalc` is a command line application written in Swift which calculates UK capital gains tax based on a set of transactions. You feed it an input list of transactions and it outputs a summary of each tax year's gain (or loss) and the details for the disposal events that make up the gain (or loss).

## Why?

I developed this because I needed something that would take my transactions and calculate capitals gains tax. I wanted something which would check my manual working. I developed it in Swift because I wanted to see how building a console app in Swift was.

There are other excellent calculators out there, such as [CGTCalculator](http://www.cgtcalculator.com/), however I couldn't find one which did everything that I need. The missing piece seemed to be handling of fund equalisation payments and dividends that need to be accounted for in accumulation funds.

## Usage

Using `cgtcalc` is simple. All you need to do is the following:

  1. Clone the repository.
  2. Put your transactions into a file, such as `data.txt`.
  3. Run `swift run cgtcalc data.txt`.

That's pretty much it. You'll then see output on your console showing the calculations and a summary for all tax years that have tax events in them. You can see more details about how it's being calculated if you pass the `-v` flag.

Full usage can be found by running with `-h`:
```
USAGE: cgtcalc <filename> [--verbose] [--output-file <output-file>]

ARGUMENTS:
  <filename>              The input data filename

OPTIONS:
  -v, --verbose           Enable verbose logging
  -o, --output-file <output-file>
                          Output file
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
|-------------|-----------------|------------|
| `BUY`       | Transaction | Buy transaction | `<DATE> <ASSET> <AMOUNT> <PRICE> <EXPENSES>` |
| `SELL`      | Transaction | Sell transaction | `<DATE> <ASSET> <AMOUNT> <PRICE> <EXPENSES>` |
| `CAPRETURN` | Asset event | Capital return event (usually for a fund on first dividend distribution after purchase) | `<DATE> <ASSET> <AMOUNT> <VALUE>` |
| `DIVIDEND`  | Asset event | Dividend for which income tax has been taken but shares also retain (usually for fund accumulation share class) | `<DATE> <ASSET> <AMOUNT> <VALUE>` |

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

Tax year    Gain    Exemption   Loss carry   Taxable gain   Tax (basic)   Tax (higher)
======================================================================================
2019/2020   £1139   £12000      £0           £0             £0            £0


# TAX YEAR DETAILS

## TAX YEAR 2019/2020

1) SOLD 2000 of GB00B41YBW71 on 28/11/2019 for GAIN of £1139
Matches with:
  - BED & BREAKFAST: 500 bought on 05/12/2019 at £4.7012 with offset of £0
  - SECTION 104: 2000 at cost basis of £3.89015
Calculation: (2000 * 4.6702 - 12.5) - ( (500 * 4.7012 + 0 + 2) + (1500 * 3.89015) ) = 1139


# TRANSACTIONS

1: 05/12/2019 BOUGHT 500 of GB00B41YBW71 at £4.7012 with £2 expenses
2: 28/11/2019 SOLD 2000 of GB00B41YBW71 at £4.6702 with £12.5 expenses
3: 28/08/2018 BOUGHT 1000 of GB00B41YBW71 at £4.1565 with £12.5 expenses
4: 01/03/2018 BOUGHT 1000 of GB00B41YBW71 at £3.6093 with £2 expenses


# ASSET EVENTS

NONE
```

## Extending

`cgtcalc` is broken into two parts:
  1. A library called `CGTCalcCore` which contains all of the calculation logic.
  2. A simple console app called `cgtcalc` which uses `CGTCalcCore`.

You can extend `CGTCalcCore` in two interesting ways:
  1. Create a custom parser to parse from your own format into what `CGTCalcCore` requires. The default parser that comes with the library is called `DefaultParser`.
  2. Create a custom presenter to process the output from `CGTCalcCore` and display it how you wish. The presenter that outputs in text format is called `TextPresenter`.

It's best to look at `main.swift` to see how to use `CGTCalcCore`. It's essentially as follows:

```swift
import CGTCalcCore
import Foundation

...

// Custom parser could be used here
let parser = DefaultParser()
let data = "... read from file ..."
let input = try parser.calculatorInput(fromData: data)

// Create calculator, feeding it the input created above, and then process it
let calculator = try Calculator(input: input, logger: logger)
let result = try calculator.process()

// Custom presenter could be used here
let presenter = TextPresenter(result: result)
let output = try presenter.process()
```

## Tests

`cgtcalc` includes a comprehensive test suite. The most interesting ones are in [Tests/CGTCalcCoreTests/Examples](Tests/CGTCalcCoreTests/Examples). These are full end-to-end tests which have [input data files](Tests/CGTCalcCoreTests/Examples/Inputs) and check against equivalent [output files](Tests/CGTCalcCoreTests/Examples/Outputs). Those are worth looking at to see how the calculator responds to given inputs.
