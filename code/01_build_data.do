/*==============================================================================
  ECON 20 Project: California SB 826 (board gender quota) and firm value
  Program 1: BUILD THE ANALYSIS DATASET

  Design: two-state diff-in-diff (Card & Krueger style), California vs. Texas.
          Outcome = ln(market cap) at fiscal year-end. Regressors = ca, post, ca_post.

  Inputs  (raw/):
    compustat_annual_main.dta        Compustat Fundamentals Annual, WRDS query 11811258
    compustat_annual_csho.dta        Compustat supplement (csho, apdedate, gsector), query 11811313
    boardex_orgsummary.dta           BoardEx NA Organization Summary - Analytics, query 11811327
    link_boardex_crsp_compustat.dta  WRDS BoardEx-CRSP-Compustat link, query 11811331
  Output:
    final_data.dta        firm-year panel, CA and TX firms only, with a market cap,
                          fiscal years 2010-2025
                          (variable mainwindow = 1 for fiscal year-ends through Dec 2019)
    temp/balance_candidates.dta  same rows plus the variables considered for the
                          balance test, used by 01b_collinearity_tests.do
  File:   code/01_build_data.do   Author: Ansh
  Slow (several minutes); reads the raw WRDS extracts in raw/.
  Run:    do code/01_build_data.do, or set local build 1 in code/00_master.do.
          Overwrites final_data.dta: only run it when the data must be rebuilt.
  Log:    logs/01_build_data.log
==============================================================================*/

clear all
set more off
* --- Project folder (standard header, same in every script) -----------------
* Uses global PROJ if set (00_master.do sets it); otherwise the current folder
* if it has final_data.dta; otherwise the first teammate folder below that has
* it. Nothing to edit: if none match, cd to the project folder first, or set
*   global PROJ "C:/path/to/project"
if `"$PROJ"' != "" cd `"$PROJ"'
capture confirm file "final_data.dta"
if _rc & `"$PROJ"' == "" {
    foreach d in "~/Desktop/Dartmouth Classes/Economics/ECON20/project" ///
                 "C:/Users/shinz/OneDrive/Desktop/Econ20 FinalProject" ///
                 "/Users/joseohui/Desktop/UIC/Dartmouth/Fall/Econometrics/JESAS/project" ///
                 "C:/Econ 20/proj" {
        capture confirm file "`d'/final_data.dta"
        if !_rc {
            cd "`d'"
            continue, break
        }
    }
}
capture confirm file "final_data.dta"
if _rc {
    di as error "final_data.dta not found. cd to the project folder, or run"
    di as error `"  global PROJ "C:/path/to/project""'
    di as error "and then run this do-file again."
    exit 601
}
capture mkdir "logs"
capture mkdir "output"
capture mkdir "output/figures"
* ---------------------------------------------------------------------------

capture log close
log using "logs/01_build_data.log", replace text

*-------------------------------------------------------------------------------
* STEP 1. BoardEx: one row per company per report month with board size and # of women
*-------------------------------------------------------------------------------

* 1a. Link table: keep the "preferred" BoardEx-to-Compustat match.
*     If a BoardEx company still maps to more than one gvkey, keep the best score
*     (score 1 = strongest match). gvkey breaks ties so the result is reproducible.
use "raw/link_boardex_crsp_compustat.dta", clear
keep if preferred == 1
rename GVKEY gvkey
sort companyid score gvkey
by companyid: keep if _n == 1
keep companyid gvkey score
save "temp/link.dta", replace

* 1b. Board data. Each row is one director; the board-level variables
*     (genderratio, numberdirectors) repeat on every director row.
*     annualreportdate is the first day of the fiscal year-end month.
use "raw/boardex_orgsummary.dta", clear
keep if hocountryname == "United States"
keep companyid annualreportdate genderratio numberdirectors nationalitymix
duplicates drop companyid annualreportdate, force   // one row per board per annual report

gen ym = mofd(annualreportdate)
format ym %tm

merge m:1 companyid using "temp/link.dta", keep(match) nogen
* if two BoardEx companies link to one gvkey in a month, keep the better link
sort gvkey ym score companyid
by gvkey ym: keep if _n == 1

* BoardEx genderratio = share of directors who are MALE
gen women     = round(numberdirectors * (1 - genderratio))
gen zerowomen = (women == 0) if women < .
rename numberdirectors boardsize
keep gvkey ym boardsize women zerowomen nationalitymix
label var boardsize "Board size (number of directors)"
label var women     "Number of women on the board"
label var zerowomen "=1 if board has no women"
label var nationalitymix "BoardEx board nationality mix (optional control, not in balance test)"
save "temp/board.dta", replace

*-------------------------------------------------------------------------------
* STEP 2. Compustat: shares outstanding supplement
*-------------------------------------------------------------------------------
use "raw/compustat_annual_csho.dta", clear
keep if indfmt == "INDL"
duplicates tag gvkey fyear, gen(dup)
drop if dup > 0                       // 11 firm-years with a fiscal-year change
keep gvkey fyear csho apdedate gsector
save "temp/csho.dta", replace

*-------------------------------------------------------------------------------
* STEP 3. Compustat main file and sample restrictions
*   NOTE: exchg and sic are CURRENT values, so a firm that was listed in 2015 and
*   delisted later (e.g. First Republic, SVB) is dropped from every year.
*-------------------------------------------------------------------------------
use "raw/compustat_annual_main.dta", clear

keep if indfmt == "INDL"              // drop the duplicate financial-services format
keep if loc == "USA"                  // headquartered in the US
drop if state == ""
duplicates tag gvkey fyear, gen(dup)
drop if dup > 0
drop dup add2 add4 prch_f prcl_f prcl_c   // variables selected by mistake

merge 1:1 gvkey fyear using "temp/csho.dta", keep(master match) nogen

* listed on NYSE (11), NYSE American/AMEX (12) or Nasdaq (14)
keep if inlist(exchg, 11, 12, 14)
* drop funds, trusts and shell companies (SIC 67xx)
drop if substr(sic, 1, 2) == "67"
* Mechanics Bancorp is coded Nasdaq from its 2025 merger, but traded over the
* counter before that at prices of $10,800-$31,950 a share
drop if gvkey == "018948"

*-------------------------------------------------------------------------------
* STEP 4. Treatment state: headquarters on the day SB 826 was signed
*   Compustat 'state' is the CURRENT headquarters state, not a history. SB 826
*   applied to firms based in California when it was signed (30 Sep 2018), so
*   firms that left CA afterwards are treated firms and are coded back to CA.
*   All ten moves below were announced after the law and verified from press
*   releases, SEC filings or news reports (dates = when the move took effect).
*   The list covers large, well-known moves only. Smaller firms that left CA
*   after 2018 remain coded by their current state. mover = 1 flags the ten so
*   they can be dropped in a robustness check.
*-------------------------------------------------------------------------------
gen state_2018 = state
gen mover = 0
foreach g in "002991" "007171" "012142" "013988" "026156" ///
             "147988" "162876" "184392" "184996" "260774" {
    replace state_2018 = "CA" if gvkey == "`g'"
    replace mover      = 1    if gvkey == "`g'"
}
*   002991  Chevron                      San Ramon -> Houston,    announced Aug 2024
*   007171  McKesson                     San Francisco -> Irving, 1 Apr 2019
*   012142  Oracle                       Redwood City -> Austin,  Dec 2020
*   013988  Charles Schwab               San Francisco -> Westlake, 1 Jan 2021
*   026156  Hewlett Packard Enterprise   San Jose -> Spring (Houston), announced Dec 2020, campus 2022
*   147988  AECOM                        Los Angeles -> Dallas,   1 Oct 2021
*   162876  Core-Mark                    S. San Francisco -> Westlake, 18 May 2019
*   184392  Green Dot                    Pasadena -> Austin, 2021 (now Provo, UT)
*   184996  Tesla                        Palo Alto -> Austin,     1 Dec 2021
*   260774  CBRE                         Los Angeles -> Dallas,   Oct 2020
label var state_2018 "Headquarters state on 30 Sep 2018"
label var mover      "=1 if HQ left California after SB 826 (10 firms, coded CA)"

* Two-state design: California (treated) vs. Texas (comparison)
keep if inlist(state_2018, "CA", "TX")

*-------------------------------------------------------------------------------
* STEP 5. Fiscal year-end date and the treatment timing
*-------------------------------------------------------------------------------
* apdedate = actual fiscal period end date. If missing (about 2%), rebuild it
* from fyear and fyr: Compustat assigns fiscal years ending Jan-May to the
* previous year.
gen fye_yr  = cond(fyr >= 6, fyear, fyear + 1)
gen fye_alt = dofm(ym(fye_yr, fyr) + 1) - 1          // last day of month fyr
gen fye     = apdedate
replace fye = fye_alt if fye == .
format fye %td
drop fye_yr fye_alt
label var fye "Fiscal year-end date"

* The raw data start at fiscal year 2010, so fiscal years ending Jan-May 2010
* (fiscal 2009) are not available. The first year-end in the data is June 2010.
keep if fye >= td(01jan2010) & fye <= td(31dec2025)

* POST = fiscal year ended on or after 1 Oct 2018 (SB 826 signed 30 Sep 2018).
* Market value is measured at fiscal year-end, so for these firm-years the
* price already reflects the law.
gen post = (fye >= td(01oct2018)) if fye < .
label var post "=1 if fiscal year ended on/after 1 Oct 2018"

gen ca      = (state_2018 == "CA")
gen ca_post = ca * post
label var ca      "=1 if HQ in California on 30 Sep 2018 (0 = Texas)"
label var ca_post "California x Post"

*-------------------------------------------------------------------------------
* STEP 6. Outcome and control variables
*-------------------------------------------------------------------------------
* Outcome: market cap in $ millions = fiscal-year-end price x shares outstanding
* (millions). Unlike the share price, it is not changed by stock splits.
* Keep only firm-years with a market cap, since the rest (mostly years before
* the IPO) are not traded firms.
gen mktcap = prcc_f * csho
drop if mktcap == . | mktcap <= 0
gen lnmktcap = ln(mktcap)
label var mktcap   "Market cap ($ millions)"
label var lnmktcap "ln(market cap)"

* Drop firm-years with less than $1 million of total assets. Ratios to assets
* are meaningless for these (one firm-year had $54,000 of assets and a $21
* million loss, so net income / assets = -397). They are 72 rows, mostly
* shell-sized firms. We drop them rather than winsorize so that every
* remaining value is the firm's actual ratio.
drop if at < 1

gen lnassets = ln(at)
gen roa      = ni / at
gen leverage = lt / at
label var lnassets "ln(total assets)"
label var roa      "Net income / assets"
label var leverage "Total liabilities / assets"

* Multinational: reports nonzero foreign pretax income. Compustat leaves
* pifo blank for 48% of firm-years. We follow the usual shortcut of treating
* blank as no foreign income, and keep pifo_missing so the balance test can
* show how often this imputation happens in each state.
gen multinational = (pifo != 0 & pifo < .)
gen pifo_missing  = (pifo == .)
label var multinational "=1 if reports foreign pretax income (blank pifo counted as 0)"
label var pifo_missing  "=1 if foreign pretax income (pifo) is blank in Compustat"

* Firm age since IPO (Compustat ipodate). Missing mostly for old, established
* firms (e.g. AT&T, Intel, Disney), so age_missing is kept for the balance test.
gen age = year(fye) - year(ipodate)
replace age = . if age < 0
gen age_missing = (age == .)
label var age         "Years since IPO"
label var age_missing "=1 if age is missing"

gen nyse = (exchg == 11)
gen tech = (gsector == "45") if gsector != ""
label var nyse "=1 if listed on NYSE"
label var tech "=1 if Information Technology sector (GICS 45)"

gen sic2 = substr(sic, 1, 2)
label var sic2 "2-digit SIC industry"

* Industries that differ most between the two states. energy is in the
* balance test (Texas is a quarter oil and gas); pharma is kept as a
* descriptive flag only.
gen energy = inlist(sic2, "13", "29")
gen pharma = inlist(sic, "2833", "2834", "2835", "2836")
label var energy "=1 if oil and gas or petroleum refining (SIC 13, 29)"
label var pharma "=1 if pharmaceuticals or biotech (SIC 2833-2836)"

* Other candidates for the balance test, tested in 01b_collinearity_tests.do
gen lnsale = ln(sale) if sale > 0
gen lnemp  = ln(emp) if emp > 0
gen rd     = xrd / at if at > 0
gen fin    = (substr(sic, 1, 1) == "6")
label var lnsale "ln(sales)"
label var lnemp  "ln(employees)"
label var rd     "R&D expense / assets"
label var fin    "=1 if financial or real estate firm (SIC 6xxx)"

*-------------------------------------------------------------------------------
* STEP 7. Merge board composition (match on gvkey and month of FYE)
*-------------------------------------------------------------------------------
gen ym = mofd(fye)
merge m:1 gvkey ym using "temp/board.dta", keep(master match)
gen board_matched = (_merge == 3)
drop _merge ym

*-------------------------------------------------------------------------------
* STEP 8. Time windows, checks and save
*-------------------------------------------------------------------------------
* Calendar year of the fiscal year-end, used for year-by-year tables/graphs
gen fyeyear = year(fye)
label var fyeyear "Calendar year of fiscal year-end"

* Main window: fiscal year-ends through Dec 2019 (before COVID)
gen mainwindow = (fye <= td(31dec2019))
label var mainwindow "=1 if fiscal year ended Jun 2010 - Dec 2019"

isid gvkey fyear
assert inlist(state_2018, "CA", "TX")
assert ca_post == (ca == 1 & post == 1)
assert mktcap > 0 & mktcap < .

* Candidate variables for the collinearity tests
preserve
keep gvkey fyear ca post mainwindow lnmktcap lnassets lnsale lnemp roa ///
     leverage multinational age nyse tech energy pharma fin rd boardsize women zerowomen
compress
save "temp/balance_candidates.dta", replace
restore

* Final variable list. Balance test: lnassets roa leverage multinational age
* nyse tech energy boardsize (see 01b_collinearity_tests.do), with
* age_missing and pifo_missing reported alongside.
keep gvkey fyear conm tic fye fyeyear state_2018 mover ca post ca_post mainwindow ///
     mktcap lnmktcap ///
     lnassets roa leverage multinational pifo_missing age age_missing nyse tech energy ///
     boardsize pharma women zerowomen nationalitymix board_matched sic2
order gvkey fyear conm tic fye fyeyear state_2018 mover ca post ca_post mainwindow ///
      mktcap lnmktcap ///
      lnassets roa leverage multinational pifo_missing age age_missing nyse tech energy ///
      boardsize pharma women zerowomen nationalitymix board_matched sic2

compress
save "final_data.dta", replace

describe
summarize

log close
