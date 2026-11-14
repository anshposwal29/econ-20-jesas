/*==============================================================================
  ECON 20 Project: California SB 826 (board gender quota) and firm value
  Program 2: TABLE 1 (MEANS) AND BALANCE TEST

  Sample: main window (fiscal year-ends Jun 2010 - Dec 2019), California vs Texas.

  Columns:
    (1)-(2) California and Texas before the law: mean [SD]      outsum
    (3)-(4) California and Texas after the law:  mean [SD]      outsum
    (3) CA - TX difference, before the law: b, (SE)     reg x ca if post == 0
    (4) Diff-in-diff in the control: b3, (SE)           reg x ca post ca_post
  Standard errors in (3) and (4) clustered by firm (gvkey).

  Input:  final_data.dta (from 01_build_data.do)
  Outputs (output/):
    table1_means.csv        means columns, from outsum
    balance_prelaw.xml      column (3), from outreg2, one regression per variable (opens in Excel)
    balance_did.xml         column (4), from outreg2, one regression per variable (opens in Excel)
    table1_balance.csv      everything in one file (built with postfile); input to 03_table1_format.py
  File:   code/02_balance_test.do   Author: Ansh
  Run:    do code/02_balance_test.do (or via code/00_master.do)
  Log:    logs/02_balance_test.log
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
* Columns (1)-(4): means and SDs before and after the law, by state (outsum)
*-------------------------------------------------------------------------------
outsum `meansonly' `balance' using "output/table1_means.csv" ///
    if post == 0 & ca == 1, replace comma bracket ctitle("California")
outsum `meansonly' `balance' using "output/table1_means.csv" ///
    if post == 0 & ca == 0, append comma bracket ctitle("Texas")
outsum `meansonly' `balance' using "output/table1_means.csv" ///
    if post == 1 & ca == 1, append comma bracket ctitle("California after")
outsum `meansonly' `balance' using "output/table1_means.csv" ///
    if post == 1 & ca == 0, append comma bracket ctitle("Texas after")

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
* One combined file: variable, means and SDs before and after the law by
* state, pre-law diff (se, p, N), DiD b3 (se, p, N). 03_table1_format.py
* turns this into the formatted Table 1.
*-------------------------------------------------------------------------------
tempname h
postfile `h' str20 variable mean_ca sd_ca mean_tx sd_tx ///
    mean_ca_post sd_ca_post mean_tx_post sd_tx_post ///
    diff diff_se diff_p diff_n did did_se did_p did_n ///
    using "temp/table1_balance.dta", replace

foreach v in `meansonly' `balance' {
    quietly summarize `v' if post == 0 & ca == 1
    local m1 = r(mean)
    local s1 = r(sd)
    quietly summarize `v' if post == 0 & ca == 0
    local m0 = r(mean)
    local s0 = r(sd)
    quietly summarize `v' if post == 1 & ca == 1
    local m1p = r(mean)
    local s1p = r(sd)
    quietly summarize `v' if post == 1 & ca == 0
    local m0p = r(mean)
    local s0p = r(sd)
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
        (`m1p') (`s1p') (`m0p') (`s0p') ///
        (`b') (`se') (`p') (`n') (`b3') (`se3') (`p3') (`n3')
}
postclose `h'

* firm-year and firm counts for each of the four groups (last rows of Table 1)
foreach g in "0 0" "0 1" "1 0" "1 1" {
    local c : word 1 of `g'
    local p : word 2 of `g'
    count if ca == `c' & post == `p'
    local fy_`c'`p' = r(N)
    quietly tab gvkey if ca == `c' & post == `p'
    local f_`c'`p' = r(r)
}
display "Firm-years  TX pre `fy_00'  TX post `fy_01'  CA pre `fy_10'  CA post `fy_11'"
display "Firms       TX pre `f_00'   TX post `f_01'   CA pre `f_10'   CA post `f_11'"
quietly tab gvkey if post == 0
local f_pre = r(r)
quietly tab gvkey
local f_all = r(r)

use "temp/table1_balance.dta", clear
local N = _N + 2
set obs `N'
replace variable = "firm_years" in `=_N-1'
replace mean_ca = `fy_10' in `=_N-1'
replace mean_tx = `fy_00' in `=_N-1'
replace mean_ca_post = `fy_11' in `=_N-1'
replace mean_tx_post = `fy_01' in `=_N-1'
replace diff_n = `fy_00' + `fy_10' in `=_N-1'
replace did_n = `fy_00' + `fy_01' + `fy_10' + `fy_11' in `=_N-1'
replace variable = "firms" in `=_N'
replace mean_ca = `f_10' in `=_N'
replace mean_tx = `f_00' in `=_N'
replace mean_ca_post = `f_11' in `=_N'
replace mean_tx_post = `f_01' in `=_N'
replace diff_n = `f_pre' in `=_N'
replace did_n = `f_all' in `=_N'
save "temp/table1_balance.dta", replace

use "temp/table1_balance.dta", clear
format mean_* sd_* diff* did* %9.3f
format diff_n did_n %9.0f
list, noobs clean
export delimited using "output/table1_balance.csv", replace

log close
