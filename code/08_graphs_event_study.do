/*==============================================================================
  ECON 20 Project: California SB 826 (board gender quota) and firm value
  Program 2: EVENT STUDY GRAPH (CA vs. TX, outcome = ln(market cap))

  Input : final_data.dta   (built by 01_build_data.do)
  Output: figures/event_study_lnmktcap.png / .gph
          figures/means_lnmktcap.png / .gph   (companion graph: raw means with CIs)

  Logic (same as the handout's "fully differenced event study"):
    - regress ln(mktcap) on year dummies, CA, and CA x year dummies,
      leaving out the last pre-treatment year (the reference year)
    - each CA x year coefficient = how much the CA-TX gap in that year differs
      from the CA-TX gap in the reference year
    - plot those coefficients with 95% confidence intervals
==============================================================================*/

* Eloise's graph script (was code/archive/Graph_and_EventStudy.do), now on fiscal years 2011-2020
* like every other script. Changed: folder lines, the year variable (fiscal year
* instead of policy year), the end year (2020) and the reference year (2017, as in
* 07_panel_event_study_graphs.do). Everything else is Eloise's code.
cap log close
clear all
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
log using "logs/08_graphs_event_study.log", replace text

use "final_data.dta", clear

*-------------------------------------------------------------------------------
* 1. Define the event-time "year"
*-------------------------------------------------------------------------------
* SB 826 was signed 30 Sep 2018. Fiscal year 2018 mixes pre and post firms (a June
* 2018 year-end is pre, a Dec 2018 year-end is post), so 2017 is the reference year.
* year = fiscal year (calendar year of the fiscal year end), as in the other scripts
gen pyear = fyeyear
label var pyear "Fiscal year (calendar year of fiscal year end)"

* Settings you can change -------------------------------------------------------
local refyr   2017     // omitted (reference) year = last fully pre-law fiscal year
local firstyr 2011
local lastyr  2020
* To show only the pre-COVID window instead, use:  keep if mainwindow == 1
*   (then set lastyr to 2019; note pyear 2020 would hold only Oct-Dec 2019 year-ends)
* To drop the 10 firms that moved out of California (robustness):
*   drop if mover == 1
* ------------------------------------------------------------------------------

keep if pyear >= `firstyr' & pyear <= `lastyr'

tab pyear ca

*-------------------------------------------------------------------------------
* 2. Year dummies and CA x year interactions (all in the firm-year data,
*    NOT collapsed -- see footnote 1 in the handout)
*-------------------------------------------------------------------------------
forvalues y = `firstyr'/`lastyr' {
    if `y' != `refyr' {
        gen yrdum`y'   = (pyear == `y')
        gen caXyrdum`y' = ca * yrdum`y'
    }
}

*-------------------------------------------------------------------------------
* 3. Fully interacted regression
*    Standard errors clustered by firm (gvkey) because the same firm appears
*    in many years.
*-------------------------------------------------------------------------------
reg lnmktcap yrdum* ca caXyrdum*, vce(cluster gvkey)

* joint test of no pre-trends (all pre-period interactions = 0)
local pretest ""
forvalues y = `firstyr'/`=`refyr'-1' {
    local pretest `pretest' caXyrdum`y'
}
test `pretest'

*-------------------------------------------------------------------------------
* 4. Store coefficients and standard errors by year, then plot
*-------------------------------------------------------------------------------
gen slope = 0          // reference year stays at 0
gen se    = .          // and has no standard error (no CI drawn)

forvalues y = `firstyr'/`lastyr' {
    if `y' != `refyr' {
        replace slope = _b[caXyrdum`y'] if pyear == `y'
        replace se    = _se[caXyrdum`y'] if pyear == `y'
    }
}

preserve
collapse (mean) slope se, by(pyear)
gen upper = slope + 1.96*se
gen lower = slope - 1.96*se

* vertical line sits between the last fully pre-law year (2017) and 2018
gr two (scatter slope pyear, yline(0, lc(black))) ///
       (rcap upper lower pyear, xline(2017.5, lp(dash))), ///
    legend(off) ///
    xlabel(`firstyr'(1)`lastyr') ///
    xtitle("Fiscal year (calendar year of fiscal year end; SB 826 applies from FY2018)") ///
    ytitle("CA - TX difference in ln(market cap), relative to 2017") ///
    title("ln(Market Cap) Event Study" "California SB 826 (Board Gender Quota)", size(medium)) ///
    note("Firm-year data, CA vs. TX. Texas is the comparison group; 2017 (last fully pre-law year) is the omitted year." ///
         "Bars show 95% confidence intervals, standard errors clustered by firm. Dashed line = SB 826 signed 30 Sep 2018.")
graph export "output/figures/event_study_lnmktcap.png", replace width(2000)
graph save   "output/figures/event_study_lnmktcap.gph", replace
restore

*-------------------------------------------------------------------------------
* 5. Companion graph: mean ln(market cap) by state and year, with 95% CIs
*    (the handout's "rcap" line graph; good to show before the event study)
*-------------------------------------------------------------------------------
preserve
collapse (mean) lnmktcap (semean) se_lnmktcap=lnmktcap, by(ca pyear)
gen upper = lnmktcap + 1.96*se_lnmktcap
gen lower = lnmktcap - 1.96*se_lnmktcap

gr two (line lnmktcap pyear if ca==1) ///
       (line lnmktcap pyear if ca==0, xline(2017.5, lp(dash))) ///
       (rcap upper lower pyear if ca==1) ///
       (rcap upper lower pyear if ca==0), ///
    legend(label(1 "California") label(2 "Texas") order(1 2)) ///
    xlabel(`firstyr'(1)`lastyr') ///
    xtitle("Fiscal year (calendar year of fiscal year end; SB 826 applies from FY2018)") ///
    ytitle("Mean ln(market cap, $ millions)") ///
    title("Mean ln(Market Cap) Before and After California SB 826", size(medium)) ///
    note("Listed firms headquartered in CA (treated) or TX (comparison) on 30 Sep 2018. Bars show 95% confidence intervals.")
graph export "output/figures/means_lnmktcap.png", replace width(2000)
graph save   "output/figures/means_lnmktcap.gph", replace
restore

log close
