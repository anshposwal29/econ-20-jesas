*==============================================================================
* 04_did_tests.do -- main results: two-period DiD, CA vs TX, 2018 (pre) vs 2019 (post)
* Author: Sophia (was code/did_tests.do)
* Tables: 1 main DiD, 2 placebo (woman on board in 2018), 3 first stage / IV,
*         4 pre-trends (2010-2017, 2018 = reference)
* Input:  final_data.dta
* Output: output/did_table1-4 (.txt/.xml), logs/04_did_tests.log (has the pre-trend F-test)
* Only the header, folder lines and comments were changed; the code is Sophia's.
*==============================================================================
cap log close
clear
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
log using "logs/04_did_tests.log", replace text

use "final_data.dta", clear

*==============================================================
* SETUP: two-period DiD, fiscal year end 2018 (pre) vs 2019 (post)
*==============================================================
encode gvkey, gen(firm_id)

gen fyr = fyeyear

* Detrending: fit a CA-specific linear trend on the years before 2018, keep the residuals
gen ca_year = ca*fyr
* not from class: i.fyr = year dummies (same fit as tab fyr, gen(yrdum)); kept as Sophia wrote it
reg lnmktcap ca i.fyr ca_year if fyr < 2018, cluster(firm_id)
predict lnmktcap_hat, resid
*==============================================================
* TABLE 4: Pretrends
*==============================================================

* Generate California x year interactions
forvalues y = 2010/2017 {
    gen ca_yr`y' = ca * (fyr == `y')
}
* not from class: i.fyr = year dummies, vce(cluster firm_id) = cluster(firm_id); kept as Sophia wrote it
areg lnmktcap ca_yr2010-ca_yr2017 i.fyr ///
    if fyr >= 2010 & fyr <= 2018, ///
    absorb(firm_id) vce(cluster firm_id)

outreg2 using output/did_table4, excel replace dec(3) ///
    keep(ca_yr2010-ca_yr2017) ///
    ctitle("(1) Pretrend coefficients") ///
    addtext(Firm FE, Yes, Year FE, Yes)
	
* joint F-test that all pre-trend coefficients are zero
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

* woman18 = 1 if the firm had at least one woman on its board in 2018
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
outreg2 using output/did_table1, excel replace dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(1) lnmktcap") addtext(Controls, No, Detrended, No)

reg lnmktcap ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
outreg2 using output/did_table1, excel append dec(3) ///
    keep(ca post19 ca_post19 lnassets roa leverage multinational) ///
    ctitle("(2) lnmktcap") addtext(Controls, Yes, Detrended, No)

reg lnmktcap_hat ca post19 ca_post19, cluster(firm_id)
outreg2 using output/did_table1, excel append dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(3) lnmktcap") addtext(Controls, No, Detrended, Yes)

reg lnmktcap_hat ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
outreg2 using output/did_table1, excel append dec(3) ///
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
outreg2 using output/did_table2, excel replace dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(1) Placebo") addtext(Controls, No, Detrended, No)

reg lnmktcap ca post19 ca_post19 lnassets roa leverage multinational if woman18==1, cluster(firm_id)
outreg2 using output/did_table2, excel append dec(3) ///
    keep(ca post19 ca_post19 lnassets roa leverage multinational) ///
    ctitle("(2) Placebo") addtext(Controls, Yes, Detrended, No)

reg lnmktcap_hat ca post19 ca_post19 lnassets roa leverage multinational if woman18==1, cluster(firm_id)
outreg2 using output/did_table2, excel append dec(3) ///
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
outreg2 using output/did_table3, excel replace dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(1) First stage: One woman") addtext(Controls, Yes) ///
    addstat(First-stage F, r(F))

reg sharewoman ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
test ca_post19
outreg2 using output/did_table3, excel append dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(2) First stage: Share women") addtext(Controls, Yes) ///
    addstat(First-stage F, r(F))

reg lnmktcap ca post19 ca_post19 lnassets roa leverage multinational if onewoman ~= ., cluster(firm_id)
outreg2 using output/did_table3, excel append dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(3) Reduced form") addtext(Controls, Yes)

* not from class: ivregress 2sls is the newer ivreg (its clustered SEs differ slightly); kept as Sophia wrote it
ivregress 2sls lnmktcap ca post19 lnassets roa leverage multinational ///
    (onewoman = ca_post19), vce(cluster firm_id)
outreg2 using output/did_table3, excel append dec(3) ///
    keep(onewoman ca post19) ///
    ctitle("(4) IV: One woman") addtext(Controls, Yes)

* not from class: ivregress 2sls is the newer ivreg (its clustered SEs differ slightly); kept as Sophia wrote it
ivregress 2sls lnmktcap ca post19 lnassets roa leverage multinational ///
    (sharewoman = ca_post19), vce(cluster firm_id)
outreg2 using output/did_table3, excel append dec(3) ///
    keep(sharewoman ca post19) ///
    ctitle("(5) IV: Share women") addtext(Controls, Yes)

log close
