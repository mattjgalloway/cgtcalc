 cgtcalc: UK capital gains tax main

DISCLAIMER: I am not a financial professional and cannot give tax advice. This calculator is intended for sample purposes only. Always do your own calculations for your self assessment. I accept no responsibility for any errors this calculator produces.**

`cgtcalc` is a command line application written in Swift which calculates UK capital gains tax based on a set of transactions. You feed it an input list of transactions and it outputs a summary of each tax year's gain (or loss) and the details for the disposal events that make up the gain (or loss).

 Why?

I developed this because I needed something that would take my transactions and calculate capitals gains tax. I wanted something which would check my manual working. I developed it in Swift because I wanted to see how building a console app in Swift was.

There are other excellent calculators out there, such as main, however I couldn't find one which did everything that I need. The missing piece seemed to be handling of fund equalisation payments and dividends that need to be accounted for in accumulation funds.

 What does it support?

Currently the calculator supports the full range of matches of acquisitions to disposals for the current capital gains tax system, namely supporting matching based on the following rules in this order:

1) Same day trades.
2) Bed & breakfast trades where you purchase an asset within 30 days of selling the same asset.
3) Section 104 holding.

The calculator specifically only deals with shares where the acquisition and disposals are all on or after 6th April 2008 when the latest rules came into effect.

It also supports handling of equalisation payments (capital return) for funds where those amounts should be subtracted from the acquisition proceeds. And it also supports handling of dividends within accumulation share classes of funds where those amounts can be subtracted from the disposal proceeds.

 What does it not support?

Currently there is no support for:

1) Transactions before 6th April 2008.
2) Anything I haven't thought of (as I say in the disclaimer - I am not a financial professional).

 Platforms

The library and console app that makes up `cgtcalc` both work fully on both macOS and Linux. It's running on a Linux server at https://cgtcalc.galloway.me.uk/.

> 

 Usage

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

 Input data

Each row of the input file starts with the kind of data followed by details. For example a buy transaction, for 200 shares of LON:FOOBAR on 01/01/2020 at £1.50 with £20 expenses would be as follows:

```
BUY 01/01/2020 LON:FOOBAR 200 1.5 20
```

The full list of kinds of data are as follows:

| Kind    | Category | Description | Fields |
|-------------|--------------|-----------------|------------|
| BUY       | Transaction  | Buy transaction | <DATE> <ASSET> <AMOUNT> <PRICE> <EXPENSES> |
| SELL      | Transaction  | Sell transaction | <DATE> <ASSET> <AMOUNT> <PRICE> <EXPENSES> |
| CAPRETURN | Asset event  | Capital return event (usually for a fund on first dividend distribution after purchase) | <DATE> <ASSET> <AMOUNT> <VALUE> |
| DIVIDEND  | Asset event  | Dividend for which income tax has been taken but shares also retain (usually for fund accumulation share class) | <DATE> <ASSET> <AMOUNT> <VALUE> |
| SPLIT     | Asset event  | Stock split     | <DATE> <ASSET> <MULTIPLIER> |
| UNSPLIT   | Asset event  | Stock un-split  | <DATE> <ASSET> <MULTIPLIER> |

 Example

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
 SUMMARY

Tax year    Gain    Exemption   Loss carry   Taxable gain   Tax (basic)   Tax (higher)
======================================================================================
2019/2020   £1140   £12000      £0           £0             £0            £0

 TAX YEAR DETAILS

 TAX YEAR 2019/2020

1) SOLD 2000 of GB00B41YBW71 on 28/11/2019 for GAIN of £1140
Matches with:
  - BED & BREAKFAST: 500 bought on 05/12/2019 at £4.7012
  - SECTION 104: 2000 at cost basis of £3.89015
Calculation: (2000 * 4.6702 - 12.5) - ( (500 * 4.7012 + 2) + (1500 * 3.89015) ) = 1140

 TRANSACTIONS

05/12/2019 BOUGHT 500 of GB00B41YBW71 at £4.7012 with £2 expenses
28/11/2019 SOLD 2000 of GB00B41YBW71 at £4.6702 with £12.5 expenses
28/08/2018 BOUGHT 1000 of GB00B41YBW71 at £4.1565 with £12.5 expenses
01/03/2018 BOUGHT 1000 of GB00B41YBW71 at £3.6093 with £2 expenses

 ASSET EVENTS

NONE
```

 Accounting for dividends

NOTE: The information in this section is my own interpretation. See disclaimer at the top of this README.**

Dividends in funds need special care when accounting for CGT. In both income and accumulation funds, there is an equalisation part of the first dividend payment after shares in the fund are acquired. This part is classed as a return of capital on the initial investment. This therefore means the cost basis of the acquisition needs to be lowered. The remainder of that first dividend (and all of subsequent dividends) are treated as normal income. That normal income doesn't need to be accounted for in income fund classes, but does in accumulation funds because that income is re-invested and so does not need to attract CGT as it will have attracted income tax already.

`cgtcalc` can handle both the equalisation portion of dividends (for income and accumulation fund share classes) and the income portion of dividends (for accumulation fund share classes).

The equalisation portion is a `CAPRETURN` asset event. The income portion is a `DIVIDEND` asset event.

 Unclear rules of semi-disposals

One complication with handling these is what to do when there are semi-disposals (i.e. not the full amount held at time of sale). It's unclear from documentation how that is handled. For example, consider the following set of transactions:

```
01/08/2019: BUY 10 at £100
01/09/2019: SELL 5 at £105
01/01/2020: BUY 10 at £90
01/04/2020: Dividend equalisation of £50 on 15 shares
01/04/2020: Dividend income of £30 on 15 shares

01/06/2020: BUY 10 at £80
01/07/2020: SELL 5 at £100
01/04/2021: Dividend equalisation of £10 on 10 shares
01/04/2021: Dividend income of £40 on 20 shares
```

It's unclear precisely which shares attract equalisation. In the case of the second dividend, depending on how things are calculated, there might be an equalisation payment or there might not be.

`cgtcalc` handles these cases by assuming FIFO for these purposes. So in the example above, the first dividend (both the equalisation and income) would be split `5/15` on the first buy, and `10/15` on the second buy. The second dividend's equalisation portion would be applied to the third buy alone. The second dividend's income portion would be split across the second and third buys at `10/20` each. The first buy doesn't attract the second dividend's income portion because that lot is fully sold by the FIFO ordering scheme.

 Extending

 Tests

`cgtcalc` includes a comprehensive test suite. There are tests that cover the basic functionality through unit tests. There are also tests that take sample input and assert that the output matches that which is expected.

 Input/output tests

The tests that take sample input and assert on the required output are the most interesting ones because you can see what the output of the tool is for a given input. These are full end-to-end tests.

The test that controls these tests can be found here: main

First the test looks for all the main. Then it iterates over each of them and runs `cgtcalc` on the file. It finds the corresponding file in the main and checks that the output is identical. Any difference is reported and the test failed.

It is also possible to have private tests which according to `.gitignore` will not be added to the repo. These live in main. They can be used to have additional tests just on your local checkout. You might want to use this to put your inputs/outputs used for Self Assessment. Then each year when you update the software, you can check that nothing has changed.

Finally, if you want to re-record the tests, then you can set `record` to `true` when calling `runTests` in `testExamples` and `testPrivateExamples`. Note that if the output file doesn't exist then the output is recorded even if record mode is off.

 Donate

If you like this and you'd like to buy me a coffee or a beer then I would say thank you and ask you to send to main.
