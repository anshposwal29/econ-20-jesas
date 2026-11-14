*==============================================================================
* 01b_collinearity_tests.do -- which variables go in the balance test (appendix)
* Author: Ansh
* Sample: pre-law firm-years in the main window, California and Texas.
* Rule: drop a variable if |correlation| >= 0.70 with another kept variable, or VIF >= 5.
* Input:  temp/balance_candidates.dta (from 01_build_data.do)
* Output: output/collinearity_tests.xlsx (sheets Correlations, VIF, Missing)
* Not from class: pwcorr, estat vif and putexcel (used only for this appendix table).
*==============================================================================
cap log close
clear
set more off

* put the location of your project folder here. Each person has their own line;
* the lines for other people's computers fail quietly, so leave them in.
capture cd "~/Desktop/Dartmouth Classes/Economics/ECON20/project"      // Ansh
capture cd "C:/Users/shinz/OneDrive/Desktop/Econ20 FinalProject"       // Sophia
capture cd "/Users/joseohui/Desktop/UIC/Dartmouth/Fall/Econometrics/JESAS/project"  // Seohee
capture cd "C:/Econ 20/proj"                                           // Eloise
confirm file "final_data.dta"   // if this fails, add a line with your folder above
capture mkdir "logs"
capture mkdir "output"
capture mkdir "output/figures"
log using "logs/01b_collinearity_tests.log", replace text

use "temp/balance_candidates.dta", clear
keep if mainwindow == 1 & post == 0

*-------------------------------------------------------------------------------
* TEST 1. Pairwise correlations (lnmktcap is the outcome, shown for reference)
*-------------------------------------------------------------------------------
pwcorr lnmktcap lnsale lnemp lnassets roa leverage multinational age nyse tech ///
    energy boardsize pharma fin rd women zerowomen
matrix C = r(C)
putexcel set "output/collinearity_tests.xlsx", replace sheet("Correlations")
putexcel A1 = matrix(C), names nformat("0.00")

*-------------------------------------------------------------------------------
* TEST 2. Variance inflation factors (VIF). A VIF only depends on the
* right-hand-side variables, so the outcome used here does not matter.
* estat vif lists the variables from highest to lowest VIF.
*-------------------------------------------------------------------------------
putexcel set "output/collinearity_tests.xlsx", modify sheet("VIF")
putexcel A1 = "Specification" B1 = "Variable" C1 = "VIF" D1 = "Observations"

* (a) all 15 candidates except rd (rd is missing for 43% of firm-years): rows 2-16
regress lnmktcap lnsale lnemp lnassets roa leverage multinational age nyse tech ///
    energy boardsize pharma fin women zerowomen
local n = e(N)
estat vif
forvalues i = 1/15 {
    local row = 1 + `i'
    putexcel A`row' = "All candidates except rd" B`row' = "`r(name_`i')'" ///
             C`row' = `r(vif_`i')' D`row' = `n'
}

* (b) the 9 variables in the final list: rows 17-25
regress lnmktcap lnassets roa leverage multinational age nyse tech energy boardsize
local n = e(N)
estat vif
forvalues i = 1/9 {
    local row = 16 + `i'
    putexcel A`row' = "Final list" B`row' = "`r(name_`i')'" ///
             C`row' = `r(vif_`i')' D`row' = `n'
}

* (c) the final list without age, which has a larger sample: rows 26-33
regress lnmktcap lnassets roa leverage multinational nyse tech energy boardsize
local n = e(N)
estat vif
forvalues i = 1/8 {
    local row = 25 + `i'
    putexcel A`row' = "Final list without age (larger sample)" B`row' = "`r(name_`i')'" ///
             C`row' = `r(vif_`i')' D`row' = `n'
}

*-------------------------------------------------------------------------------
* TEST 3. Share of firm-years missing each variable, by state
*-------------------------------------------------------------------------------
putexcel set "output/collinearity_tests.xlsx", modify sheet("Missing")
putexcel A1 = "Variable" B1 = "Share missing, California" C1 = "Share missing, Texas"

quietly count if ca == 1
local n_ca = r(N)
quietly count if ca == 0
local n_tx = r(N)

local row = 2
foreach v in lnsale lnemp lnassets roa leverage multinational age nyse tech ///
    energy boardsize pharma fin rd women zerowomen {
    quietly count if ca == 1 & missing(`v')
    local m_ca = r(N) / `n_ca'
    quietly count if ca == 0 & missing(`v')
    local m_tx = r(N) / `n_tx'
    putexcel A`row' = "`v'" B`row' = `m_ca' C`row' = `m_tx'
    local row = `row' + 1
}

* is age missing more often in California than in Texas?
gen age_missing = (age == .)
regress age_missing ca, cluster(gvkey)

cap log close
