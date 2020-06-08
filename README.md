# cgtcalc: UK capital gains tax calculator

**DISCLAIMER: I am not a financial professional and cannot give tax advice. This calculator is intended for sample purposes only. Always do your own calculations for your self assessment.**

`cgtcalc` is a command line application written in Swift which calculates UK capital gains tax based on a set of transactions. You feed it an input list of transactions and it outputs a summary of each tax year's gain (or loss) and the details for the disposal events that make up the gain (or loss).

## Example

Given the following input in a file called `data.txt`:
```
SELL 28/08/2018 GB00B41YBW71 10 4.6702 12.5 0
BUY 28/08/2018 GB00B41YBW71 10 4.1565 12.5 0
```

The tool can be invoked like so:
```
swift run cgtcalc data.txt
```

And will output the following:
```
# SUMMARY

Year 2018/2019: Gain = £-19, Exemption = £11700


# DETAILS

## TAX YEAR 2018/2019

1) SOLD 10 of GB00B41YBW71 on 28/08/2018 for gain of £-19
Matches with:SAME DAY: 10 bought on 28/08/2018 at 4.1565
Calculation: (10 * £4.6702 - £12.5) - ( (10 * £4.1565 + £12.5) ) = £-19
```

## Usage

TODO

## Extending

TODO
