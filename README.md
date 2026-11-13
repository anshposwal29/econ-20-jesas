# econ-20-jesas

ECON 20 project: California SB 826 (board gender quota, signed 30 Sep 2018) and firm value. Two-state difference-in-differences, California vs. Texas, in the style of Card & Krueger.

## TL;DR: `final_data.dta`

- **One row = one firm-year.** 14,950 rows, 1,866 firms, fiscal year-ends from June 2010 to December 2025. California: 8,790 rows, 1,172 firms. Texas: 6,160 rows, 694 firms. Every row has a market cap and at least $1 million of assets.
- **ID:** `gvkey` + `fyear` is unique. `conm` and `tic` are also available.
- **Time:** `fye` is the fiscal year-end date and `fyeyear` is its calendar year. `post` = 1 if the fiscal year ended on or after 1 Oct 2018. `mainwindow` = 1 for year-ends through 2019 (8,762 rows, 1,408 firms), the default sample.
- **Regressors:** `ca` (=1 California, =0 Texas), `post`, and `ca_post`. The coefficient on `ca_post` is the diff-in-diff estimate.
- **Outcome:** `lnmktcap` = ln(price × shares outstanding, $M) at fiscal year-end. Stock splits do not affect it.
- **Balance test variables (9):** `lnassets`, `roa`, `leverage`, `multinational`, `age`, `nyse`, `tech`, `energy`, `boardsize`. No pair has |correlation| ≥ 0.70 and every VIF is below 5 (`output/collinearity_tests.xlsx`). `age_missing` and `pifo_missing` are reported alongside `age` and `multinational`.
- **Movers:** `mover` = 1 for the 10 firms that left California after the law (147 rows). They are coded as California; drop them for a robustness check.
- **Board (85% of rows):** `boardsize`, `women`, `zerowomen`. These are missing when `board_matched` = 0. `women` and `zerowomen` are outcomes of the law, not balance variables.
- **Age:** missing for 36% of main-window firm-years (California 31%, Texas 43% pre-law). It is a firm-level gap: 453 of 1,408 main-window firms have no IPO date in Compustat, mostly older firms. `age_missing` flags these rows.

```stata
use "final_data.dta", clear
reg lnmktcap ca post ca_post if mainwindow == 1, vce(cluster gvkey)
```

**Rules:** never overwrite `final_data.dta` (only `01_build_data.do` creates it). Create new variables in your own do-file. Always use `vce(cluster gvkey)`. Missing (`.`) counts as +∞, so write `gen x = (age > 10) if age < .`.

## Pipeline

| Step | File | What it does |
|---|---|---|
| 1 | `code/01_build_data.do` | Builds the CA/TX firm-year panel from Compustat + BoardEx → `final_data.dta` |
| 1b | `code/01b_collinearity_tests.do` | Tests which variables enter the balance test, for the appendix → `output/collinearity_tests.xlsx`. Run after step 1 |
| 2 | `code/02_balance_test.do` | Table 1 means (`outsum`) and balance test (`outreg2`) → `output/table1_means.csv`, `output/balance_prelaw.xml`, `output/balance_did.xml`, and all four columns in `output/table1_balance.csv` |
| 3 | `code/03_table1_format.py` | Formats `output/table1_balance.csv` into the paper's Table 1 (Dynarski layout: 4 means columns, pre-law difference, diff-in-diff) → `output/Table1_means_balance.xlsx`. Run `python3 code/03_table1_format.py` from the project folder |
| 4 | `code/did_tests.do` (Sophia) | **Main results.** Two-period DiD, fiscal year-end 2018 (pre) vs 2019 (post): Table 1 main DiD (with and without controls, raw and detrended), Table 2 placebo (firms with a woman on the board in 2018), Table 3 first stage / reduced form / IV, Table 4 pre-trends → `did_table1`–`did_table4` (`.txt`/`.xml`) |
| 5 | `code/did_graphs.do` (Seohee) | Figures for Tables 1–4 → `output/figures/fig_table*.png`. Every coefficient is the same regression as a table column, in the same units. Also writes `output/figures/figure_numbers.csv` (every plotted number) |
| 6 | `code/paneldata_outreg2.do` (Sophia) | Panel version with firm and year FE, all years: main DiD, pre-trends (2017 = reference), IV → `table2_main`, `table3_pretrend`, `table4_iv` |
| check | `code/run_check.sh` | Re-runs steps 4 and 5 and runs `code/check_figures_vs_tables.py`, which compares every number in the figures with the tables (coefficients, SEs, N, F-stats, pre-trend test). Run `bash code/run_check.sh` before handing anything in; it must end with `0 problem(s)` |
| archive | `code/archive/` | Superseded or exploratory scripts kept for reference: the all-states Table 1 scripts, Eloise's policy-year event studies and first stage, and the problem-set template. Not part of the paper |

**Running the code.** `did_graphs.do` finds the project folder by itself on Ansh's and Sophia's machines; anyone else should `cd` to the project folder first. Sophia's `.do` files keep her own `cd` line, so change it on your machine (or use `run_check.sh`, which handles it without editing her file). `final_data_full.dta` is left over from the earlier all-states design and is no longer built or updated.

**Two things the group still has to decide**
- **Table numbers clash.** `did_tests.do` makes Tables 1–4 and `paneldata_outreg2.do` makes Tables 2–4, with different content (e.g. "Table 3" is the IV in one and pre-trends in the other). The figures follow `did_tests.do`.
- **`paneldata_outreg2.do`, `table4_iv` columns 1–2.** The first stages are labeled "Year FE: Yes" but leave out `fyeardum*`, and use `fyeyear < 2020` while the IV columns use all years. With year FE the first-stage F is about 1.8 (one woman) and 6.1 (share), not 106.8 and 253.6. Not changed here, since that is Sophia's call.

## Variables in `final_data.dta`

### Identifiers and timing

| Variable | Description | Source / construction |
|---|---|---|
| `gvkey` | Compustat firm identifier | Compustat |
| `fyear` | Compustat fiscal year (FYs ending Jan–May are assigned to the previous year) | Compustat |
| `fye` | Fiscal year-end date (`apdedate`; if missing, rebuilt from `fyear` and `fyr`) | Constructed |
| `fyeyear` | Calendar year of the fiscal year-end | `year(fye)` |
| `post` | =1 if fiscal year ended on/after 1 Oct 2018 | `fye >= 01oct2018` |
| `mainwindow` | =1 if fiscal year ended by Dec 2019 (pre-COVID main window) | `fye <= 31dec2019` |

### Treatment

| Variable | Description |
|---|---|
| `state_2018` | Headquarters state on 30 Sep 2018: Compustat's current `state`, corrected for 10 large firms that left California after the law (list and dates in `01_build_data.do`, Step 4) |
| `mover` | =1 for those 10 firms (Chevron, McKesson, Oracle, Schwab, HPE, AECOM, Core-Mark, Green Dot, Tesla, CBRE) |
| `ca` | =1 if `state_2018` is California, =0 if Texas. Fixed for each firm |
| `ca_post` | California × Post (`ca * post`) |

### Outcomes and firm controls

| Variable | Description | Construction |
|---|---|---|
| `mktcap` | Market cap ($ millions) | `prcc_f * csho` |
| `lnmktcap` | ln(market cap), the main outcome | `ln(mktcap)` |
| `lnassets` | ln(total assets) | `ln(at)`; firm-years with `at < 1` ($1M) are dropped |
| `roa` | Return on assets, not winsorized | `ni / at` |
| `leverage` | Total liabilities / assets, not winsorized | `lt / at` |
| `multinational` | =1 if reports nonzero foreign pretax income | `pifo != 0` (blank → 0; `pifo` is blank for 48% of firm-years) |
| `pifo_missing` | =1 if `pifo` is blank in Compustat (CA 41%, TX 58%) | `pifo == .` |
| `age` | Years since IPO (often missing) | `year(fye) - year(ipodate)`, negatives set missing. `ipodate` can be a re-listing date |
| `age_missing` | =1 if `age` is missing | `age == .` |
| `nyse` | =1 if listed on NYSE | `exchg == 11` |
| `tech` | =1 if Information Technology sector, missing if no sector | `gsector == "45"` (GICS) |
| `energy` | =1 if oil and gas or petroleum refining; balance variable | SIC 13, 29 |
| `pharma` | =1 if pharmaceuticals or biotech; descriptive flag only, not in the balance test | SIC 2833–2836 |
| `sic2` | 2-digit SIC industry | `substr(sic, 1, 2)` |

### Variables tested and left out of the balance test

Tested on pre-law, main-window firm-years in `code/01b_collinearity_tests.do`. Rule: drop at |correlation| ≥ 0.70 or VIF ≥ 5.

| Variable | Why it was left out |
|---|---|
| `lnmktcap` | It is the outcome (correlation of 0.86 with `lnassets`) |
| `lnsale` | Correlation of 0.87 with `lnassets`; VIF 8.0 |
| `lnemp` | Correlation of 0.78 with `lnassets` and 0.89 with `lnsale` |
| `pharma` | Passes both tests (|r| ≤ 0.32), but left out to keep the industry rows to the two that matter most (`tech`, `energy`); reported in Table 1 |
| `women`, `zerowomen` | Correlation of −0.79 with each other, and both are outcomes of the law |
| `rd` | Not collinear, but missing for 65% of Texas and 26% of California firm-years |
| `fin` | Not collinear, but similar in both states (9.6% vs 11.9% of rows), so it adds little |

### Board composition (BoardEx, merged on `gvkey` × month of fiscal year-end)

| Variable | Description | Construction |
|---|---|---|
| `boardsize` | Board size (number of directors) | BoardEx `numberdirectors` |
| `women` | Number of women on the board | `round(numberdirectors * (1 - genderratio))` — BoardEx `genderratio` is the **male** share |
| `zerowomen` | =1 if board has no women | `women == 0` |
| `nationalitymix` | BoardEx board nationality mix. Optional control, not in the balance test; BoardEx definition still to confirm | `nationalitymix` |
| `board_matched` | =1 if firm-year matched to BoardEx | `_merge == 3` |

### Raw Compustat variables used (in the build; most are not kept in `final_data.dta`)

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

### Raw BoardEx / link variables used

| Variable | Meaning |
|---|---|
| `companyid` | BoardEx company identifier |
| `annualreportdate` | Annual report date (first day of the fiscal year-end month) |
| `genderratio` | Share of directors who are **male** |
| `numberdirectors` | Number of directors |
| `hocountryname` | HQ country (kept `United States`) |
| `preferred`, `score` | Link quality flags in BoardEx–Compustat link (keep `preferred == 1`, best `score`) |
| `GVKEY` | Compustat ID in link file (renamed `gvkey`) |

## Merges (in `01_build_data.do`)

Counts below are from `logs/01_build_data.log`.

| # | Master | Using | Type & keys | Kept | Result |
|---|---|---|---|---|---|
| 1 | BoardEx board file (one row per `companyid` × report) | `temp/link.dta` | `m:1` on `companyid` | `keep(match)` | 63,756 matched, 0 unmatched |
| 2 | Compustat main (`raw/compustat_annual_main.dta`) | `temp/csho.dta` | `1:1` on `gvkey` `fyear` | `keep(master match)` | 133,492 matched, 0 unmatched |
| 3 | CA/TX firm-years with a market cap | `temp/board.dta` | `m:1` on `gvkey` `ym` | `keep(master match)` | 12,682 matched (85%), 2,268 master-only; flagged by `board_matched` |

**1. BoardEx → Compustat link (`temp/link.dta`).** From `raw/link_boardex_crsp_compustat.dta`, keep `preferred == 1`. If a `companyid` still maps to several `gvkey`s, keep the best `score` (1 = strongest match), then the lowest `gvkey`, so each `companyid` has one `gvkey` and the result is reproducible.

**Board file (`temp/board.dta`).** From `raw/boardex_orgsummary.dta`, keep US-HQ companies (`hocountryname == "United States"`). The raw file has one row per director, and the board-level fields repeat on each row, so it is collapsed to one row per `companyid` × `annualreportdate`. If two BoardEx companies link to one `gvkey` in the same month, the better link is kept.

**2. Shares-outstanding supplement (`temp/csho.dta`).** From `raw/compustat_annual_csho.dta` (`indfmt == "INDL"`), 11 `gvkey` × `fyear` duplicate pairs are dropped (these are fiscal-year changes). This file adds `csho`, `apdedate` and `gsector` to the main Compustat file.

**3. Board composition → firm-years.** The merge key `ym` is the month of the fiscal year-end on the Compustat side and the month of `annualreportdate` on the BoardEx side. Unmatched firm-years are kept, with `boardsize`, `women` and `zerowomen` missing and `board_matched = 0`.

**Caveats**
- `state_2018` corrects only large known moves. Smaller firms that left California after 2018 are still coded by their current state.
- `exchg` and `sic` are current values, so firms that were listed during the sample and later delisted (e.g. First Republic, SVB) are dropped from every year.
- Board matching is lower for small firms, and 2025 is only 22% matched, so avoid 2025 for board outcomes.
- Ratios are not winsorized. The $1M asset floor removes the worst cases, but a few extreme values remain (full-sample `roa` ranges from −56 to 15; `leverage` up to 23). Check sensitivity to a higher floor (line 186 of `01_build_data.do`).
- Some firms have two fiscal year-ends in one calendar year after a fiscal-year change, so `gvkey` × `fyeyear` is not always unique.

## Sample restrictions

US-HQ (`loc == "USA"`), `indfmt == "INDL"`, nonmissing `state`, currently listed on NYSE/AMEX/Nasdaq (`exchg` ∈ {11, 12, 14}), SIC 67xx (funds/trusts/shells) dropped, Mechanics Bancorp dropped, duplicate `gvkey`–`fyear` rows dropped, `state_2018` ∈ {CA, TX}, fiscal year-ends through 31 Dec 2025, market cap present and positive, total assets ≥ $1 million (72 rows dropped). The raw data start at fiscal year 2010, so fiscal years ending January–May 2010 are not available.
