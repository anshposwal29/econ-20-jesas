*==============================================================================
* 06_panel_tables.do  --  PANEL DiD TABLES (firm and year fixed effects)
* Author:  Sophia (formerly code/paneldata_outreg2.do)
* Purpose: Panel version with firm and year FE, fiscal years through 2020:
*            table2_main      main DiD (no controls, controls, detrended)
*            table2_plcbo     firms with a woman on the board in 2017
*                             (written with "append": 00_master.do erases it
*                             first so reruns do not duplicate columns)
*            table3_pretrend  pre-trends, pre-law years, 2017 = reference
*            table4_iv        first stage, reduced form, IV
* Input:   final_data.dta
* Outputs: output/table2_main, output/table2_plcbo, output/table3_pretrend,
*          output/table4_iv  (.txt and .xml each); logs/06_panel_tables.log
* Run:     do code/06_panel_tables.do   (or via code/00_master.do)
* Note:    only the folder/log/output-path lines were changed from Sophia's
*          original; every regression and detrending line is hers, unchanged.
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
log using "logs/06_panel_tables.log", replace text

use "final_data.dta", clear

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
drop if fyr>2020
tab fyr, gen(fyeardum)
xtset firm_id

*==============================================================
* TABLE 2: Main difference-in-differences results (ln market cap)
*==============================================================

* (1) No controls
xtreg lnmktcap ca_post fyeardum*, fe cluster(firm_id)
outreg2 using output/table2_main, excel replace dec(3) ///
	drop(fyeardum* o.fyeardum*) ///
    ctitle("(1) No controls") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, No)

* (2) With controls
xtreg lnmktcap ca_post fyeardum* lnassets roa leverage multinational, fe cluster(firm_id)
outreg2 using output/table2_main, excel append dec(3) ///
	drop(fyeardum* o.fyeardum*) ///
    ctitle("(2) Controls") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

* (3) Detrended outcome: remove a California-specific linear trend estimated pre-law
gen ca_year = ca*fyr
reg lnmktcap ca fyeardum* ca_year if post==0, cluster(firm_id)
predict lnmktcap_hat, resid

xtreg lnmktcap_hat ca_post fyeardum* lnassets roa leverage multinational, fe cluster(firm_id)
outreg2 using output/table2_main, excel append drop(fyeardum* o.fyeardum*) dec(3) ///
	ctitle("(3) Detrended") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

* (4) Firms that already had a woman on the board before the law (fyr 2017)
gen woman_pre_obs = (women >= 1) if fyr==2017
bysort firm_id: egen woman_pre = max(woman_pre_obs)

xtreg lnmktcap ca_post fyeardum* lnassets roa leverage multinational if woman_pre==1, fe cluster(firm_id)
outreg2 using output/table2_plcbo, excel append drop(fyeardum* o.fyeardum*) dec(3) ///
	ctitle("(4) Woman pre-law") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

* (5) Same subsample, detrended
reg lnmktcap ca fyeardum* ca_year if post==0 & woman_pre==1, cluster(firm_id)
predict lnmktcap_hat_w if woman_pre==1, resid

xtreg lnmktcap_hat_w ca_post fyeardum* lnassets roa leverage multinational if woman_pre==1, fe cluster(firm_id)
outreg2 using output/table2_plcbo, excel append dec(3) ///
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
outreg2 using output/table3_pretrend, excel replace keep(ca_yr*) dec(3) ///
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
outreg2 using output/table4_iv, excel replace drop(fyeardum*) dec(3) ///
    ctitle("(1) First stage", "One woman") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes) ///
    addstat(First-stage F, r(F))

* (2) First stage: share of women
xtreg sharewoman ca_post lnassets roa leverage multinational if fyeyear < 2020, fe cluster(firm_id)
test ca_post
outreg2 using output/table4_iv, excel append drop(fyeardum* o.fyeardum*) dec(3) ///
    ctitle("(2) First stage", "Share women") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes) ///
    addstat(First-stage F, r(F))

* (3) Reduced form, same sample as the first stages
xtreg lnmktcap ca_post fyeardum* lnassets roa leverage multinational if onewoman ~= ., fe cluster(firm_id)
outreg2 using output/table4_iv, excel append drop(fyeardum* o.fyeardum*) dec(3) ///
    ctitle("(3) Reduced form", "ln(mkt cap)") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

* (4) IV: one woman
xtivreg lnmktcap fyeardum* lnassets roa leverage multinational (onewoman = ca_post), fe vce(cluster firm_id)
outreg2 using output/table4_iv, excel append drop(fyeardum* o.fyeardum*) dec(3) ///
    ctitle("(4) IV", "ln(mkt cap)") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

* (5) IV: share of women
xtivreg lnmktcap fyeardum* lnassets roa leverage multinational (sharewoman = ca_post), fe vce(cluster firm_id)
outreg2 using output/table4_iv, excel append drop(fyeardum* o.fyeardum*) dec(3) ///
    ctitle("(5) IV", "ln(mkt cap)") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

log close
