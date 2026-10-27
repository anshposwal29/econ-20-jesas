# econ-20-jesas

ECON 20 project: California SB 826 (board gender quota, signed 30 Sep 2018) and firm value.

## TL;DR: `final_data.dta`

- **One row = one firm-year.** 61,063 rows, 6,614 firms, fiscal year-ends from 2010 to 2025, Washington firms excluded (`final_data_full.dta` includes them).
- **ID:** `gvkey` + `fyear` is unique. `conm`, `tic`, `cusip` and `cik` are also available.
- **Time:** `fye` is the fiscal year-end date and `fyeyear` is its calendar year. `post` = 1 if the fiscal year ended on or after 1 Oct 2018. `mainwindow` = 1 for 2010–2019, the default sample.
- **Groups:** `ca` (treatment) vs. all other states. The coefficient on `ca_post` is the diff-in-diff estimate. `tx` is for robustness checks.
- **Outcome:** `lnmktcap` = ln(price × shares outstanding, $M).
- **Controls:** `lnassets`, `roa`, `leverage`, `multinational`, `age`, `nyse`, `tech`, `sic2` (for industry fixed effects).
- **Board (about 80% of rows):** `boardsize`, `women`, `zerowomen`. These are missing when `board_matched` = 0.

```stata
use "final_data.dta", clear
reg lnmktcap ca post ca_post if mainwindow == 1, vce(cluster gvkey)
```

**Rules:** never overwrite `final_data.dta` (only `01_build_data.do` creates it). Create new variables in your own do-file. Always use `vce(cluster gvkey)`. Missing (`.`) counts as +∞, so write `gen x = (age > 10) if age < .`.

## Pipeline

| Step | File | What it does |
|---|---|---|
| 1 | `code/01_build_data.do` | Builds the firm-year panel from Compustat + BoardEx → `final_data.dta` (WA excluded), `final_data_full.dta` (all states) |
| 2 | `code/02_table1_means.do` | Table 1a (before/after means, balance tests) and Table 1b (year-by-year means) → `output/*.csv` |
| 3 | `code/03_table1_excel.py` | Formats Table 1 into Excel → `output/Table1_means_balance.xlsx` |

Change the `cd` line at the top of each `.do` file to your project folder before running.

## Variables in `final_data.dta` / `final_data_full.dta`

### Identifiers and timing

| Variable | Description | Source / construction |
|---|---|---|
| `gvkey` | Compustat firm identifier | Compustat |
| `fyear` | Compustat fiscal year (FYs ending Jan–May are assigned to the previous year) | Compustat |
| `fyr` | Fiscal year-end month | Compustat |
| `apdedate` | Actual fiscal period end date | Compustat supplement |
| `fye` | Fiscal year-end date (`apdedate`; if missing, rebuilt from `fyear` and `fyr`) | Constructed |
| `fyeyear` | Calendar year of the fiscal year-end | `year(fye)` |
| `yr` | Calendar year of FYE, used as the BoardEx merge key | `year(fye)` |
| `post` | =1 if fiscal year ended on/after 1 Oct 2018 | `fye >= 01oct2018` |
| `mainwindow` | =1 if fiscal year ended Jan 2010 – Dec 2019 (pre-COVID main window) | `fye <= 31dec2019` |

### Treatment / comparison groups (HQ state from Compustat)

| Variable | Description |
|---|---|
| `state` | Headquarters state (Compustat, **current** HQ — firms that left CA after 2018 are coded by new state) |
| `ca` | =1 if HQ in California |
| `tx` | =1 if HQ in Texas |
| `wa` | =1 if HQ in Washington (always 0 in `final_data.dta`; WA passed its own law in 2020) |
| `ca_post` | California × Post (`ca * post`) |

### Outcomes and firm controls

| Variable | Description | Construction |
|---|---|---|
| `mktcap` | Market cap ($ millions) | `prcc_f * csho` |
| `lnmktcap` | ln(market cap) | `ln(mktcap)` if `mktcap > 0` |
| `lnassets` | ln(total assets) | `ln(at)` if `at > 0` |
| `roa` | Return on assets, winsorized 1/99% | `ni / at` |
| `leverage` | Total liabilities / assets, winsorized 1/99% | `lt / at` |
| `multinational` | =1 if reports nonzero foreign pretax income | `pifo != 0` (missing → 0) |
| `age` | Years since IPO (often missing) | `year(fye) - year(ipodate)`, negatives set missing |
| `nyse` | =1 if listed on NYSE | `exchg == 11` |
| `tech` | =1 if Information Technology sector | `gsector == "45"` (GICS) |
| `sic2` | 2-digit SIC industry | `substr(sic, 1, 2)` |

### Board composition (BoardEx, merged on `gvkey` × `yr`)

| Variable | Description | Construction |
|---|---|---|
| `boardsize` | Board size (number of directors) | BoardEx `numberdirectors` |
| `women` | Number of women on the board | `round(numberdirectors * (1 - genderratio))` — BoardEx `genderratio` is the **male** share |
| `zerowomen` | =1 if board has no women | `women == 0` |
| `board_matched` | =1 if firm-year matched to BoardEx | `_merge == 3` |

### Raw Compustat variables used

| Variable | Meaning |
|---|---|
| `prcc_f` | Fiscal-year-end closing price |
| `csho` | Shares outstanding (millions) |
| `at` | Total assets |
| `ni` | Net income |
| `lt` | Total liabilities |
| `pifo` | Pretax income – foreign |
| `ipodate` | IPO date |
| `exchg` | Exchange code (11 = NYSE, 12 = NYSE American/AMEX, 14 = Nasdaq) |
| `sic` | SIC industry code |
| `gsector` | GICS sector |
| `indfmt` | Industry format (kept `INDL`) |
| `loc` | Country of HQ (kept `USA`) |

### Raw BoardEx / link variables used

| Variable | Meaning |
|---|---|
| `companyid` | BoardEx company identifier |
| `annualreportdate` | Annual report date |
| `genderratio` | Share of directors who are **male** |
| `numberdirectors` | Number of directors |
| `hocountryname` | HQ country (kept `United States`) |
| `preferred`, `score` | Link quality flags in BoardEx–Compustat link (keep `preferred == 1`, best `score`) |
| `GVKEY` | Compustat ID in link file (renamed `gvkey`) |

## Merges (in `01_build_data.do`)

Counts below are from `logs/01_build_data.log`.

| # | Master | Using | Type & keys | Kept | Result |
|---|---|---|---|---|---|
| 1 | BoardEx board file (one row per `companyid` × `yr`) | `temp/link.dta` | `m:1` on `companyid` | `keep(match)` | 63,335 matched, 0 unmatched |
| 2 | Compustat main (`raw/compustat_annual_main.dta`) | `temp/csho.dta` | `1:1` on `gvkey` `fyear` | `keep(master match)` | 133,492 matched, 0 unmatched |
| 3 | Compustat firm-years | `temp/board.dta` | `m:1` on `gvkey` `yr` | `keep(master match)` | 49,020 matched (78%), 13,723 master-only; flagged by `board_matched` |

**1. BoardEx → Compustat link (`temp/link.dta`).** From `raw/link_boardex_crsp_compustat.dta`, keep `preferred == 1`. If a `companyid` still maps to several `gvkey`s, keep the best `score` (1 = strongest match), so each `companyid` has one `gvkey`. `GVKEY` is renamed `gvkey`.

**Board file (`temp/board.dta`).** From `raw/boardex_orgsummary.dta`, keep US-HQ companies (`hocountryname == "United States"`). The raw file has one row per director, and the board-level fields repeat on each row, so it is collapsed to one row per `companyid` × `annualreportdate`. `yr = year(annualreportdate)`. If a company files two annual reports in one calendar year, the later one is kept. After merging in `gvkey` (merge 1), duplicates on `gvkey` × `yr` are resolved the same way, by keeping the latest report.

**2. Shares-outstanding supplement (`temp/csho.dta`).** From `raw/compustat_annual_csho.dta` (`indfmt == "INDL"`), 11 `gvkey` × `fyear` duplicate pairs are dropped (these are fiscal-year changes). This file adds `csho`, `apdedate` and `gsector` to the main Compustat file. Exchange and SIC filters are applied after this merge.

**3. Board composition → firm-years.** The merge key `yr` is the calendar year of the fiscal year-end (`year(fye)`) on the Compustat side and the calendar year of `annualreportdate` on the BoardEx side. Unmatched firm-years are kept, with `boardsize`, `women` and `zerowomen` missing and `board_matched = 0`. Board-variable means therefore cover only matched firm-years.

**Caveats**
- `state` is the *current* HQ state in Compustat, not the historical one, so firms that moved out of California after 2018 are miscoded (to be fixed).
- The `yr` key assumes the BoardEx annual report date falls in the same calendar year as the Compustat fiscal year-end. A report dated early in the next year would be matched to the wrong year or not matched at all.
- Washington firms are dropped *after* all merges. `final_data_full.dta` keeps them for the WA-vs-TX placebo.

## Sample restrictions

US-HQ (`loc == "USA"`), `indfmt == "INDL"`, nonmissing `state`, listed on NYSE/AMEX/Nasdaq (`exchg` ∈ {11, 12, 14}), SIC 67xx (funds/trusts/shells) dropped, duplicate `gvkey`–`fyear` rows dropped, fiscal year-ends 1 Jan 2010 – 31 Dec 2025.

## Output table variables

**`output/table1a_means.csv`** — one row per `variable`:
`mean_ca_pre`, `sd_ca_pre` (California, before), `mean_oth_pre`, `sd_oth_pre` (other states, before), `mean_ca_post`, `sd_ca_post`, `mean_oth_post`, `sd_oth_post` (after).

**`output/balance_prelaw.csv`** — CA minus other states, pre-law, SE clustered by firm:
`diff`, `se`, `pvalue`, `nobs`.

**`output/balance_did.csv`** — diff-in-diff balance test, `x = b0 + b1·post + b2·ca + b3·ca_post`:
`did_b3`, `did_se`, `did_p`, `did_n`.

**`output/table1b_means_by_year.csv`** — one row per `fyeyear`; suffix `1` = California, `0` = other states (excl. WA):
`lnmktcap1/0`, `zerowomen1/0`, `women1/0`, `boardsize1/0`, `lnassets1/0`, `n_firmyears1/0`.
