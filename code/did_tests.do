
clear all
set more off
cd "C:\Users\shinz\OneDrive\Desktop\Econ20 FinalProject"

capture log close
log using "did_log.log", replace text

use "final_data.dta", clear

*==============================================================
* SETUP: 2018 PRE vs. 2019-2020 POST
*==============================================================

encode gvkey, gen(firm_id)
gen fyr = fyeyear

*==============================================================
* DETRENDING: FIT CALIFORNIA-SPECIFIC TREND THROUGH 2018
*==============================================================

gen yeartrend = fyr - 2011
reg lnmktcap ca i.fyr i.ca#c.yeartrend if fyr < 2019, ///
    cluster(firm_id)

predict lnmktcap_hat, resid

*==============================================================
* TABLE 4: PRETRENDS
*==============================================================

forvalues y = 2011/2017 {
    gen ca_yr`y' = ca * (fyr == `y')
}

areg lnmktcap ca_yr2011-ca_yr2017 i.fyr ///
    if fyr >= 2011 & fyr <= 2018, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using did_table4, excel replace dec(3) ///
    keep(ca_yr2011-ca_yr2017) ///
    ctitle("(1) Pretrend coefficients") ///
    addtext(Firm FE, Yes, Year FE, Yes)

test ca_yr2011 ca_yr2012 ca_yr2013 ///
     ca_yr2014 ca_yr2015 ca_yr2016 ca_yr2017

*==============================================================
* TWO-PERIOD DID SAMPLE
* 2018 PRE; 2019 AND 2020 POST
*==============================================================

keep if fyr == 2018 | fyr == 2019 | fyr == 2020

gen post19 = (fyr >= 2019)
gen ca_post19 = ca * post19

gen onewoman = (women >= 1) if women != .
gen sharewoman = women / boardsize if women != . ///
    & boardsize != . & boardsize > 0

* Identify firms with at least one woman in 2018
gen woman_obs = (women >= 1) if fyr == 2018
bysort firm_id: egen woman18 = max(woman_obs)

*==============================================================
* TABLE 1: MAIN DID RESULTS
*==============================================================

* (1) DiD, no controls
areg lnmktcap ca_post19 i.fyr, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using did_table1, excel replace dec(3) ///
    keep(ca_post19) ///
    ctitle("(1) lnmktcap") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, No, Detrended, No)


* (2) DiD, controls
areg lnmktcap ca_post19 i.fyr ///
    lnassets roa leverage multinational, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using did_table1, excel append dec(3) ///
    keep(ca_post19 lnassets roa leverage multinational) ///
    ctitle("(2) lnmktcap") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes, Detrended, No)


* (3) Detrended DiD, no controls
areg lnmktcap_hat ca_post19 i.fyr, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using did_table1, excel append dec(3) ///
    keep(ca_post19) ///
    ctitle("(3) lnmktcap") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, No, Detrended, Yes)


* (4) Detrended DiD, controls
areg lnmktcap_hat ca_post19 i.fyr ///
    lnassets roa leverage multinational, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using did_table1, excel append dec(3) ///
    keep(ca_post19 lnassets roa leverage multinational) ///
    ctitle("(4) lnmktcap") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes, Detrended, Yes)

*==============================================================
* TABLE 2: PLACEBO TEST
* Sample: Companies with at least one woman on board in 2018
*==============================================================

* (1) No controls
areg lnmktcap ca_post19 i.fyr if woman18 == 1, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using did_table2, excel replace dec(3) ///
    keep(ca_post19) ///
    ctitle("(1) lnmktcap") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, No)

* (2) Controls
areg lnmktcap ca_post19 i.fyr ///
    lnassets roa leverage multinational if woman18 == 1, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using did_table2, excel append dec(3) ///
    keep(ca_post19 lnassets roa leverage multinational) ///
    ctitle("(2) lnmktcap") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

* (3) Detrended, with controls
areg lnmktcap_hat ca_post19 i.fyr ///
    lnassets roa leverage multinational if woman18 == 1, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using did_table2, excel append dec(3) ///
    keep(ca_post19 lnassets roa leverage multinational) ///
    ctitle("(3) lnmktcap") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes, Detrended, Yes)


*==============================================================
* TABLE 3: FIRST STAGE, REDUCED FORM, AND IV
*==============================================================
* (1) First stage: One woman

reg onewoman ca post19 ca_post19 ///
    lnassets roa leverage multinational, cluster(firm_id)

test ca_post19

outreg2 using did_table3, excel replace dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(1) First stage: One woman") ///
    addtext(Controls, Yes) ///
    addstat(First-stage F, r(F))


* (2) First stage: Share women

reg sharewoman ca post19 ca_post19 ///
    lnassets roa leverage multinational, cluster(firm_id)

test ca_post19

outreg2 using did_table3, excel append dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(2) First stage: Share women") ///
    addtext(Controls, Yes) ///
    addstat(First-stage F, r(F))


* (3) Reduced form

reg lnmktcap ca post19 ca_post19 ///
    lnassets roa leverage multinational if onewoman != ., ///
    cluster(firm_id)

outreg2 using did_table3, excel append dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(3) Reduced form") ///
    addtext(Controls, Yes)


* (4) IV: One woman

ivreg lnmktcap ca post19 ///
    lnassets roa leverage multinational ///
    (onewoman = ca_post19), cluster(firm_id)

outreg2 using did_table3, excel append dec(3) ///
    keep(onewoman ca post19) ///
    ctitle("(4) IV: One woman") ///
    addtext(Controls, Yes)


* (5) IV: Share women

ivreg lnmktcap ca post19 ///
    lnassets roa leverage multinational ///
    (sharewoman = ca_post19), cluster(firm_id)

outreg2 using did_table3, excel append dec(3) ///
    keep(sharewoman ca post19) ///
    ctitle("(5) IV: Share women") ///
    addtext(Controls, Yes)

* (6) DETRENDED IV: Share women

ivreg lnmktcap_hat ca post19 ///
    lnassets roa leverage multinational ///
    (sharewoman = ca_post19), cluster(firm_id)

outreg2 using did_table3, excel append dec(3) ///
    keep(sharewoman ca post19) ///
    ctitle("(7) Detrended IV: Share women") ///
    addtext(Controls, Yes, Detrended, Yes)


log close
