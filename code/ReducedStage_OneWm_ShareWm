/*==============================================================================
  ECON 20 Project: California SB 826 (board gender quota) and firm value
  Program 7: REDUCED FORM with ShareWm and OneWm (NOT IV; no CA, no Post)

  Input : final_data.dta   (built by 01_build_data.do)
  Output: figures/lnmktcap_sharewm_binned.png / .gph   (ShareWm, binned scatter)
          figures/lnmktcap_sharewm_byyear.png / .gph   (ShareWm, slope by year)
          figures/lnmktcap_onewm_binned.png   / .gph   (OneWm,   binned scatter)
          figures/lnmktcap_onewm_byyear.png   / .gph   (OneWm,   slope by year)

  Same code as program 4, but CA, Post and CA x Post are replaced by X:
      ln(mktcap)_it = b0 + b1*X_it + a_i + u_it,     X = ShareWm  or  OneWm
    - ShareWm = percent of the board that is women (0-100)
    - OneWm   = 1 if the board has at least one woman
    - a_i     = FIRM FIXED EFFECTS

  Three versions are shown (as in program 4):
    (1) no fixed effects
    (2) firm fixed effects            <-- your equation
    (3) firm + year fixed effects
  b1 is the coefficient on X in every column. Because the outcome is in logs,
  for OneWm b1 x 100 is approximately the percent difference in market cap; for
  ShareWm it is the percent change per 1 percentage point more women.
==============================================================================*/

clear all
set more off
cd "C:/Econ 20/proj"

capture mkdir figures
capture log close
log using "reduced_form_sharewm_onewm.log", replace text

use "final_data.dta", clear

*-------------------------------------------------------------------------------
* 0. Build the variables (same definitions as programs 3 and 4)
*    >>> CHECK: set the board-size and market-cap variable names.
*-------------------------------------------------------------------------------
local bsvar boardsize      // total number of directors
local mcvar mktcap         // market capitalization

keep if board_matched == 1

gen OneWm = (women >= 1) if women < .
label var OneWm "=1 if at least 1 woman on the board"

gen ShareWm = 100 * women / `bsvar' if women < . & `bsvar' < . & `bsvar' > 0
label var ShareWm "Percent of board that is women"

count if `mcvar' <= 0
count if missing(`mcvar')
//gen lnmktcap = ln(`mcvar') if `mcvar' > 0 & `mcvar' < .
label var lnmktcap "ln(market capitalization)"

*-------------------------------------------------------------------------------
* 1. Event-time "year" and sample
*-------------------------------------------------------------------------------
gen pyear = year(fye) + (month(fye) >= 10)
label var pyear "Policy year (runs 1 Oct - 30 Sep; pyear 2019 = first post year)"

* Settings you can change -------------------------------------------------------
local firstyr 2011
local lastyr  2025
* To show only the pre-COVID window instead, use:  keep if mainwindow == 1
* To drop the 10 firms that moved out of California (robustness):
*   drop if mover == 1
* ------------------------------------------------------------------------------

keep if pyear >= `firstyr' & pyear <= `lastyr'

* Same sample for both X's
drop if missing(OneWm, ShareWm, lnmktcap)

* gvkey is a string; areg needs a numeric id for absorb()
egen firmid = group(gvkey)

* Sanity checks: look at these before trusting any graph
tab pyear
summ lnmktcap OneWm ShareWm
corr lnmktcap OneWm ShareWm

*-------------------------------------------------------------------------------
* 2. Regressions and graphs, once for ShareWm and once for OneWm
*    areg ..., absorb(firmid) = firm fixed effects; s.e. clustered by firm.
*-------------------------------------------------------------------------------
foreach x in ShareWm OneWm {

    display _newline(2) as text "{hline 78}"
    display as text "REDUCED FORM: ln(mktcap) on `x'"
    display as text "{hline 78}"

    * (1) no fixed effects
    reg lnmktcap `x', vce(cluster gvkey)
    estimates store r1_`x'

    * (2) firm fixed effects  <-- your equation
    areg lnmktcap `x', absorb(firmid) vce(cluster gvkey)
    estimates store r2_`x'
    local b2  = _b[`x']
    local se2 = _se[`x']

    * (3) firm AND year fixed effects
    areg lnmktcap `x' i.pyear, absorb(firmid) vce(cluster gvkey)
    estimates store r3_`x'

    estimates table r1_`x' r2_`x' r3_`x', keep(`x') b(%9.4f) se(%9.4f) ///
        stats(N r2) title("Reduced form: ln(mktcap) on `x'")

    local fn = lower("`x'")
    if "`x'" == "ShareWm" {
        local xt  "Percent women on board"
        local xtr "Percent women on board (residual, after firm fixed effects)"
        local ttl "Firm Value and Percent Women on the Board"
    }
    else {
        local xt  "At least 1 woman on board"
        local xtr "At least 1 woman on board (residual, after firm fixed effects)"
        local ttl "Firm Value and Having a Woman on the Board"
    }

    *---------------------------------------------------------------------------
    * 3. MAIN GRAPH: binned partial-regression plot. ln(mktcap) and `x' are both
    *    residualized on firm fixed effects, cut into 20 bins by the residualized
    *    `x', and the bin averages are plotted with a fitted line. The slope of
    *    the line is the coefficient b1 from column (2).
    *---------------------------------------------------------------------------
    preserve
    quietly areg lnmktcap, absorb(firmid)
    predict double ry, dresiduals
    quietly areg `x', absorb(firmid)
    predict double rx, dresiduals

    xtile bin = rx, nq(20)
    collapse (mean) ry rx, by(bin)

    local bb : display %6.3f `b2'
    local ss : display %6.3f `se2'

    gr two (scatter ry rx, msize(medlarge)) ///
           (lfit ry rx), ///
        legend(off) ///
        xtitle("`xtr'") ///
        ytitle("ln(market cap) (residual, after firm fixed effects)") ///
        title("`ttl'", size(medium)) ///
        note("Binned means (20 bins), firm-year data, CA and TX firms. Slope = `bb' (clustered s.e. `ss').")
    graph export "figures/lnmktcap_`fn'_binned.png", replace width(2000)
    graph save   "figures/lnmktcap_`fn'_binned.gph", replace
    restore

    *---------------------------------------------------------------------------
    * 4. SECONDARY GRAPH (replaces the event study): the slope on `x' in each
    *    year, with firm and year fixed effects. Each point is the coefficient
    *    on `x' x 1[year = t]; the bars are 95% CIs, s.e. clustered by firm.
    *---------------------------------------------------------------------------
    forvalues t = `firstyr'/`lastyr' {
        gen xyr`t' = `x' * (pyear == `t')
    }

    areg lnmktcap xyr* i.pyear, absorb(firmid) vce(cluster gvkey)

    gen slope = .
    gen se    = .
    forvalues t = `firstyr'/`lastyr' {
        replace slope = _b[xyr`t']  if pyear == `t'
        replace se    = _se[xyr`t'] if pyear == `t'
    }

    * check the numbers before plotting
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
        ytitle("Coefficient on `xt' (outcome: ln market cap)") ///
        title("Reduced Form by Year" "ln(market cap) on `xt'", size(medium)) ///
        note("Firm-year data, CA and TX firms, firm and year fixed effects." ///
             "Bars show 95% confidence intervals, standard errors clustered by firm. Dashed line = SB 826 signed 30 Sep 2018.")
    graph export "figures/lnmktcap_`fn'_byyear.png", replace width(2000)
    graph save   "figures/lnmktcap_`fn'_byyear.gph", replace
    restore

    drop xyr* slope se
}

log close
