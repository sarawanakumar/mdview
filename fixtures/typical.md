# Ledgerline

A small command-line tool for keeping accounts in plain text files. You write
transactions in a simple format, and Ledgerline checks them, totals them and
prints reports. Everything stays in files you own and can read without it.

![Ledgerline's balance report in a terminal](images/sample.png)

> **Status:** stable. The file format hasn't changed since version 2.0, and
> any future change will come with a converter.

## Contents

- [Why Ledgerline](#why-ledgerline)
- [Install](#install)
- [Quick start](#quick-start)
- [The file format](#the-file-format)
- [Configuration](#configuration)
- [Command reference](#command-reference)
- [Recipes](#recipes)
- [Questions](#questions)
- [Contributing](#contributing)
- [Changelog](#changelog)
- [License](#license)

## Why Ledgerline

Most money apps keep your data in a database you can't open, sync it to a
server you don't control, and change their export format every few years.
Ledgerline takes the opposite approach:

- **Plain text.** Your accounts are ordinary files. Any editor works, and
  version control gives you history for free.
- **Checked.** Every transaction must balance. Typos in account names are
  caught, and so are dates that go backwards.
- **Fast.** Ten years of household accounts (about 40,000 transactions)
  load in under a second on a laptop.
- **Quiet.** No accounts, no telemetry, no network access at all.

It isn't a replacement for a full accounting package. There is no payroll,
no invoicing and no tax engine. It's for people who want to know where their
money went, and who are happy typing.

## Install

### macOS

```bash
brew install ledgerline
ledgerline --version
```

### Linux

Download the archive for your platform from the releases page, then:

```bash
tar -xzf ledgerline-3.2.0-linux-x86_64.tar.gz
sudo install -m 755 ledgerline /usr/local/bin/
```

### From source

You need a recent Rust toolchain (1.80 or later).

```bash
git clone https://example.com/ledgerline.git
cd ledgerline
cargo build --release
./target/release/ledgerline --help
```

The build has no network step after the first `cargo fetch`, so it works
offline once the dependencies are cached.

## Quick start

Create a file called `2026.ledger`:

```
2026-01-01 Opening balances
    assets:bank:current        1,250.00 GBP
    assets:cash                   40.00 GBP
    equity:opening

2026-01-03 Corner shop
    expenses:food:groceries       23.45 GBP
    assets:cash

2026-01-05 Salary
    assets:bank:current        2,800.00 GBP
    income:salary
```

Then ask for a balance:

```bash
ledgerline balance 2026.ledger
```

```
        4,026.55 GBP  assets
        4,050.00 GBP    bank:current
          -23.45 GBP    cash
          23.45 GBP  expenses:food:groceries
       -1,290.00 GBP  equity:opening
       -2,800.00 GBP  income:salary
--------------------
               0
```

The total is zero because every transaction balances. If it isn't, Ledgerline
tells you which transaction is wrong and by how much.

## The file format

A transaction is a date, a description, and two or more postings. Each
posting is an account name and an amount. One posting may leave its amount
out; Ledgerline fills it in so the transaction balances.

| Part | Example | Notes |
|:-----|:--------|:------|
| Date | `2026-01-03` | ISO format only. `2026/01/03` is rejected. |
| Status | `*` or `!` | Optional. Cleared or pending. |
| Description | `Corner shop` | Free text up to the end of the line. |
| Account | `expenses:food` | Colon-separated. Spaces are allowed inside names. |
| Amount | `23.45 GBP` | Commodity after the number. Commas are ignored. |
| Comment | `; receipt in drawer` | Anything after a semicolon. |

Indent postings by at least two spaces. Separate the account from the amount
by at least two spaces too, since account names may contain single spaces.

### Comments and tags

```
2026-02-14 * Dinner out  ; :dining:celebration:
    expenses:food:restaurants     64.00 GBP  ; split with Sam
    liabilities:credit-card
```

Tags go between colons in a comment. Reports can filter on them with
`tag:dining`.

### Prices and currencies

A posting can carry a price, so you can record a purchase in another
currency:

```
2026-03-02 Train ticket, Paris
    expenses:travel               45.00 EUR @ 0.86 GBP
    liabilities:credit-card
```

Ledgerline keeps the original amount, and converts it only when a report
asks for a single currency with `--value GBP`.

## Configuration

Ledgerline reads `~/.config/ledgerline/config.yaml` if it exists. Every
setting is optional.

```yaml
# Where to look when no file is given
default_file: ~/accounts/main.ledger

# How amounts are printed
decimal_mark: "."
thousands_separator: ","
currency_position: after

# Reports
week_starts_on: monday
fiscal_year_start: 04-06
colour: auto
```

| Setting | Default | Meaning |
|---|---|---|
| `default_file` | none | File used when no file is named on the command line. |
| `decimal_mark` | `.` | Character between whole and fractional parts. |
| `thousands_separator` | `,` | Character between groups of three digits. |
| `currency_position` | `after` | Whether `GBP` goes before or after the number. |
| `week_starts_on` | `monday` | First day of the week for weekly reports. |
| `fiscal_year_start` | `01-01` | Month and day the reporting year begins. |
| `colour` | `auto` | `always`, `never`, or `auto` (only in a terminal). |

The environment variable `LEDGERLINE_FILE` overrides `default_file`.

## Command reference

Every command takes one or more files, or reads `default_file` when none is
given. Common options:

| Option | Short | Meaning |
|---|:-:|---|
| `--begin DATE` | `-b` | Ignore transactions before this date. |
| `--end DATE` | `-e` | Ignore transactions on or after this date. |
| `--period TEXT` | `-p` | A period such as `2026`, `2026-q1` or `last month`. |
| `--depth N` | `-d` | Collapse accounts deeper than N levels. |
| `--value CUR` | `-V` | Convert every amount to one currency. |
| `--output FILE` | `-o` | Write to a file instead of the terminal. |



### balance

Shows the balance of each account. Prints the total of every posting to each account, with parent accounts summing their children.

```bash
ledgerline balance -p 2026 expenses
```

| Option | Meaning |
|---|---|
| `--flat` | List accounts without indentation. |
| `--empty` | Include accounts with a zero balance. |

Use `--depth 2` for a short overview, and leave it off to see everything.

#### How it works

`balance` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline balance -p 2026 expenses
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### register

Lists postings one per line, with a running total. Prints each matching posting in date order, with the running total in the last column.

```bash
ledgerline register expenses:food -p 'last month'
```

| Option | Meaning |
|---|---|
| `--wide` | Use the full terminal width for descriptions. |
| `--average` | Show a running average instead of a total. |

The running total resets for each file unless you name the files together.

#### How it works

`register` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline register expenses:food -p 'last month'
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### print

Prints transactions back out, cleaned up. Prints the matching transactions with consistent spacing, missing amounts filled in, and accounts aligned.

```bash
ledgerline print -p 2026-03 > march.ledger
```

| Option | Meaning |
|---|---|
| `--explicit` | Write out every amount, including the inferred one. |
| `--sort FIELD` | Sort by `date`, `payee` or `amount`. |

Handy for splitting a large file by year.

#### How it works

`print` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline print -p 2026-03 > march.ledger
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### check

Checks files without printing a report. Prints nothing when everything is fine, and a list of problems otherwise.

```bash
ledgerline check --strict main.ledger
```

| Option | Meaning |
|---|---|
| `--strict` | Require every account to be declared first. |
| `--dates` | Fail if dates go backwards within a file. |

Run it from a pre-commit hook so mistakes never reach your history.

#### How it works

`check` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline check --strict main.ledger
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### accounts

Lists every account name used. Prints one account name per line, in alphabetical order.

```bash
ledgerline accounts --tree
```

| Option | Meaning |
|---|---|
| `--tree` | Indent child accounts under their parents. |
| `--unused` | Only accounts declared but never posted to. |

A quick way to spot a misspelt account.

#### How it works

`accounts` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline accounts --tree
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### payees

Lists every payee (transaction description). Prints one payee per line, with how many transactions each has.

```bash
ledgerline payees --count | head
```

| Option | Meaning |
|---|---|
| `--count` | Sort by number of transactions. |
| `--since DATE` | Only payees seen since the date. |

Descriptions are compared exactly, so `Tesco` and `TESCO` are different payees.

#### How it works

`payees` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline payees --count | head
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### stats

Summarises a file. Prints the date range, number of transactions, accounts, payees and commodities.

```bash
ledgerline stats --by-year
```

| Option | Meaning |
|---|---|
| `--by-year` | One summary line for each year. |
| `--json` | Print the summary as JSON. |

Useful as a quick sanity check after importing.

#### How it works

`stats` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline stats --by-year
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### import

Converts a bank's CSV export into transactions. Prints new transactions, skipping any already present in the target file.

```bash
ledgerline import --rules bank.rules statement.csv
```

| Option | Meaning |
|---|---|
| `--rules FILE` | Rules that map columns and payees to accounts. |
| `--dry-run` | Show what would be added without writing anything. |

Run with `--dry-run` first, at least until your rules settle down.

#### How it works

`import` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline import --rules bank.rules statement.csv
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### close

Closes the books for a period. Prints transactions that zero the income and expense accounts into equity.

```bash
ledgerline close -e 2027-01-01 --open
```

| Option | Meaning |
|---|---|
| `--retain ACCOUNT` | Account that receives the result (default `equity:retained`). |
| `--open` | Also print opening balances for the next period. |

Keep the closing transactions in their own file so they're easy to redo.

#### How it works

`close` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline close -e 2027-01-01 --open
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### budget

Compares spending with a budget. Prints each budgeted account with its budget, actual spending and the difference.

```bash
ledgerline budget -p 2026 --monthly
```

| Option | Meaning |
|---|---|
| `--monthly` | One column for each month. |
| `--over` | Only accounts over budget. |

Budgets are periodic transactions that start with `~`.

#### How it works

`budget` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline budget -p 2026 --monthly
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### forecast

Projects balances forward. Prints future postings generated from periodic transactions, added to the register.

```bash
ledgerline forecast --until 2027-06-30 assets:bank
```

| Option | Meaning |
|---|---|
| `--until DATE` | How far ahead to project (default: one year). |
| `--only` | Show only the projected postings. |

Forecasts never write to your files; they're computed each time.

#### How it works

`forecast` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline forecast --until 2027-06-30 assets:bank
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### prices

Lists commodity prices. Prints every price seen, from `P` directives and from postings with `@`.

```bash
ledgerline prices --latest
```

| Option | Meaning |
|---|---|
| `--latest` | Only the most recent price for each pair. |
| `--inverse` | Also show the inverse of each price. |

Prices are only ever read from your files; Ledgerline never fetches them.

#### How it works

`prices` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline prices --latest
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### tags

Lists tags and how often they're used. Prints each tag, with the number of transactions and the total amount.

```bash
ledgerline tags --sort count
```

| Option | Meaning |
|---|---|
| `--values` | Also list the values given to `tag:value` tags. |
| `--sort count` | Sort by use instead of by name. |

Tags are case-sensitive.

#### How it works

`tags` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline tags --sort count
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### diff

Compares two files. Prints transactions present in one file but not the other.

```bash
ledgerline diff bank-export.ledger main.ledger
```

| Option | Meaning |
|---|---|
| `--ignore-status` | Treat cleared and pending the same. |
| `--by-amount` | Match transactions by date and amount only. |

A good way to reconcile against a statement.

#### How it works

`diff` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline diff bank-export.ledger main.ledger
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### rewrite

Adds postings to matching transactions. Prints the transactions with extra postings added, for example to split out tax.

```bash
ledgerline rewrite --query expenses:fuel --add 'expenses:tax *0.2'
```

| Option | Meaning |
|---|---|
| `--add 'ACCOUNT AMOUNT'` | Posting to add. Amounts can be a fraction like `*0.2`. |
| `--query TEXT` | Which transactions to change. |

Prints the result; it never edits a file in place.

#### How it works

`rewrite` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline rewrite --query expenses:fuel --add 'expenses:tax *0.2'
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### files

Lists the files that were read. Prints each file read, including those pulled in by `include`.

```bash
ledgerline files --tree
```

| Option | Meaning |
|---|---|
| `--sizes` | Show file sizes. |
| `--tree` | Show which file included which. |

Useful when a figure seems to come from nowhere.

#### How it works

`files` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline files --tree
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### roi

Works out return on investment. Prints the time-weighted and money-weighted return of an investment account.

```bash
ledgerline roi --inv assets:pension --pnl income:pension -p 2026
```

| Option | Meaning |
|---|---|
| `--inv ACCOUNT` | The investment account. |
| `--pnl ACCOUNT` | The account that records gains and losses. |

Needs prices for the commodities held, at least at the start and end.

#### How it works

`roi` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline roi --inv assets:pension --pnl income:pension -p 2026
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### activity

Draws a simple histogram of postings. Prints one row for each period, with a bar of `*` showing how many postings it had.

```bash
ledgerline activity --weekly -p 2026
```

| Option | Meaning |
|---|---|
| `--weekly` | One row per week. |
| `--daily` | One row per day. |

Gaps show up as rows with no bar.

#### How it works

`activity` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline activity --weekly -p 2026
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### commodities

Lists every commodity used. Prints each commodity with its display precision and where it was first seen.

```bash
ledgerline commodities --undeclared
```

| Option | Meaning |
|---|---|
| `--declared` | Only commodities declared with a `commodity` line. |
| `--undeclared` | Only commodities used but never declared. |

Declare commodities to control how many decimal places they print with.

#### How it works

`commodities` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline commodities --undeclared
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### notes

Lists the notes part of descriptions. Prints the text after a `|` in each description, which many people use for details.

```bash
ledgerline notes --unique -p 2026
```

| Option | Meaning |
|---|---|
| `--with-payee` | Show the payee next to each note. |
| `--unique` | Drop repeated notes. |

Descriptions without a `|` have no note and aren't listed.

#### How it works

`notes` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline notes --unique -p 2026
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### aregister

Shows one account's register as a bank statement would. Prints each transaction touching the account, with the other accounts in a column and the account's running balance.

```bash
ledgerline aregister assets:bank:current -p 2026-02
```

| Option | Meaning |
|---|---|
| `--txn-dates` | Use transaction dates instead of posting dates. |
| `--cleared` | Only cleared transactions. |

Easier to compare with a statement than `register`, since each transaction is one line.

#### How it works

`aregister` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline aregister assets:bank:current -p 2026-02
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

### incomestatement

Prints income and expenses side by side. Prints income accounts, then expense accounts, then the net result for the period.

```bash
ledgerline incomestatement -p 2026 --quarterly
```

| Option | Meaning |
|---|---|
| `--quarterly` | One column for each quarter. |
| `--percent` | Show each account as a percentage of its section. |

Signs are flipped for income so that both sections read as positive numbers.

#### How it works

`incomestatement` reads every file first, so the order in which you name files only
matters for the running totals. It then applies the date options, then any
account or tag patterns, and only then works out what to print. Patterns are
matched against the whole account name, so `food` matches
`expenses:food:groceries` but `^food` doesn't.

Amounts in different commodities are never added together. If an account
holds both GBP and EUR, both appear on their own lines, unless you ask for
`--value` with a price to convert with.

#### Example output

```
$ ledgerline incomestatement -p 2026 --quarterly
  2026-01-03  Corner shop        expenses:food:groceries     23.45 GBP     23.45 GBP
  2026-01-10  Market             expenses:food:groceries     12.10 GBP     35.55 GBP
  2026-01-17  Corner shop        expenses:food:groceries     18.90 GBP     54.45 GBP
```

See also: [Command reference](#command-reference), [Recipes](#recipes) and
[the file format](#the-file-format).

## Tutorial: a year of household accounts

This walk-through builds a realistic file for one household over a year. It
takes about twenty minutes, and by the end you'll have used most commands.

### 1. Decide on your accounts

Start small. You can always split an account later with `rewrite`, but
merging lots of tiny accounts is tedious. A good first set:

1. `assets:bank:current` for the everyday account
2. `assets:bank:savings` for the savings account
3. `assets:cash` for the wallet
4. `liabilities:credit-card` for the one card you use
5. `income:salary` and `income:interest`
6. `expenses:` followed by a handful of categories

Declare them at the top of the file, so `check --strict` can catch typos:

```
account assets:bank:current
account assets:bank:savings
account assets:cash
account liabilities:credit-card
account income:salary
account income:interest
account expenses:food:groceries
account expenses:food:restaurants
account expenses:home:rent
account expenses:home:energy
account expenses:transport
account expenses:fun
account equity:opening
```

### 2. Record opening balances

Look up each balance on the first day of the year and write one
transaction. The equity posting has no amount; Ledgerline fills it in.

```
2026-01-01 Opening balances
    assets:bank:current          1,250.00 GBP
    assets:bank:savings          6,400.00 GBP
    assets:cash                     40.00 GBP
    liabilities:credit-card       -312.18 GBP
    equity:opening
```

### 3. Add regular payments

Rent, energy and the salary happen every month. Rather than typing them
twelve times, write them once as periodic transactions and let `forecast`
show the year ahead. When each one really happens, copy it in with the real
date and amount.

```
~ monthly from 2026-01-01
    expenses:home:rent             950.00 GBP
    assets:bank:current

~ monthly from 2026-01-15
    expenses:home:energy            86.00 GBP
    assets:bank:current
```

### 4. Import the card statement

Card statements are the most tedious part to type, so import them. Save a
rules file next to your accounts:

```
# card.rules
skip 1
fields date, description, amount
date-format %d/%m/%Y
currency GBP
account1 liabilities:credit-card

if TESCO|SAINSBURY|CO-OP
  account2 expenses:food:groceries
if TRAINLINE|TFL
  account2 expenses:transport
```

Then try it:

```bash
ledgerline import --rules card.rules --dry-run statement-2026-01.csv
```

Anything the rules don't match goes to `expenses:unknown`. Add a rule for
it, run the import again, and repeat until nothing is unknown.

### 5. Check and look around

```bash
ledgerline check --strict 2026.ledger
ledgerline balance --depth 2
ledgerline register expenses:food -p 2026-01
ledgerline activity --weekly
```

If `check` complains, it names the file and line. The most common problems
are a single space between the account and the amount, and a transaction
that doesn't balance because of a missing minus sign.

### 6. Close the year

On the first of January, close the old year so the new file starts clean:

```bash
ledgerline close -e 2027-01-01 --open 2026.ledger > 2027-opening.ledger
```

## Error messages

| Message | What it means | What to do |
|---|---|---|
| `transaction does not balance` | The postings don't add up to zero. | Check signs and amounts; the message shows the difference. |
| `two postings without amounts` | Only one posting may leave its amount out. | Add an amount to one of them. |
| `unknown account` | With `--strict`, an account wasn't declared. | Declare it, or fix the spelling. |
| `date goes backwards` | With `--dates`, a transaction is earlier than the one before it. | Move it, or drop `--dates`. |
| `bad date` | The date isn't in `YYYY-MM-DD` form. | Rewrite it in ISO format. |
| `single space before amount` | The account and amount are separated by one space. | Use two or more spaces. |
| `unknown commodity` | With `--strict`, a commodity wasn't declared. | Add a `commodity` line. |
| `include not found` | An `include` names a file that doesn't exist. | Check the path; it's relative to the including file. |
| `price has no commodity` | An `@` price is a bare number. | Write the commodity after the number. |
| `rules: no date field` | An import rules file doesn't say which column is the date. | Add `date` to the `fields` line. |

## Recipes

### Monthly spending by category

```bash
ledgerline balance expenses --depth 2 --monthly -p 2026 --empty
```

### Find big purchases

```bash
ledgerline register expenses 'amount:>200' -p 'this year'
```

### Keep one file per year

Put each year in its own file and a small main file that includes them:

```
include 2024.ledger
include 2025.ledger
include 2026.ledger
```

### A pre-commit hook

```bash
#!/bin/sh
# .git/hooks/pre-commit
exec ledgerline check --strict --dates main.ledger
```

### Export a report for a spreadsheet

```bash
ledgerline balance -p 2026 --output 2026.csv
```

The output format follows the file extension: `.csv`, `.json`, `.html` and
`.txt` are supported.

### Reading the JSON output

```json
{
  "account": "expenses:food:groceries",
  "amounts": [{ "commodity": "GBP", "quantity": 1834.52 }],
  "postings": 147,
  "children": []
}
```

### Using it from Python

```python
import json
import subprocess

def balance(account, period="this year"):
    """Return the balance of an account as a float, in GBP."""
    result = subprocess.run(
        ["ledgerline", "balance", account, "-p", period, "--output", "-.json"],
        capture_output=True, text=True, check=True,
    )
    rows = json.loads(result.stdout)
    return sum(a["quantity"] for r in rows for a in r["amounts"] if a["commodity"] == "GBP")

print(f"Groceries so far: {balance('expenses:food:groceries'):.2f}")
```

## Questions

**Does it work with files from other plain-text accounting tools?**
Mostly. The format is close to the common ledger dialects. Automated
transactions and some directives aren't supported, and `check` tells you
which lines it skipped.

**Can several people edit the same file?**
Yes, the same way several people edit any text file. Version control and
small, frequent commits work well. Transactions merge cleanly because each
one is a separate block.

**Why doesn't it download exchange rates or share prices?**
Ledgerline never uses the network, on purpose. Add `P` lines yourself, or
generate them with a separate script and `include` the result.

**How big can a file get?**
Files with a few hundred thousand transactions work, though reports take a
few seconds. Splitting by year keeps everyday reports fast.

**Is there a graphical app?**
No, and there are no plans for one. Several editors have syntax colouring
for the format, which is most of what a graphical app would add.

## Design notes

These notes explain some choices that surprise people. They're here so that
future changes can keep to the same ideas, or change them on purpose.

### Why amounts are decimals, not floats

Money adds up exactly or not at all. Every amount is stored as a whole
number of the smallest unit seen for that commodity, together with the
number of decimal places. Adding `0.10` ten times gives exactly `1.00`, and
a report never shows `0.30000000000000004`. Prices are the exception: a
price can have as many decimal places as you write, and conversions are
rounded once, at the end, to the commodity's usual precision.

### Why the format is strict about spaces

Account names may contain single spaces, so `expenses:eating out` is a valid
account. That means one space can't also separate the account from the
amount, and the format asks for two. It's the most common mistake new users
make, which is why `check` has a message for it that says exactly what to do.

### Why there's no automatic categorisation

Guessing categories from descriptions is easy to get mostly right and very
hard to get completely right. A wrong guess you don't notice is worse than
no guess at all, because it quietly corrupts your reports. Import rules are
explicit instead: every match is something you wrote, and anything that
doesn't match is left in `expenses:unknown` where you'll see it.

### Why reports never write to your files

Commands such as `rewrite`, `close` and `print` produce text that looks like
a ledger file, but they print it rather than saving it. You decide where it
goes, usually with a shell redirect, and your version control shows exactly
what changed. A tool that edits your only copy of your accounts in place
needs to be perfect; one that prints doesn't.

### Why it never touches the network

Exchange rates and share prices are the obvious thing to fetch, and every
fetch is a chance for something to go wrong: a changed API, a rate limit, a
leak of what you own to whoever runs the server. Keeping the network out
entirely means Ledgerline behaves the same on a plane as at home, and the
same in five years as today.

### Performance

The parser reads files in a single pass and keeps transactions in date
order as it goes, so most reports are a single walk over memory. On a 2024
laptop, the numbers for a 40,000-transaction file are roughly:

| Step | Time |
|---|--:|
| Read and parse | 180 ms |
| Check balances and accounts | 25 ms |
| `balance` report | 15 ms |
| `register` for one account | 30 ms |
| `forecast` one year ahead | 60 ms |

Startup itself is under 10 ms, so small files feel instant.

## Glossary

- **Account:** a named place where amounts accumulate, such as
  `assets:bank:current`. Accounts form a tree through their colons.
- **Posting:** one line of a transaction: an account and an amount.
- **Transaction:** a dated group of postings that adds up to zero.
- **Commodity:** what an amount is measured in: a currency, a share, or
  anything else you count, such as `hours`.
- **Price:** how much of one commodity another is worth on a date.
- **Periodic transaction:** a template starting with `~`, used for budgets
  and forecasts. It's never counted as a real transaction.
- **Cleared:** a transaction marked `*`, meaning it has appeared on a
  statement.
- **Pending:** a transaction marked `!`, meaning it's expected but not yet
  confirmed.

## Contributing

Bug reports and small fixes are very welcome. Before starting anything
larger, open an issue so we can agree on the approach.

- [x] Write a failing test that shows the bug
- [x] Keep changes focused: one fix or feature per pull request
- [ ] Run `cargo fmt` and `cargo clippy` before pushing
- [ ] Update this README if behaviour changes

The test suite runs with `cargo test`. Report tests compare output with
files in `tests/expected/`; set `LEDGERLINE_BLESS=1` to rewrite them after a
deliberate change, then check the diff.

### Project layout

| Folder | What's in it |
|---|---|
| `src/parse/` | The file format parser and its error messages. |
| `src/query/` | Account, date and tag filters. |
| `src/report/` | One module per command. |
| `src/output/` | Text, CSV, JSON and HTML writers. |
| `tests/` | Integration tests and their expected output. |

## Changelog

### 3.2.0 (2026-09-14)

- `activity` gains `--daily`.
- `import` now remembers the last row it saw, so re-running it is faster.
- Fixed: `close --open` used the wrong date for the opening transaction.

### 3.1.0 (2026-05-02)

- New `roi` command.
- `budget --over` lists only overspent accounts.
- Account names may now contain digits at the start.

### 3.0.0 (2026-01-10)

- Reports can write CSV, JSON and HTML with `--output`.
- **Breaking:** `--format` is removed; use `--output` with a file extension.
- Minimum Rust version is now 1.80.

### 2.6.1 (2025-10-21)

- Fixed a crash when a file ended in the middle of a transaction.
- Fixed: tags with hyphens were split in two.

### 2.6.0 (2025-08-03)

- New `diff` command for reconciling against statements.
- `register --average` shows a running average.

### 2.5.0 (2025-04-17)

- `forecast` can project up to ten years ahead.
- Faster loading of files with many `include` lines (about 3x).

### 2.4.0 (2025-01-06)

- New `rewrite` command.
- `check --dates` reports dates that go backwards.

### 2.3.0 (2024-11-12)

- `import` rules can match on amount ranges.
- `payees --since` lists only recent payees.
- Fixed: `--depth 1` hid the total line.

### 2.2.0 (2024-08-25)

- HTML output uses the system font and follows dark mode.
- `balance --flat` lists accounts without indentation.

### 2.1.0 (2024-06-01)

- New `tags` command.
- Comments may start with `#` as well as `;`.

### 2.0.0 (2024-03-30)

- The file format is now stable.
- **Breaking:** dates must be in ISO format.

## License

Ledgerline is released under the MIT License. See `LICENSE` for the full
text.

---

*This file is a made-up README used to test mdview. Ledgerline isn't a real
project.*
