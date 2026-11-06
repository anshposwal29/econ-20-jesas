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

clear all
set more off
* --- SAME project folder as 01_build_data.do ---
cd "C:/Econ 20/proj"

capture mkdir figures
capture log close
log using "C:/Econ 20/proj", replace text

use "final_data.dta", clear

*-------------------------------------------------------------------------------
* 1. Define the event-time "year"
*-------------------------------------------------------------------------------
* SB 826 was signed 30 Sep 2018 and POST = fiscal year-end on/after 1 Oct 2018.
* Calendar year of the FYE (fyeyear) would mix pre and post firms in 2018
* (a June 2018 FYE is pre, a Dec 2018 FYE is post). So we build a "policy year"
* that starts on 1 Oct:
*     pyear 2018 = fiscal year-ends 1 Oct 2017 - 30 Sep 2018  (last PRE year)
*     pyear 2019 = fiscal year-ends 1 Oct 2018 - 30 Sep 2019  (first POST year)
gen pyear = year(fye) + (month(fye) >= 10)
label var pyear "Policy year (runs 1 Oct - 30 Sep; pyear 2019 = first post year)"

* Sanity check: pyear >= 2019 should coincide exactly with post == 1
assert (pyear >= 2019) == post

* Settings you can change -------------------------------------------------------
local refyr   2018     // omitted (reference) year = last pre-treatment year
local firstyr 2011     // pyear 2010 only has Jun-Sep 2010 year-ends (partial), so start in 2011
local lastyr  2025     // pyear 2026 only has Oct-Dec 2025 year-ends (partial)
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

* vertical line sits between the last pre year (2018) and first post year (2019)
gr two (scatter slope pyear, yline(0, lc(black))) ///
       (rcap upper lower pyear, xline(2018.5, lp(dash))), ///
    legend(off) ///
    xlabel(`firstyr'(2)`lastyr') ///
    xtitle("Policy year (runs 1 Oct - 30 Sep; 2019 = first year after SB 826)") ///
    ytitle("CA - TX difference in ln(market cap), relative to 2018") ///
    title("ln(Market Cap) Event Study" "California SB 826 (Board Gender Quota)", size(medium)) ///
    note("Firm-year data, CA vs. TX. Texas is the comparison group; 2018 (last pre-law year) is the omitted year." ///
         "Bars show 95% confidence intervals, standard errors clustered by firm. Dashed line = SB 826 signed 30 Sep 2018.")
graph export "figures/event_study_lnmktcap.png", replace width(2000)
graph save   "figures/event_study_lnmktcap.gph", replace
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
       (line lnmktcap pyear if ca==0, xline(2018.5, lp(dash))) ///
       (rcap upper lower pyear if ca==1) ///
       (rcap upper lower pyear if ca==0), ///
    legend(label(1 "California") label(2 "Texas") order(1 2)) ///
    xlabel(`firstyr'(2)`lastyr') ///
    xtitle("Policy year (runs 1 Oct - 30 Sep; 2019 = first year after SB 826)") ///
    ytitle("Mean ln(market cap, $ millions)") ///
    title("Mean ln(Market Cap) Before and After California SB 826", size(medium)) ///
    note("Listed firms headquartered in CA (treated) or TX (comparison) on 30 Sep 2018. Bars show 95% confidence intervals.")
graph export "figures/means_lnmktcap.png", replace width(2000)
graph save   "figures/means_lnmktcap.gph", replace
restore

log close
