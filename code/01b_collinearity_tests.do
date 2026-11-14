/*==============================================================================
  ECON 20 Project: California SB 826 (board gender quota) and firm value
  COLLINEARITY TESTS: which variables go in the balance test (for the appendix)

  Sample: firm-years before the law in the main window, California and Texas.
  Rule, set before choosing: drop a variable if it has |correlation| >= 0.70 with
  another kept variable, or a variance inflation factor (VIF) >= 5.

  Input:  temp/balance_candidates.dta (from 01_build_data.do)
  Output: output/collinearity_tests.xlsx
            Correlations  pairwise correlations among all candidates
            VIF           VIFs for all candidates and for the final list
            Missing       share of firm-years missing each variable, by state
  File:   code/01b_collinearity_tests.do   Author: Ansh
  Run:    do code/01b_collinearity_tests.do (or via code/00_master.do)
  Log:    logs/01b_collinearity_tests.log
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
log using "logs/01b_collinearity_tests.log", replace text

use "temp/balance_candidates.dta", clear
keep if mainwindow == 1 & post == 0

local final lnassets roa leverage multinational age nyse tech energy boardsize
local cand  lnsale lnemp `final' pharma fin rd women zerowomen
local file  "output/collinearity_tests.xlsx"

*-------------------------------------------------------------------------------
* TEST 1. Pairwise correlations (lnmktcap is the outcome, shown for reference)
*-------------------------------------------------------------------------------
pwcorr lnmktcap `cand'
matrix C = r(C)
putexcel set "`file'", replace sheet("Correlations")
putexcel A1 = matrix(C), names nformat("0.00")

*-------------------------------------------------------------------------------
* TEST 2. Variance inflation factors. A VIF depends only on the right-hand-side
*   variables, so the outcome used here does not matter. rd is left out of the
*   all-candidates run because it is missing for 43% of firm-years.
*-------------------------------------------------------------------------------
putexcel set "`file'", modify sheet("VIF")
putexcel A1 = "Specification" B1 = "Variable" C1 = "VIF" D1 = "Observations"

local row = 2
local rdname rd
local allcand : list cand - rdname

foreach spec in allcand final finalnoage {
    if "`spec'" == "allcand" {
        local xs `allcand'
        local name "All candidates except rd"
    }
    if "`spec'" == "final" {
        local xs `final'
        local name "Final list"
    }
    if "`spec'" == "finalnoage" {
        local noage age
        local xs : list final - noage
        local name "Final list without age (larger sample)"
    }
    quietly regress lnmktcap `xs'
    local n = e(N)
    estat vif
    local k : word count `xs'
    forvalues i = 1/`k' {
        putexcel A`row' = "`name'" B`row' = "`r(name_`i')'" ///
                 C`row' = `r(vif_`i')' D`row' = `n'
        local ++row
    }
}

*-------------------------------------------------------------------------------
* TEST 3. Missing data by state, and whether age is missing at random
*-------------------------------------------------------------------------------
putexcel set "`file'", modify sheet("Missing")
putexcel A1 = "Variable" B1 = "Share missing, California" C1 = "Share missing, Texas"

local row = 2
foreach v of local cand {
    quietly count if ca == 1
    local n1 = r(N)
    quietly count if ca == 1 & missing(`v')
    local m1 = r(N) / `n1'
    quietly count if ca == 0
    local n0 = r(N)
    quietly count if ca == 0 & missing(`v')
    local m0 = r(N) / `n0'
    putexcel A`row' = "`v'" B`row' = `m1' C`row' = `m0'
    local ++row
}

gen age_missing = (age == .)
regress age_missing ca, vce(cluster gvkey)

log close
