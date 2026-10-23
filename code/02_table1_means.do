/*==============================================================================
  ECON 20 Project: California SB 826 and firm value
  Program 2: TABLE 1 (MEANS), WASHINGTON EXCLUDED
    Table 1a: before vs after the law, California vs all other states (excl. WA)
              before = fiscal year ended Jan 2010 - 30 Sep 2018
              after  = fiscal year ended 1 Oct 2018 - 31 Dec 2019
    Table 1b: year-by-year means, 2010-2025, California vs other states
  Uses built-in Stata commands only (no ssc add-ons needed).
==============================================================================*/

clear all
set more off
* --- CHANGE THIS LINE to the project folder on your computer ---
cd "~/Desktop/Dartmouth Classes/Economics/ECON20/project"

capture log close
log using "logs/02_table1_means.log", replace text

use "final_data.dta", clear          // Washington already excluded in 01_build_data.do
assert wa == 0

local vars lnmktcap mktcap lnassets roa leverage multinational age nyse tech ///
           boardsize women zerowomen

*===============================================================================
* TABLE 1a. Before vs after, main window (fiscal year-ends 2010 - 2019)
*===============================================================================
preserve
keep if mainwindow == 1

display _newline "===== BEFORE the law: fiscal year ended Jan 2010 - 30 Sep 2018 ====="
display "ca = 0: all other states (excl. WA)    ca = 1: California"
tabstat `vars' if post == 0, by(ca) stat(mean sd n) columns(statistics) longstub

display _newline "===== AFTER the law: fiscal year ended 1 Oct 2018 - 31 Dec 2019 ====="
tabstat `vars' if post == 1, by(ca) stat(mean sd n) columns(statistics) longstub

* Number of firms in each cell
egen firmtag = tag(gvkey ca post)
display _newline "Number of FIRMS by group (rows: ca, columns: post)"
tab ca post if firmtag
display _newline "Number of FIRM-YEARS by group"
tab ca post

* CSV for Excel: means and standard deviations, built-in commands only
* (no add-ons needed). One row per variable.
*   ca_pre = California before, oth_pre = all other states before, etc.
tempname h
postfile `h' str20 variable ///
    mean_ca_pre sd_ca_pre mean_oth_pre sd_oth_pre ///
    mean_ca_post sd_ca_post mean_oth_post sd_oth_post ///
    using "temp/table1a_post.dta", replace
foreach v of local vars {
    quietly summarize `v' if ca == 1 & post == 0
    local m1 = r(mean)
    local s1 = r(sd)
    quietly summarize `v' if ca == 0 & post == 0
    local m2 = r(mean)
    local s2 = r(sd)
    quietly summarize `v' if ca == 1 & post == 1
    local m3 = r(mean)
    local s3 = r(sd)
    quietly summarize `v' if ca == 0 & post == 1
    local m4 = r(mean)
    local s4 = r(sd)
    post `h' ("`v'") (`m1') (`s1') (`m2') (`s2') (`m3') (`s3') (`m4') (`s4')
}
postclose `h'

* Preliminary balance test: California minus other states, BEFORE the law.
* Standard errors clustered by firm (each firm appears in several years).
tempname b
postfile `b' str20 variable diff se pvalue nobs ///
    using "temp/balance_post.dta", replace
foreach v of local vars {
    quietly reg `v' ca if post == 0, vce(cluster gvkey)
    local d  = _b[ca]
    local se = _se[ca]
    local p  = 2 * ttail(e(df_r), abs(`d' / `se'))
    post `b' ("`v'") (`d') (`se') (`p') (e(N))
}
postclose `b'

restore

display _newline "===== TABLE 1a: means [sd], before vs after, excl. WA ====="
use "temp/table1a_post.dta", clear
format mean_* sd_* %9.3f
list, clean noobs abbreviate(14)
export delimited using "output/table1a_means.csv", replace

display _newline "===== Balance test: California minus other states, before the law ====="
display "(SE clustered by firm)"
use "temp/balance_post.dta", clear
format diff se pvalue %9.3f
list, clean noobs
export delimited using "output/balance_prelaw.csv", replace

use "final_data.dta", clear

*===============================================================================
* TABLE 1b. Year-by-year means, all years kept (2010 - 2025)
*   fyeyear = calendar year of the fiscal year-end
*   The law was signed 30 Sep 2018, so for December year-end firms
*   2018 is the first "after" year.
*===============================================================================
* (tabstat works in every Stata version)
display _newline "===== Year-by-year means: CALIFORNIA ====="
tabstat lnmktcap zerowomen women boardsize if ca == 1, by(fyeyear) stat(mean) format(%9.3f)

display _newline "===== Year-by-year means: ALL OTHER STATES (excl. WA) ====="
tabstat lnmktcap zerowomen women boardsize if ca == 0, by(fyeyear) stat(mean) format(%9.3f)

* Save the year-by-year means to a CSV (one row per year)
preserve
collapse (mean) lnmktcap zerowomen women boardsize lnassets ///
         (count) n_firmyears = lnmktcap, by(fyeyear ca)
reshape wide lnmktcap zerowomen women boardsize lnassets n_firmyears, i(fyeyear) j(ca)
* suffix 1 = California, suffix 0 = all other states (excl. WA)
order fyeyear lnmktcap1 lnmktcap0 zerowomen1 zerowomen0 women1 women0 ///
      boardsize1 boardsize0 lnassets1 lnassets0 n_firmyears1 n_firmyears0
export delimited using "output/table1b_means_by_year.csv", replace
list, clean noobs
restore

log close
