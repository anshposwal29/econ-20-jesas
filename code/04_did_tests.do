*==============================================================================
* 04_did_tests.do -- main results: DiD, placebo and IV, CA vs TX,
*                    fiscal year 2018 (pre) vs 2019 and 2020 (post)
* Author: Sophia (code/did_tests.do, version of 17 Nov)
* Tables in the paper: Table 2 pre-trends (did_table4), Table 3 main DiD (did_table1),
*         Table 4 placebo (did_table2), Table 5 first stage / reduced form / IV (did_table3)
* Input:  final_data.dta
* Output: output/did_table1-4 (.txt/.xml, and .tex for the LaTeX paper), logs/04_did_tests.log
* Only the header, folder lines and the outreg2 file names were changed; the code is Sophia's.
* tex(frag) in outreg2 writes a LaTeX copy of each table (same numbers as the Excel one).
*==============================================================================
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
log using "logs/04_did_tests.log", replace text

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

outreg2 using output/did_table4, excel tex(frag) replace dec(3) ///
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

outreg2 using output/did_table1, excel tex(frag) replace dec(3) ///
    keep(ca_post19) ///
    ctitle("(1) lnmktcap") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, No, Detrended, No)


* (2) DiD, controls
areg lnmktcap ca_post19 i.fyr ///
    lnassets roa leverage multinational, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using output/did_table1, excel tex(frag) append dec(3) ///
    keep(ca_post19 lnassets roa leverage multinational) ///
    ctitle("(2) lnmktcap") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes, Detrended, No)


* (3) Detrended DiD, no controls
areg lnmktcap_hat ca_post19 i.fyr, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using output/did_table1, excel tex(frag) append dec(3) ///
    keep(ca_post19) ///
    ctitle("(3) lnmktcap") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, No, Detrended, Yes)


* (4) Detrended DiD, controls
areg lnmktcap_hat ca_post19 i.fyr ///
    lnassets roa leverage multinational, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using output/did_table1, excel tex(frag) append dec(3) ///
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

outreg2 using output/did_table2, excel tex(frag) replace dec(3) ///
    keep(ca_post19) ///
    ctitle("(1) lnmktcap") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, No)

* (2) Controls
areg lnmktcap ca_post19 i.fyr ///
    lnassets roa leverage multinational if woman18 == 1, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using output/did_table2, excel tex(frag) append dec(3) ///
    keep(ca_post19 lnassets roa leverage multinational) ///
    ctitle("(2) lnmktcap") ///
    addtext(Firm FE, Yes, Year FE, Yes, Controls, Yes)

* (3) Detrended, with controls
areg lnmktcap_hat ca_post19 i.fyr ///
    lnassets roa leverage multinational if woman18 == 1, ///
    absorb(firm_id) cluster(firm_id)

outreg2 using output/did_table2, excel tex(frag) append dec(3) ///
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

outreg2 using output/did_table3, excel tex(frag) replace dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(1) First stage: One woman") ///
    addtext(Controls, Yes) ///
    addstat(First-stage F, r(F))


* (2) First stage: Share women

reg sharewoman ca post19 ca_post19 ///
    lnassets roa leverage multinational, cluster(firm_id)

test ca_post19

outreg2 using output/did_table3, excel tex(frag) append dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(2) First stage: Share women") ///
    addtext(Controls, Yes) ///
    addstat(First-stage F, r(F))


* (3) Reduced form

reg lnmktcap ca post19 ca_post19 ///
    lnassets roa leverage multinational if onewoman != ., ///
    cluster(firm_id)

outreg2 using output/did_table3, excel tex(frag) append dec(3) ///
    keep(ca post19 ca_post19) ///
    ctitle("(3) Reduced form") ///
    addtext(Controls, Yes)


* (4) IV: One woman

ivreg lnmktcap ca post19 ///
    lnassets roa leverage multinational ///
    (onewoman = ca_post19), cluster(firm_id)

outreg2 using output/did_table3, excel tex(frag) append dec(3) ///
    keep(onewoman ca post19) ///
    ctitle("(4) IV: One woman") ///
    addtext(Controls, Yes)


* (5) IV: Share women

ivreg lnmktcap ca post19 ///
    lnassets roa leverage multinational ///
    (sharewoman = ca_post19), cluster(firm_id)

outreg2 using output/did_table3, excel tex(frag) append dec(3) ///
    keep(sharewoman ca post19) ///
    ctitle("(5) IV: Share women") ///
    addtext(Controls, Yes)

* (6) DETRENDED IV: Share women

ivreg lnmktcap_hat ca post19 ///
    lnassets roa leverage multinational ///
    (sharewoman = ca_post19), cluster(firm_id)

outreg2 using output/did_table3, excel tex(frag) append dec(3) ///
    keep(sharewoman ca post19) ///
    ctitle("(6) Detrended IV: Share women") ///
    addtext(Controls, Yes, Detrended, Yes)


log close
