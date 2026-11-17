/*==============================================================================
  ECON 20 Project: California SB 826 (board gender quota) and firm value
  Program 4: REDUCED FORM (CA vs. TX, outcome = ln(market cap))

  Input : final_data.dta   (built by 01_build_data.do)
  Output: figures/means_lnmktcap.png / .gph         (main graph: raw means with CIs)
          figures/reduced_form_lnmktcap.png / .gph  (event study, firm + year FE)

  Reduced form (column 2 below is the one that matches your equation):
      ln(mktcap)_it = b0 + b1*Post + b2*(CA_i x Post) + a_i + u_it
    - Post  = 1 if the fiscal year ended on or after 1 Oct 2018
    - a_i   = FIRM FIXED EFFECTS (absorb CA, so CA alone is dropped)

  Three versions are shown so you can see what fixed effects do:
    (1) no fixed effects         : lnmktcap on CA, Post, CA x Post
    (2) firm fixed effects       : your equation
    (3) firm + year fixed effects: year FE absorb Post (the standard two-way FE DiD)
  The coefficient on CA x Post is b2 in every column. Because the outcome is in
  logs, b2 x 100 is approximately the percent change in market cap.
==============================================================================*/

* Eloise's graph script (was code/archive/ReducedFrom_DiD.do), now on fiscal years 2011-2020
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
log using "logs/11_graphs_reduced_form.log", replace text

use "final_data.dta", clear

*-------------------------------------------------------------------------------
* 0. Build the outcome: ln(market cap)
*
*    >>> CHECK THIS: set the local below to the name of your market cap variable
*        (e.g. mktcap, mkvalt, me). Run -describe- if you are not sure.
*    Logs need strictly positive values, so zero/negative/missing are dropped.
*-------------------------------------------------------------------------------
local mcvar mktcap

* Keep the SAME sample as the first stage (firms with a BoardEx match)?
* 1 = yes (recommended for 2SLS so both stages use the same firms), 0 = no
local samesample 1
if `samesample' == 1 keep if board_matched == 1

count if `mcvar' <= 0
count if missing(`mcvar')

label var lnmktcap "ln(market capitalization)"
drop if missing(lnmktcap)

*-------------------------------------------------------------------------------
* 1. Define the event-time "year" (same as programs 2 and 3)
*-------------------------------------------------------------------------------
* year = fiscal year (calendar year of the fiscal year end), as in the other scripts
gen pyear = fyeyear
label var pyear "Fiscal year (calendar year of fiscal year end)"

* Settings you can change -------------------------------------------------------
local refyr   2017     // omitted (reference) year = last fully pre-law fiscal year
local firstyr 2011
local lastyr  2020
* To show only the pre-COVID window instead, use:  keep if mainwindow == 1
* To drop the 10 firms that moved out of California (robustness):
*   drop if mover == 1
* ------------------------------------------------------------------------------

keep if pyear >= `firstyr' & pyear <= `lastyr'

* Sanity checks: look at these before trusting any graph
tab pyear ca
summ lnmktcap, detail
tabstat lnmktcap, by(ca) stat(mean sd n)

*-------------------------------------------------------------------------------
* 2. The reduced-form regressions (this is your main result)
*    areg ..., absorb(gvkey) = firm fixed effects
*    Standard errors clustered by firm in every column.
*-------------------------------------------------------------------------------
gen caXpost = ca * post
label var caXpost "CA x Post"
assert caXpost == ca_post

* (1) no fixed effects
reg lnmktcap ca post caXpost, vce(cluster gvkey)
estimates store r1
test caXpost

* (2) firm fixed effects  <-- your equation
areg lnmktcap post caXpost, absorb(gvkey) vce(cluster gvkey)
estimates store r2
test caXpost

* (3) firm AND year fixed effects (i.pyear absorbs Post)
areg lnmktcap caXpost i.pyear, absorb(gvkey) vce(cluster gvkey)
estimates store r3
test caXpost

* side-by-side table
estimates table r1 r2 r3, keep(ca post caXpost) b(%9.4f) se(%9.4f) ///
    stats(N r2) title("Reduced form: ln(mktcap) on CA x Post")

*-------------------------------------------------------------------------------
* 3. MAIN GRAPH: average ln(market cap), by state and year, with 95% CIs
*-------------------------------------------------------------------------------
preserve
collapse (mean) lnmktcap (semean) se_y=lnmktcap, by(ca pyear)
gen upper = lnmktcap + 1.96*se_y
gen lower = lnmktcap - 1.96*se_y

gr two (line lnmktcap pyear if ca==1) ///
       (line lnmktcap pyear if ca==0, xline(2017.5, lp(dash))) ///
       (rcap upper lower pyear if ca==1) ///
       (rcap upper lower pyear if ca==0), ///
    legend(label(1 "California") label(2 "Texas") order(1 2)) ///
    xlabel(`firstyr'(1)`lastyr') ///
    xtitle("Fiscal year (calendar year of fiscal year end; SB 826 applies from FY2018)") ///
    ytitle("Average ln(market capitalization)") ///
    title("Firm Value Before and After California SB 826", size(medium)) ///
    note("Listed firms headquartered in CA (treated) or TX (comparison) on 30 Sep 2018. Bars show 95% confidence intervals.")
graph export "output/figures/means_lnmktcap_boardsample.png", replace width(2000)
graph save   "output/figures/means_lnmktcap_boardsample.gph", replace
restore

*-------------------------------------------------------------------------------
* 4. SECONDARY GRAPH: event study (firm fixed effects + year dummies)
*    Year dummies are year fixed effects; firm FE absorb CA, so "ca" is omitted.
*    Each CA x year coefficient = CA-TX gap in ln(mktcap) in that year minus the
*    gap in 2017.
*-------------------------------------------------------------------------------
forvalues t = `firstyr'/`lastyr' {
    if `t' != `refyr' {
        gen yrdum`t'    = (pyear == `t')
        gen caXyrdum`t' = ca * yrdum`t'
    }
}

areg lnmktcap yrdum* caXyrdum*, absorb(gvkey) vce(cluster gvkey)

* joint test of no pre-trends (all pre-period interactions = 0)
local pretest ""
forvalues t = `firstyr'/`=`refyr'-1' {
    local pretest `pretest' caXyrdum`t'
}
test `pretest'

* store coefficients and standard errors by year
gen slope = 0          // reference year stays at 0
gen se    = .          // and has no standard error (no CI drawn)
forvalues t = `firstyr'/`lastyr' {
    if `t' != `refyr' {
        replace slope = _b[caXyrdum`t'] if pyear == `t'
        replace se    = _se[caXyrdum`t'] if pyear == `t'
    }
}

* check the numbers before plotting (reference year should be 0 with no se)
tabstat slope se, by(pyear) stat(mean) nototal

preserve
collapse (mean) slope se, by(pyear)
gen upper = slope + 1.96*se
gen lower = slope - 1.96*se

gr two (scatter slope pyear, yline(0, lc(black))) ///
       (rcap upper lower pyear, xline(2017.5, lp(dash))), ///
    legend(off) ///
    xlabel(`firstyr'(1)`lastyr') ///
    xtitle("Fiscal year (calendar year of fiscal year end; SB 826 applies from FY2018)") ///
    ytitle("CA - TX difference in ln(market cap), relative to 2017") ///
    title("Reduced Form Event Study" "California SB 826 (Board Gender Quota)", size(medium)) ///
    note("Firm-year data, CA vs. TX, firm and year fixed effects. 2017 (last fully pre-law year) is the omitted year." ///
         "Bars show 95% confidence intervals, standard errors clustered by firm. Dashed line = SB 826 signed 30 Sep 2018.")
graph export "output/figures/reduced_form_lnmktcap.png", replace width(2000)
graph save   "output/figures/reduced_form_lnmktcap.gph", replace
restore

log close
