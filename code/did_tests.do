clear all
set more off
cd "C:\Users\shinz\OneDrive\Desktop\Econ20 FinalProject"

capture log close
log using "did_log.log", replace text

use "final_data.dta", clear

*==============================================================
* SETUP: two-period DiD, fiscal year end 2018 (pre) vs 2019 (post)
*==============================================================
encode gvkey, gen(firm_id)

gen fyr = fyeyear

* Detrending: fit CA-specific linear trend on pre-law years (before 2018), then take residuals
gen ca_year = ca*fyr
reg lnmktcap ca i.fyr ca_year if fyr < 2018, cluster(firm_id)
predict lnmktcap_hat, resid
*==============================================================
* TABLE 4: Pretrends
*==============================================================

* Generate California x year interactions
forvalues y = 2010/2017 {
    gen ca_yr`y' = ca * (fyr == `y')
}
areg lnmktcap ca_yr2010-ca_yr2017 i.fyr ///
    if fyr >= 2010 & fyr <= 2018, ///
    absorb(firm_id) vce(cluster firm_id)

outreg2 using did_table4, excel replace dec(3) ///
    keep(ca_yr2010-ca_yr2017) ///
    ctitle("(1) Pretrend coefficients") ///
    addtext(Firm FE, Yes, Year FE, Yes)
	
test ca_yr2010 ca_yr2011 ca_yr2012 ca_yr2013 ///
     ca_yr2014 ca_yr2015 ca_yr2016 ca_yr2017

*==================================================================
* TWO-PERIOD DID SAMPLE
*==================================================================
keep if fyr==2018 | fyr==2019

gen post19    = (fyr==2019)
gen ca_post19 = ca*post19

gen onewoman   = (women >= 1) if women ~= .
gen sharewoman = women / boardsize if women ~= . & boardsize ~= . & boardsize > 0

gen woman_obs = (women >= 1) if fyr==2018
bysort firm_id: egen woman18 = max(woman_obs)


*==============================================================
* TABLE 1: MAIN DiD RESULTS
* (1) DiD, no controls
* (2) DiD, controls
* (3) Detrended DiD, no controls
* (4) Detrended DiD, controls
*==============================================================

reg lnmktcap ca post19 ca_post19, cluster(firm_id)
outreg2 using did_table1, excel replace dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(1) lnmktcap") addtext(Controls, No, Detrended, No)

reg lnmktcap ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
outreg2 using did_table1, excel append dec(3) ///
    keep(ca post19 ca_post19 lnassets roa leverage multinational) ///
    ctitle("(2) lnmktcap") addtext(Controls, Yes, Detrended, No)

reg lnmktcap_hat ca post19 ca_post19, cluster(firm_id)
outreg2 using did_table1, excel append dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(3) lnmktcap") addtext(Controls, No, Detrended, Yes)

reg lnmktcap_hat ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
outreg2 using did_table1, excel append dec(3) ///
    keep(ca post19 ca_post19 lnassets roa leverage multinational) ///
    ctitle("(4) lnmktcap") addtext(Controls, Yes, Detrended, Yes)


*==============================================================
* TABLE 2: PLACEBO TEST
* Sample: Companies with at least one woman on board in 2018
* (1) No controls
* (2) Controls
* (3) Detrended
*==============================================================

reg lnmktcap ca post19 ca_post19 if woman18==1, cluster(firm_id)
outreg2 using did_table2, excel replace dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(1) Placebo") addtext(Controls, No, Detrended, No)

reg lnmktcap ca post19 ca_post19 lnassets roa leverage multinational if woman18==1, cluster(firm_id)
outreg2 using did_table2, excel append dec(3) ///
    keep(ca post19 ca_post19 lnassets roa leverage multinational) ///
    ctitle("(2) Placebo") addtext(Controls, Yes, Detrended, No)

reg lnmktcap_hat ca post19 ca_post19 lnassets roa leverage multinational if woman18==1, cluster(firm_id)
outreg2 using did_table2, excel append dec(3) ///
    keep(ca post19 ca_post19 lnassets roa leverage multinational) ///
    ctitle("(3) Placebo") addtext(Controls, Yes, Detrended, Yes)


*==============================================================
* TABLE 3: FIRST STAGE, REDUCED FORM, AND IV
* (1) First stage: One woman
* (2) First stage: Share women
* (3) Reduced form
* (4) IV: One woman
* (5) IV: Share women
*==============================================================

reg onewoman ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
test ca_post19
outreg2 using did_table3, excel replace dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(1) First stage: One woman") addtext(Controls, Yes) ///
    addstat(First-stage F, r(F))

reg sharewoman ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
test ca_post19
outreg2 using did_table3, excel append dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(2) First stage: Share women") addtext(Controls, Yes) ///
    addstat(First-stage F, r(F))

reg lnmktcap ca post19 ca_post19 lnassets roa leverage multinational if onewoman ~= ., cluster(firm_id)
outreg2 using did_table3, excel append dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(3) Reduced form") addtext(Controls, Yes)

ivregress 2sls lnmktcap ca post19 lnassets roa leverage multinational ///
    (onewoman = ca_post19), vce(cluster firm_id)
outreg2 using did_table3, excel append dec(3) ///
    keep(onewoman ca post19) ///
    ctitle("(4) IV: One woman") addtext(Controls, Yes)

ivregress 2sls lnmktcap ca post19 lnassets roa leverage multinational ///
    (sharewoman = ca_post19), vce(cluster firm_id)
outreg2 using did_table3, excel append dec(3) ///
    keep(sharewoman ca post19) ///
    ctitle("(5) IV: Share women") addtext(Controls, Yes)

log close
