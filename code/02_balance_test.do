*==============================================================================
* 02_balance_test.do -- Table 1: means and balance test, California vs Texas
* Author: Ansh
* Sample: main window (fiscal year-ends Jun 2010 - Dec 2019). SEs clustered by firm.
* Input:  final_data.dta
* Output: output/table1_means.csv (outsum), output/balance_prelaw.xml and
*         output/balance_did.xml (outreg2), output/table1_balance.csv (all
*         columns in one file, read by 03_table1_format.py)
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
log using "logs/02_balance_test.log", replace text

use "final_data.dta", clear
keep if mainwindow == 1

* Balance test variables (chosen in 01b_collinearity_tests.do).
* age_missing and pifo_missing show how often age and foreign income are blank.
local balance lnassets roa leverage multinational pifo_missing age age_missing ///
              nyse tech energy boardsize
* Shown in the means columns only: the outcome and the board outcomes
local meansonly lnmktcap women zerowomen pharma

* Short labels for the table (outsum uses the label and cannot take commas)
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
* Means and SDs before and after the law, by state (outsum)
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
* CA - TX difference before the law (outreg2)
*-------------------------------------------------------------------------------
local app replace
foreach v of local balance {
    reg `v' ca if post == 0, cluster(gvkey)
    outreg2 ca using "output/balance_prelaw", `app' excel noaster ///
        ctitle("`v'") label
    local app append
}

*-------------------------------------------------------------------------------
* Diff-in-diff in each balance variable (outreg2)
*-------------------------------------------------------------------------------
local app replace
foreach v of local balance {
    reg `v' ca post ca_post, cluster(gvkey)
    outreg2 ca_post using "output/balance_did", `app' excel noaster ///
        ctitle("`v'") label
    local app append
}

*-------------------------------------------------------------------------------
* All columns in one file, one row per variable: means and SDs by state before
* and after the law, the pre-law difference (b, se, p, N) and the DiD (b, se, p, N).
* not from class: postfile collects one row per variable into a new dataset.
*-------------------------------------------------------------------------------
tempname h
postfile `h' str20 variable mean_ca sd_ca mean_tx sd_tx ///
    mean_ca_post sd_ca_post mean_tx_post sd_tx_post ///
    diff diff_se diff_p diff_n did did_se did_p did_n ///
    using "temp/table1_balance.dta", replace

* means-only variables: no regressions, so those columns are missing
foreach v of local meansonly {
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
    post `h' ("`v'") (`m1') (`s1') (`m0') (`s0') ///
        (`m1p') (`s1p') (`m0p') (`s0p') ///
        (.) (.) (.) (.) (.) (.) (.) (.)
}

* balance variables: means plus the two regressions above
foreach v of local balance {
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
    * pre-law difference
    quietly reg `v' ca if post == 0, cluster(gvkey)
    local b  = _b[ca]
    local se = _se[ca]
    local p  = 2 * ttail(e(df_r), abs(`b' / `se'))
    local n  = e(N)
    * diff-in-diff
    quietly reg `v' ca post ca_post, cluster(gvkey)
    local b3  = _b[ca_post]
    local se3 = _se[ca_post]
    local p3  = 2 * ttail(e(df_r), abs(`b3' / `se3'))
    local n3  = e(N)
    post `h' ("`v'") (`m1') (`s1') (`m0') (`s0') ///
        (`m1p') (`s1p') (`m0p') (`s0p') ///
        (`b') (`se') (`p') (`n') (`b3') (`se3') (`p3') (`n3')
}
postclose `h'

* firm-years and firms in each of the four groups (last two rows of Table 1)
count if ca == 0 & post == 0
local fy_tx_pre = r(N)
count if ca == 0 & post == 1
local fy_tx_post = r(N)
count if ca == 1 & post == 0
local fy_ca_pre = r(N)
count if ca == 1 & post == 1
local fy_ca_post = r(N)

* r(r) after tab = number of different firms
quietly tab gvkey if ca == 0 & post == 0
local f_tx_pre = r(r)
quietly tab gvkey if ca == 0 & post == 1
local f_tx_post = r(r)
quietly tab gvkey if ca == 1 & post == 0
local f_ca_pre = r(r)
quietly tab gvkey if ca == 1 & post == 1
local f_ca_post = r(r)
quietly tab gvkey if post == 0
local f_pre = r(r)
quietly tab gvkey
local f_all = r(r)

display "Firm-years  TX pre `fy_tx_pre'  TX post `fy_tx_post'  CA pre `fy_ca_pre'  CA post `fy_ca_post'"
display "Firms       TX pre `f_tx_pre'   TX post `f_tx_post'   CA pre `f_ca_pre'   CA post `f_ca_post'"

* add the two count rows to the bottom of the file
use "temp/table1_balance.dta", clear
local row1 = _N + 1
local row2 = _N + 2
set obs `row2'

replace variable = "firm_years" in `row1'
replace mean_ca = `fy_ca_pre' in `row1'
replace mean_tx = `fy_tx_pre' in `row1'
replace mean_ca_post = `fy_ca_post' in `row1'
replace mean_tx_post = `fy_tx_post' in `row1'
replace diff_n = `fy_tx_pre' + `fy_ca_pre' in `row1'
replace did_n = `fy_tx_pre' + `fy_tx_post' + `fy_ca_pre' + `fy_ca_post' in `row1'

replace variable = "firms" in `row2'
replace mean_ca = `f_ca_pre' in `row2'
replace mean_tx = `f_tx_pre' in `row2'
replace mean_ca_post = `f_ca_post' in `row2'
replace mean_tx_post = `f_tx_post' in `row2'
replace diff_n = `f_pre' in `row2'
replace did_n = `f_all' in `row2'
save "temp/table1_balance.dta", replace

format mean_* sd_* diff* did* %9.3f
format diff_n did_n %9.0f
list, noobs clean
export delimited using "output/table1_balance.csv", replace

cap log close
