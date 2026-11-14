*==============================================================================
* 04_did_tests.do  --  MAIN RESULTS: two-period DiD tables
* Author:  Sophia (formerly code/did_tests.do)
* Purpose: Two-period difference-in-differences, fiscal year-end 2018 (pre)
*          vs 2019 (post), California vs Texas, outcome ln(market cap):
*            Table 1  main DiD (with/without controls, raw and detrended)
*            Table 2  placebo (firms with a woman on the board in 2018)
*            Table 3  first stage, reduced form and IV
*            Table 4  pre-trends (CA x year, 2010-2017, 2018 = reference)
* Input:   final_data.dta
* Outputs: output/did_table1.txt/.xml ... output/did_table4.txt/.xml
*          logs/04_did_tests.log (also holds the pre-trend joint F-test)
* Run:     do code/04_did_tests.do   (or via code/00_master.do); the header
*          below finds the project folder on any teammate's machine.
* Note:    only the folder/log/output-path lines were changed from Sophia's
*          original; every regression line is hers, unchanged.
*==============================================================================
clear all
set more off
* --- Project folder (standard header, same in every script) -----------------
* Uses global PROJ if set (00_master.do sets it); otherwise the current folder
* if it has final_data.dta; otherwise the first teammate folder below that has
* it. Nothing to edit: if none match, cd to the project folder first, or set
*   global PROJ "C:/path/to/project"
if `"$PROJ"' != "" cd `"$PROJ"'
capture confirm file "final_data.dta"
if _rc & `"$PROJ"' == "" {
    foreach d in "~/Desktop/Dartmouth Classes/Economics/ECON20/project" ///
                 "C:/Users/shinz/OneDrive/Desktop/Econ20 FinalProject" ///
                 "/Users/joseohui/Desktop/UIC/Dartmouth/Fall/Econometrics/JESAS/project" ///
                 "C:/Econ 20/proj" {
        capture confirm file "`d'/final_data.dta"
        if !_rc {
            cd "`d'"
            continue, break
        }
    }
}
capture confirm file "final_data.dta"
if _rc {
    di as error "final_data.dta not found. cd to the project folder, or run"
    di as error `"  global PROJ "C:/path/to/project""'
    di as error "and then run this do-file again."
    exit 601
}
capture mkdir "logs"
capture mkdir "output"
capture mkdir "output/figures"
* ---------------------------------------------------------------------------

capture log close
log using "logs/04_did_tests.log", replace text

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

outreg2 using output/did_table4, excel replace dec(3) ///
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

ivregress 2sls lnmktcap ca post19 lnassets roa leverage multinational ///
    (onewoman = ca_post19), vce(cluster firm_id)
outreg2 using output/did_table3, excel append dec(3) ///
    keep(onewoman ca post19) ///
    ctitle("(4) IV: One woman") addtext(Controls, Yes)

ivregress 2sls lnmktcap ca post19 lnassets roa leverage multinational ///
    (sharewoman = ca_post19), vce(cluster firm_id)
outreg2 using output/did_table3, excel append dec(3) ///
    keep(sharewoman ca post19) ///
    ctitle("(5) IV: Share women") addtext(Controls, Yes)

log close
