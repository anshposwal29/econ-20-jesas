/*==============================================================================
  ECON 20 Project: California SB 826 (board gender quota) and firm value
  Program 3: FIRST STAGE (CA vs. TX, outcome = PERCENT WOMEN on the board)

  Input : final_data.dta   (built by 01_build_data.do)
  Output: figures/means_sharewm.png / .gph         (main graph: raw means with CIs)
          figures/first_stage_sharewm.png / .gph   (event study, firm + year FE)

  First stage (column 2 below is the one that matches your equation):
      ShareWm_it = b0 + b1*Post + b2*(CA_i x Post) + a_i + u_it
    - ShareWm = percent of the board that is women (0-100)
    - Post    = 1 if policy year >= 2019
    - a_i     = FIRM FIXED EFFECTS (absorb CA, so CA alone is dropped)

  Three versions are shown so you can see what fixed effects do:
    (1) no fixed effects         : ShareWm on CA, Post, CA x Post
    (2) firm fixed effects       : your equation
    (3) firm + year fixed effects: year FE absorb Post (the standard two-way FE DiD)
  The coefficient on CA x Post is b2 in every column, and is in PERCENTAGE POINTS.
==============================================================================*/

clear all
set more off
cd "C:/Econ 20/proj"

capture mkdir figures
capture log close
log using "first_stage_sharewm.log", replace text

use "final_data.dta", clear

*-------------------------------------------------------------------------------
* 0. Build the outcome: ShareWm = 100 * (women on board / board size)
*    Firms with no BoardEx match have missing board data, so they are dropped.
*
*    >>> CHECK THIS: set the local below to whatever variable holds the TOTAL
*        number of directors in your data (e.g. boardsize, board_size, nbod).
*        Run  -describe-  if you are not sure what it is called.
*-------------------------------------------------------------------------------
local bsvar boardsize

keep if board_matched == 1
gen ShareWm = 100 * women / `bsvar' if women < . & `bsvar' < . & `bsvar' > 0
label var ShareWm "Percent of board that is women"
assert !missing(ShareWm)
assert inrange(ShareWm, 0, 100)
assert (ShareWm == 0) == zerowomen

*-------------------------------------------------------------------------------
* 1. Define the event-time "year" (same as program 2)
*-------------------------------------------------------------------------------
gen pyear = year(fye) + (month(fye) >= 10)
label var pyear "Policy year (runs 1 Oct - 30 Sep; pyear 2019 = first post year)"
assert (pyear >= 2019) == post

* Settings you can change -------------------------------------------------------
local refyr   2018     // omitted (reference) year = last pre-treatment year
local firstyr 2011
local lastyr  2025
* To show only the pre-COVID window instead, use:  keep if mainwindow == 1
* To drop the 10 firms that moved out of California (robustness):
*   drop if mover == 1
* ------------------------------------------------------------------------------

keep if pyear >= `firstyr' & pyear <= `lastyr'

* Sanity checks: look at these before trusting any graph
tab pyear ca
summ ShareWm, detail
tabstat ShareWm, by(ca) stat(mean sd n)

*-------------------------------------------------------------------------------
* 2. The first-stage regressions (this is your main result)
*    areg ..., absorb(gvkey) = firm fixed effects
*    Standard errors clustered by firm in every column.
*-------------------------------------------------------------------------------
gen caXpost = ca * post
label var caXpost "CA x Post"
assert caXpost == ca_post

* (1) no fixed effects
reg ShareWm ca post caXpost, vce(cluster gvkey)
estimates store m1
test caXpost

* (2) firm fixed effects  <-- your equation
areg ShareWm post caXpost, absorb(gvkey) vce(cluster gvkey)
estimates store m2
test caXpost

* (3) firm AND year fixed effects (i.pyear absorbs Post)
areg ShareWm caXpost i.pyear, absorb(gvkey) vce(cluster gvkey)
estimates store m3
test caXpost

* side-by-side table; with one instrument, first-stage F = t^2 on caXpost
estimates table m1 m2 m3, keep(ca post caXpost) b(%9.4f) se(%9.4f) ///
    stats(N r2) title("First stage: ShareWm on CA x Post")

*-------------------------------------------------------------------------------
* 3. MAIN GRAPH: average percent women on the board,
*    by state and year, with 95% CIs
*-------------------------------------------------------------------------------
preserve
collapse (mean) ShareWm (semean) se_y=ShareWm, by(ca pyear)
gen upper = ShareWm + 1.96*se_y
gen lower = ShareWm - 1.96*se_y

gr two (line ShareWm pyear if ca==1) ///
       (line ShareWm pyear if ca==0, xline(2018.5, lp(dash))) ///
       (rcap upper lower pyear if ca==1) ///
       (rcap upper lower pyear if ca==0), ///
    legend(label(1 "California") label(2 "Texas") order(1 2)) ///
    xlabel(`firstyr'(2)`lastyr') ///
    xtitle("Policy year (runs 1 Oct - 30 Sep; 2019 = first year after SB 826)") ///
    ytitle("Average percent of board that is women") ///
    title("Women on Boards Before and After California SB 826", size(medium)) ///
    note("Listed firms headquartered in CA (treated) or TX (comparison) on 30 Sep 2018. Bars show 95% confidence intervals.")
graph export "figures/means_sharewm.png", replace width(2000)
graph save   "figures/means_sharewm.gph", replace
restore

*-------------------------------------------------------------------------------
* 4. SECONDARY GRAPH: event study (firm fixed effects + year dummies)
*    Year dummies are year fixed effects; firm FE absorb CA, so "ca" is omitted.
*    Each CA x year coefficient = CA-TX gap in that year minus the gap in 2018.
*-------------------------------------------------------------------------------
forvalues t = `firstyr'/`lastyr' {
    if `t' != `refyr' {
        gen yrdum`t'    = (pyear == `t')
        gen caXyrdum`t' = ca * yrdum`t'
    }
}

areg ShareWm yrdum* caXyrdum*, absorb(gvkey) vce(cluster gvkey)

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
       (rcap upper lower pyear, xline(2018.5, lp(dash))), ///
    legend(off) ///
    xlabel(`firstyr'(2)`lastyr') ///
    xtitle("Policy year (runs 1 Oct - 30 Sep; 2019 = first year after SB 826)") ///
    ytitle("CA - TX difference in percent women on board, relative to 2018") ///
    title("First Stage Event Study" "California SB 826 (Board Gender Quota)", size(medium)) ///
    note("Firm-year data, CA vs. TX, firm and year fixed effects. 2018 (last pre-law year) is the omitted year." ///
         "Bars show 95% confidence intervals, standard errors clustered by firm. Dashed line = SB 826 signed 30 Sep 2018.")
graph export "figures/first_stage_sharewm.png", replace width(2000)
graph save   "figures/first_stage_sharewm.gph", replace
restore

log close
