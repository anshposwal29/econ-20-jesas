clear all
set more off
cd "/Users/joseohui/Desktop/UIC/Dartmouth/Fall/Econometrics/JESAS"

capture log close
log using "test.log", replace text

use "/Users/joseohui/Desktop/UIC/Dartmouth/Fall/Econometrics/JESAS/project/raw/final_data.dta", clear

*==============================================================
* SETUP
*==============================================================
encode gvkey, gen(firm_id)

* fyr = calendar year of the fiscal year end (works whether fyeyear is a year or a date)
quietly summarize fyeyear
if r(max) > 3000 {
    gen fyr = year(fyeyear)
}
else {
    gen fyr = fyeyear
}
tab fyr

* Year dummies from fyr. xtset on firm only, because two fiscal year ends
* can fall in the same calendar year for a firm, which would break xtset firm fyr
tab fyr, gen(fyeardum)
xtset firm_id

*==============================================================
* TABLE 2: Main difference-in-differences results (ln market cap)
*==============================================================

* (1) No controls
xtreg lnmktcap ca_post fyeardum*, fe cluster(firm_id)
outreg2 using table2_main, excel replace dec(3) ///
	drop(fyeardum* o.fyeardum*) ///
    ctitle("(1) No controls") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, No)

* (2) With controls
xtreg lnmktcap ca_post fyeardum* lnassets roa leverage multinational, fe cluster(firm_id)
outreg2 using table2_main, excel append dec(3) ///
	drop(fyeardum* o.fyeardum*) ///
    ctitle("(2) Controls") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

* (3) Detrended outcome: remove a California-specific linear trend estimated pre-law
gen ca_year = ca*fyr
reg lnmktcap ca fyeardum* ca_year if post==0, cluster(firm_id)
predict lnmktcap_hat, resid

xtreg lnmktcap_hat ca_post fyeardum* lnassets roa leverage multinational, fe cluster(firm_id)
outreg2 using table2_main, excel append drop(fyeardum* o.fyeardum*) dec(3) ///
	ctitle("(3) Detrended") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

* (4) Firms that already had a woman on the board before the law (fyr 2017)
gen woman_pre_obs = (women >= 1) if fyr==2017
bysort firm_id: egen woman_pre = max(woman_pre_obs)

xtreg lnmktcap ca_post fyeardum* lnassets roa leverage multinational if woman_pre==1, fe cluster(firm_id)
outreg2 using table2_main, excel append drop(fyeardum* o.fyeardum*) dec(3) ///
	ctitle("(4) Woman pre-law") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

* (5) Same subsample, detrended
reg lnmktcap ca fyeardum* ca_year if post==0 & woman_pre==1, cluster(firm_id)
predict lnmktcap_hat_w if woman_pre==1, resid

xtreg lnmktcap_hat_w ca_post fyeardum* lnassets roa leverage multinational if woman_pre==1, fe cluster(firm_id)
outreg2 using table2_main, excel append dec(3) ///
    drop(fyeardum* o.fyeardum*) ///
	ctitle("(5) Woman pre-law, detrended") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

*==============================================================
* TABLE 3: Pre-trend (event study), pre-law years only, 2017 = reference
*==============================================================
forvalues y = 2010/2016 {
    gen ca_yr`y' = ca * (fyr == `y')
}

xtreg lnmktcap ca_yr2010-ca_yr2016 i.fyr if fyr <= 2017, fe cluster(firm_id)
test ca_yr2010 ca_yr2011 ca_yr2012 ca_yr2013 ca_yr2014 ca_yr2015 ca_yr2016
outreg2 using table3_pretrend, excel replace keep(ca_yr*) dec(3) ///
    ctitle("ln(market cap)") ///
    addtext(Firm FE, Yes, Year FE, Yes) ///
    addstat(Joint F-test, r(F), p-value, r(p))

*==============================================================
* TABLE 4: Instrumental variables (CA x Post instruments board gender)
*==============================================================
gen onewoman = (women >= 1) if women ~= .
gen sharewoman = women / boardsize if women ~= . & boardsize ~= . & boardsize > 0

* (1) First stage: at least one woman
xtreg onewoman ca_post lnassets roa leverage multinational if fyeyear < 2020, fe cluster(firm_id)
test ca_post
outreg2 using table4_iv, excel replace drop(fyeardum*) dec(3) ///
    ctitle("(1) First stage", "One woman") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes) ///
    addstat(First-stage F, r(F))

* (2) First stage: share of women
xtreg sharewoman ca_post lnassets roa leverage multinational if fyeyear < 2020, fe cluster(firm_id)
test ca_post
outreg2 using table4_iv, excel append drop(fyeardum* o.fyeardum*) dec(3) ///
    ctitle("(2) First stage", "Share women") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes) ///
    addstat(First-stage F, r(F))

* (3) Reduced form, same sample as the first stages
xtreg lnmktcap ca_post fyeardum* lnassets roa leverage multinational if onewoman ~= ., fe cluster(firm_id)
outreg2 using table4_iv, excel append drop(fyeardum* o.fyeardum*) dec(3) ///
    ctitle("(3) Reduced form", "ln(mkt cap)") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

* (4) IV: one woman
xtivreg lnmktcap fyeardum* lnassets roa leverage multinational (onewoman = ca_post), fe vce(cluster firm_id)
outreg2 using table4_iv, excel append drop(fyeardum* o.fyeardum*) dec(3) ///
    ctitle("(4) IV", "ln(mkt cap)") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

* (5) IV: share of women
xtivreg lnmktcap fyeardum* lnassets roa leverage multinational (sharewoman = ca_post), fe vce(cluster firm_id)
outreg2 using table4_iv, excel append drop(fyeardum* o.fyeardum*) dec(3) ///
    ctitle("(5) IV", "ln(mkt cap)") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)
	
*==============================================================
* EVENT STUDIES: ORIGINAL vs DETRENDED (fiscal years 2011-2021, ref = 2017)
*==============================================================
capture mkdir figures
local firstyr 2011
local lastyr  2021
local refyr   2017

* Detrended first-stage outcome, same command as the do-file uses for lnmktcap
* (lnmktcap_hat already exists from Table 2, column 3)
capture drop onewoman_hat
reg onewoman ca fyeardum* ca_year if post==0, cluster(firm_id)
predict onewoman_hat, resid

capture drop evCA*
forvalues t = `firstyr'/`lastyr' {
    if `t' != `refyr' {
        gen evCA`t' = ca * (fyr == `t')
    }
}

foreach y in onewoman lnmktcap {

    * original (o) and detrended (d) event studies, same sample
    foreach v in `y' `y'_hat {
        local s = cond("`v'" == "`y'", "o", "d")

        xtreg `v' evCA* i.fyr if onewoman ~= . & fyr >= `firstyr' & fyr <= `lastyr', ///
            fe cluster(firm_id)

        capture drop b_`s' se_`s'
        gen b_`s'  = 0
        gen se_`s' = .
        forvalues t = `firstyr'/`lastyr' {
            if `t' != `refyr' {
                replace b_`s'  = _b[evCA`t']  if fyr == `t'
                replace se_`s' = _se[evCA`t'] if fyr == `t'
            }
        }
    }

    if "`y'" == "onewoman" {
        local ttl "First Stage Event Study"
        local yt  "CA - TX difference in P(at least 1 woman), relative to 2017"
    }
    else {
        local ttl "Reduced Form Event Study"
        local yt  "CA - TX difference in ln(market cap), relative to 2017"
    }

    preserve
    keep if fyr >= `firstyr' & fyr <= `lastyr'
    collapse (mean) b_o se_o b_d se_d, by(fyr)
    foreach s in o d {
        gen up_`s' = b_`s' + 1.96*se_`s'
        gen lo_`s' = b_`s' - 1.96*se_`s'
    }
    gen x_o = fyr - 0.12
    gen x_d = fyr + 0.12

    gr two (rcap up_o lo_o x_o, lc(gs11)) (scatter b_o x_o, mc(gs8) ms(Oh)) ///
           (rcap up_d lo_d x_d, lc(cranberry)) (scatter b_d x_d, mc(blue) ms(O)), ///
        yline(0, lc(black) lp(dash)) xline(2017.5, lp(dash) lc(black)) ///
        legend(order(2 "Original" 4 "Detrended (CA linear pre-trend removed)") ring(0) pos(11)) ///
        xlabel(`firstyr'(2)`lastyr') ///
        xtitle("Fiscal year (calendar year of fiscal year end; SB 826 applies from FY2018)") ///
        ytitle("`yt'") ///
        title("`ttl'" "California SB 826: Original vs. Detrended", size(medium)) ///
        note("CA-specific linear trend estimated on pre-law observations (post==0) and removed from the outcome." ///
             "Bars show 95% CIs, standard errors clustered by firm. Dashed line = SB 826 signed 30 Sep 2018.")
    graph export "figures/es_`y'_overlay.png", replace width(2000)
	graph save   "figures/es_`y'_overlay.gph", replace
    restore
}

log close
