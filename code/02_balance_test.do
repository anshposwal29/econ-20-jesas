/*==============================================================================
  ECON 20 Project: California SB 826 (board gender quota) and firm value
  Program 2: TABLE 1 (MEANS) AND BALANCE TEST

  Sample: main window (fiscal year-ends Jun 2010 - Dec 2019), California vs Texas.

  Columns:
    (1) California, before the law: mean [SD]           outsum
    (2) Texas, before the law:      mean [SD]           outsum
    (3) CA - TX difference, before the law: b, (SE)     reg x ca if post == 0
    (4) Diff-in-diff in the control: b3, (SE)           reg x ca post ca_post
  Standard errors in (3) and (4) clustered by firm (gvkey).

  Input:  final_data.dta (from 01_build_data.do)
  Outputs (output/):
    table1_means.csv        columns (1)-(2), from outsum
    balance_prelaw.xml      column (3), from outreg2, one regression per variable (opens in Excel)
    balance_did.xml         column (4), from outreg2, one regression per variable (opens in Excel)
    table1_balance.csv      all four columns in one file (built with postfile)
==============================================================================*/

clear all
set more off
* --- CHANGE THIS LINE to the project folder on your computer ---
cd "~/Desktop/Dartmouth Classes/Economics/ECON20/project"

capture log close
log using "logs/02_balance_test.log", replace text

use "final_data.dta", clear
keep if mainwindow == 1

* Variables in the balance test (see 01b_collinearity_tests.do for the choice).
* age_missing and pifo_missing show how often age and foreign income are blank.
local balance lnassets roa leverage multinational pifo_missing age age_missing ///
              nyse tech energy boardsize
* Shown in the means columns only: the outcome and the board outcomes
local meansonly lnmktcap women zerowomen pharma

* Short labels for the table (outsum keys on the label and cannot take commas)
label var lnmktcap      "Ln(Market Cap)"
label var women         "Women on Board"
label var zerowomen     "No Women on Board"
label var pharma        "Pharma or Biotech"
label var lnassets      "Ln(Total Assets)"
label var roa           "Net Income / Assets"
label var leverage      "Liabilities / Assets"
label var multinational "Multinational"
label var pifo_missing  "Foreign Income Not Reported"
label var age           "Years Since IPO"
label var age_missing   "IPO Date Missing"
label var nyse          "Listed on NYSE"
label var tech          "Tech Sector"
label var energy        "Oil and Gas"
label var boardsize     "Board Size"

*-------------------------------------------------------------------------------
* Columns (1)-(2): means and SDs before the law, by state (outsum)
*-------------------------------------------------------------------------------
outsum `meansonly' `balance' using "output/table1_means.csv" ///
    if post == 0 & ca == 1, replace comma bracket ctitle("California")
outsum `meansonly' `balance' using "output/table1_means.csv" ///
    if post == 0 & ca == 0, append comma bracket ctitle("Texas")

*-------------------------------------------------------------------------------
* Column (3): CA - TX difference before the law (outreg2)
*-------------------------------------------------------------------------------
local app replace
foreach v of local balance {
    reg `v' ca if post == 0, vce(cluster gvkey)
    outreg2 ca using "output/balance_prelaw", `app' excel noaster ///
        ctitle("`v'") label
    local app append
}

*-------------------------------------------------------------------------------
* Column (4): diff-in-diff in each control (outreg2)
*-------------------------------------------------------------------------------
local app replace
foreach v of local balance {
    reg `v' ca post ca_post, vce(cluster gvkey)
    outreg2 ca_post using "output/balance_did", `app' excel noaster ///
        ctitle("`v'") label
    local app append
}

*-------------------------------------------------------------------------------
* One combined file: variable, CA mean, CA sd, TX mean, TX sd,
* pre-law diff, se, p, N, DiD b3, se, p, N
*-------------------------------------------------------------------------------
tempname h
postfile `h' str20 variable mean_ca sd_ca mean_tx sd_tx ///
    diff diff_se diff_p diff_n did did_se did_p did_n ///
    using "temp/table1_balance.dta", replace

foreach v in `meansonly' `balance' {
    quietly summarize `v' if post == 0 & ca == 1
    local m1 = r(mean)
    local s1 = r(sd)
    quietly summarize `v' if post == 0 & ca == 0
    local m0 = r(mean)
    local s0 = r(sd)
    * balance regressions for the balance variables only
    local isbal : list v in balance
    if `isbal' {
        quietly reg `v' ca if post == 0, vce(cluster gvkey)
        local b  = _b[ca]
        local se = _se[ca]
        local p  = 2 * ttail(e(df_r), abs(`b' / `se'))
        local n  = e(N)
        quietly reg `v' ca post ca_post, vce(cluster gvkey)
        local b3  = _b[ca_post]
        local se3 = _se[ca_post]
        local p3  = 2 * ttail(e(df_r), abs(`b3' / `se3'))
        local n3  = e(N)
    }
    else {
        local b   = .
        local se  = .
        local p   = .
        local n   = .
        local b3  = .
        local se3 = .
        local p3  = .
        local n3  = .
    }
    post `h' ("`v'") (`m1') (`s1') (`m0') (`s0') ///
        (`b') (`se') (`p') (`n') (`b3') (`se3') (`p3') (`n3')
}
postclose `h'

* firm and firm-year counts for the table notes
count if post == 0 & ca == 1
local fy_ca = r(N)
count if post == 0 & ca == 0
local fy_tx = r(N)
quietly tab gvkey if post == 0 & ca == 1
local f_ca = r(r)
quietly tab gvkey if post == 0 & ca == 0
local f_tx = r(r)
display "Pre-law firm-years: CA `fy_ca', TX `fy_tx'. Firms: CA `f_ca', TX `f_tx'."

use "temp/table1_balance.dta", clear
format mean_* sd_* diff* did* %9.3f
format diff_n did_n %9.0f
list, noobs clean
export delimited using "output/table1_balance.csv", replace

log close
