/*==============================================================================
  ECON 20 Project: California SB 826 (board gender quota) and firm value
  Program 4: EVENT STUDY GRAPHS WITH FIRM FE AND INDUSTRY-BY-YEAR FE
             (reduced form and first stage of the share-of-women IV)

  Input : final_data.dta   (built by 01_build_data.do)
  Output: output/figures/es_lnmktcap_fe.png / .gph   reduced form: ln(market cap)
          output/figures/es_sharewm_fe.png  / .gph   first stage: % women on board
          output/figures/means_lnmktcap.png / .gph   raw means by state (companion)
          output/figures/means_sharewm.png  / .gph   raw means by state (companion)
          logs/04_event_study_fe.log

  Builds on Eloise's code/Graph_and_EventStudy and code/FirstStageShareWm.
  Changes from those:
    - firm fixed effects (absorb gvkey): coefficients compare each firm with
      itself, so firms entering or leaving the sample do not move them
    - 2-digit SIC industry x year fixed effects: CA firms are compared with TX
      firms in the same industry and year (removes oil-price shocks to TX
      energy firms and tech-cycle shocks to CA tech firms)
    - window is policy years 2011-2021 (fiscal year-ends Oct 2010 - Sep 2021)
    - the reduced form and first stage use the same firm-years (board data
      and market cap both present), so the IV is ratio of the two

  Event study:  y_it = sum_{t != 2018} d_t (CA_i x 1[pyear = t])
                       + a_i + g_{industry, t} + u_it
  d_t = CA - TX gap in year t minus the gap in 2018, within industry-year.
  Standard errors clustered by firm.
==============================================================================*/

clear all
set more off
cd "~/Desktop/Dartmouth Classes/Economics/ECON20/project"

capture mkdir "output/figures"
capture log close
log using "logs/04_event_study_fe.log", replace text

use "final_data.dta", clear

*-------------------------------------------------------------------------------
* 0. Variables and sample
*-------------------------------------------------------------------------------
* ShareWm = percent of the board that is women (0-100), as in FirstStageShareWm
gen ShareWm = 100 * women / boardsize if women < . & boardsize < . & boardsize > 0
label var ShareWm "Women as % of board"

* policy year runs 1 Oct - 30 Sep; pyear 2019 = first post year
gen pyear = year(fye) + (month(fye) >= 10)
assert (pyear >= 2019) == post

local refyr   2018
local firstyr 2011
local lastyr  2021
keep if inrange(pyear, `firstyr', `lastyr')

* same firm-years for both outcomes
keep if ShareWm < . & lnmktcap < .

egen ind = group(sic2)
label var ind "2-digit SIC industry"

tab pyear ca
quietly levelsof gvkey
di "Firm-years: " _N "   Firms: " r(r)
quietly levelsof sic2
di "2-digit SIC industries: " r(r)

*-------------------------------------------------------------------------------
* 1. CA x year interactions (2018 omitted)
*-------------------------------------------------------------------------------
forvalues t = `firstyr'/`lastyr' {
    if `t' != `refyr' {
        gen caXyr`t' = ca * (pyear == `t')
    }
}
local pretest ""
forvalues t = `firstyr'/`=`refyr'-1' {
    local pretest `pretest' caXyr`t'
}

*-------------------------------------------------------------------------------
* 2. Event studies: firm FE (absorbed) + industry x year FE, cluster by firm
*-------------------------------------------------------------------------------
foreach v in lnmktcap ShareWm {

    if "`v'" == "lnmktcap" {
        local ttl  "Reduced Form: ln(Market Cap)"
        local ylab "CA - TX difference in ln(market cap)"
    }
    if "`v'" == "ShareWm" {
        local ttl  "First Stage: Women as % of Board"
        local ylab "CA - TX difference in % women on board"
    }

    di _n "=================== Event study: `v' ==================="
    areg `v' caXyr* i.ind#i.pyear, absorb(gvkey) vce(cluster gvkey)
    di _n "Joint test of no pre-trends (`v'):"
    test `pretest'
    local p_pre = r(p)

    preserve
    clear
    set obs `=`lastyr' - `firstyr' + 1'
    gen pyear = `firstyr' + _n - 1
    gen slope = 0                    // reference year = 0, no CI
    gen se    = .
    forvalues t = `firstyr'/`lastyr' {
        if `t' != `refyr' {
            replace slope = _b[caXyr`t']  if pyear == `t'
            replace se    = _se[caXyr`t'] if pyear == `t'
        }
    }
    gen upper = slope + 1.96*se
    gen lower = slope - 1.96*se
    list pyear slope se, noobs clean

    gr two (rcap upper lower pyear, lcolor(cranberry)) ///
           (scatter slope pyear, mcolor(navy) msymbol(circle)), ///
        yline(0, lc(black)) xline(2018.5, lp(dash) lc(gs6)) ///
        legend(off) ///
        xlabel(`firstyr'(1)`lastyr') ///
        xtitle("Policy year (runs 1 Oct - 30 Sep; 2019 = first year after SB 826)") ///
        ytitle("`ylab'" "relative to 2018") ///
        title("`ttl'" "Firm and Industry-by-Year Fixed Effects", size(medium)) ///
        note("CA vs. TX firm-years with board data. Firm FE and 2-digit SIC x year FE; 2018 is the omitted year." ///
             "95% CIs, SEs clustered by firm. Pre-trend joint test p = `: di %4.3f `p_pre''. Dashed line = SB 826 signed 30 Sep 2018.")
    graph export "output/figures/es_`v'_fe.png", replace width(2000)
    graph save   "output/figures/es_`v'_fe.gph", replace
    restore
}

*-------------------------------------------------------------------------------
* 3. Companion graphs: raw means by state and year, 95% CIs
*    (no fixed effects -- these show the levels behind the event studies)
*    CA is shifted 0.08 left and TX 0.08 right so the bars do not overlap.
*-------------------------------------------------------------------------------
foreach v in lnmktcap ShareWm {
    if "`v'" == "lnmktcap" local ylab "Mean ln(market cap, $ millions)"
    if "`v'" == "ShareWm"  local ylab "Mean women as % of board"
    if "`v'" == "lnmktcap" local ttl  "Mean ln(Market Cap), California vs. Texas"
    if "`v'" == "ShareWm"  local ttl  "Women as % of Board, California vs. Texas"

    preserve
    collapse (mean) m=`v' (semean) s=`v', by(ca pyear)
    gen upper = m + 1.96*s
    gen lower = m - 1.96*s
    gen x = pyear + cond(ca == 1, -0.08, 0.08)

    gr two (rcap upper lower x if ca==1, lcolor(navy)) ///
           (rcap upper lower x if ca==0, lcolor(cranberry)) ///
           (connected m x if ca==1, lcolor(navy) mcolor(navy)) ///
           (connected m x if ca==0, lcolor(cranberry) mcolor(cranberry) msymbol(square)), ///
        xline(2018.5, lp(dash) lc(gs6)) ///
        legend(order(3 "California" 4 "Texas") rows(1) position(6)) ///
        xlabel(`firstyr'(1)`lastyr') ///
        xtitle("Policy year (runs 1 Oct - 30 Sep; 2019 = first year after SB 826)") ///
        ytitle("`ylab'") ///
        title("`ttl'", size(medium)) ///
        note("Raw means, no fixed effects. Same firm-years as the event studies. Bars show 95% CIs." ///
             "The set of firms changes over time (e.g. new CA biotech listings after 2018).")
    graph export "output/figures/means_`v'.png", replace width(2000)
    graph save   "output/figures/means_`v'.gph", replace
    restore
}

log close
