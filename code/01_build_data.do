/*==============================================================================
  ECON 20 Project: California SB 826 (board gender quota) and firm value
  Program 1 of 2: BUILD THE ANALYSIS DATASET

  Inputs  (raw/):
    compustat_annual_main.dta        Compustat Fundamentals Annual, WRDS query 11811258
    compustat_annual_csho.dta        Compustat supplement (csho, apdedate, gsector), query 11811313
    boardex_orgsummary.dta           BoardEx NA Organization Summary - Analytics, query 11811327
    link_boardex_crsp_compustat.dta  WRDS BoardEx-CRSP-Compustat link, query 11811331
  Outputs:
    final_data.dta        firm-year panel, fiscal year-ends Jan 2010 - Dec 2025, WASHINGTON EXCLUDED
                          (variable mainwindow = 1 for fiscal year-ends Jan 2010 - Dec 2019)
    final_data_full.dta   same years, all states including Washington
==============================================================================*/

clear all
set more off
* --- CHANGE THIS LINE to the project folder on your computer ---
cd "~/Desktop/Dartmouth Classes/Economics/ECON20/project"

capture log close
log using "logs/01_build_data.log", replace text

*-------------------------------------------------------------------------------
* STEP 1. BoardEx: one row per company per year with board size and # of women
*-------------------------------------------------------------------------------

* 1a. Link table: keep the "preferred" BoardEx-to-Compustat match.
*     If a BoardEx company still maps to more than one gvkey, keep the best score
*     (score 1 = strongest match).
use "raw/link_boardex_crsp_compustat.dta", clear
keep if preferred == 1
sort companyid score
by companyid: keep if _n == 1
rename GVKEY gvkey
keep companyid gvkey
save "temp/link.dta", replace

* 1b. Board data. Each row is one director; the board-level variables
*     (genderratio, numberdirectors) repeat on every director row.
use "raw/boardex_orgsummary.dta", clear
keep if hocountryname == "United States"
keep companyid annualreportdate genderratio numberdirectors
duplicates drop companyid annualreportdate, force   // one row per board per annual report

gen yr = year(annualreportdate)
* if a company files two annual reports in one calendar year, keep the later one
sort companyid yr annualreportdate
by companyid yr: keep if _n == _N

merge m:1 companyid using "temp/link.dta", keep(match) nogen
sort gvkey yr annualreportdate
by gvkey yr: keep if _n == _N

* BoardEx genderratio = share of directors who are MALE
gen women     = round(numberdirectors * (1 - genderratio))
gen zerowomen = (women == 0) if women < .
rename numberdirectors boardsize
keep gvkey yr boardsize women zerowomen
label var boardsize "Board size (number of directors)"
label var women     "Number of women on the board"
label var zerowomen "=1 if board has no women"
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

*-------------------------------------------------------------------------------
* STEP 4. Fiscal year-end date and the treatment timing
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

* POST = fiscal year ended on or after 1 Oct 2018 (SB 826 signed 30 Sep 2018).
* Market value is measured at fiscal year-end, so for these firm-years the
* price already reflects the law.
gen post = (fye >= td(01oct2018)) if fye < .
label var post "=1 if fiscal year ended on/after 1 Oct 2018"

*-------------------------------------------------------------------------------
* STEP 5. Treatment and comparison groups (HQ state from Compustat)
*   NOTE: Compustat 'state' is the CURRENT headquarters state. Firms that left
*   California after 2018 are coded by their new state. To be fixed later.
*-------------------------------------------------------------------------------
gen ca    = (state == "CA")
gen tx    = (state == "TX")
gen wa    = (state == "WA")
gen ca_post = ca * post
label var ca      "=1 if HQ in California"
label var tx      "=1 if HQ in Texas"
label var wa      "=1 if HQ in Washington"
label var ca_post "California x Post"

*-------------------------------------------------------------------------------
* STEP 6. Outcome and control variables
*-------------------------------------------------------------------------------
* Market cap in $ millions = fiscal-year-end price x shares outstanding (millions)
gen mktcap   = prcc_f * csho
gen lnmktcap = ln(mktcap) if mktcap > 0
label var mktcap   "Market cap ($ millions)"
label var lnmktcap "ln(market cap)"

gen lnassets = ln(at) if at > 0
gen roa      = ni / at if at > 0
gen leverage = lt / at if at > 0
label var lnassets "ln(total assets)"
label var roa      "Net income / assets"
label var leverage "Total liabilities / assets"

* Multinational: reports nonzero foreign pretax income (missing treated as 0)
gen multinational = (pifo != 0 & pifo < .)
label var multinational "=1 if reports foreign pretax income"

* Firm age since IPO (Compustat ipodate; often missing)
gen age = year(fye) - year(ipodate)
replace age = . if age < 0
label var age "Years since IPO"

gen nyse = (exchg == 11)
gen tech = (gsector == "45")
label var nyse "=1 if listed on NYSE"
label var tech "=1 if Information Technology sector (GICS 45)"

gen sic2 = substr(sic, 1, 2)
label var sic2 "2-digit SIC industry"

* Winsorize ratios at the 1st/99th percentile (a few firms have tiny assets)
foreach v in roa leverage {
    quietly _pctile `v', p(1 99)
    replace `v' = r(r1) if `v' < r(r1)
    replace `v' = r(r2) if `v' > r(r2) & `v' < .
}

*-------------------------------------------------------------------------------
* STEP 7. Merge board composition (match on gvkey and calendar year of FYE)
*-------------------------------------------------------------------------------
gen yr = year(fye)
merge m:1 gvkey yr using "temp/board.dta", keep(master match)
gen board_matched = (_merge == 3)
drop _merge

*-------------------------------------------------------------------------------
* STEP 8. Time windows and save
*-------------------------------------------------------------------------------
keep if fye >= td(01jan2010) & fye <= td(31dec2025)

* Calendar year of the fiscal year-end, used for year-by-year tables/graphs
gen fyeyear = year(fye)
label var fyeyear "Calendar year of fiscal year-end"

* Main window: fiscal year-ends Jan 2010 - Dec 2019 (before COVID)
gen mainwindow = (fye <= td(31dec2019))
label var mainwindow "=1 if fiscal year ended Jan 2010 - Dec 2019"

compress
* Full file, ALL states incl. Washington (needed later for WA-vs-TX placebo)
save "final_data_full.dta", replace

* Main analysis file: drop Washington firms (WA passed its own board-diversity
* law in 2020, so WA is not a clean comparison state). All years 2010-2025 kept.
drop if wa == 1
save "final_data.dta", replace

describe
summarize

log close
