*==============================================================================
* 07_panel_event_study_graphs.do -- panel event studies, original vs detrended
* Author: Seohee (was code/paneldata_outreg2_graphs.do)
* Event studies for fiscal years 2011-2020 (2018 = reference year, the last
* pre-law year), for the board outcome (onewoman) and the main outcome (lnmktcap).
* Only lnmktcap is detrended: it is the outcome that fails the pre-trend test.
* Input:  final_data.dta
* Output: output/figures/es_onewoman.png/.gph, es_lnmktcap_overlay.png/.gph,
*         output/table_event_study (.txt/.xml/.tex) = the numbers behind both graphs
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
log using "logs/07_panel_event_study_graphs.log", replace text

use "final_data.dta", clear

encode gvkey, gen(firm_id)
gen fyr = fyeyear
* the paper uses fiscal years 2011-2020 everywhere
keep if fyr >= 2011 & fyr <= 2020

* year dummies (2011-2020). xtset on firm only: some firms have two
* fiscal year-ends in one calendar year, which would break xtset firm_id fyr.
tab fyr, gen(fyeardum)
xtset firm_id

gen onewoman = (women >= 1) if women ~= .

* pre = fiscal years 2011-2018, post = fiscal years 2019-2020
replace post = (fyr >= 2019)

*==============================================================
* DETRENDING (ln market cap only): fit a CA-specific linear trend on the
* pre-law years (2011-2018) and keep the residuals. Same as the detrended
* columns of Sophia's panel tables.
*==============================================================
gen ca_year = ca*fyr

reg lnmktcap ca fyeardum* ca_year if post==0, cluster(firm_id)
predict lnmktcap_hat, resid

*==============================================================
* EVENT STUDIES (2011-2020, 2018 = reference year)
* Same sample in all three: firm-years with board data (onewoman ~= .)
*==============================================================
foreach y in 2011 2012 2013 2014 2015 2016 2017 2019 2020 {
    gen caXyr`y' = ca*(fyr==`y')
}

* (1) first stage
xtreg onewoman caXyr* fyeardum* if onewoman ~= ., fe cluster(firm_id)
* joint test that the pre-law years (2011-2017) are all zero
test caXyr2011 caXyr2012 caXyr2013 caXyr2014 caXyr2015 caXyr2016 caXyr2017
outreg2 using output/table_event_study, excel tex(frag) replace dec(3) ///
    drop(fyeardum* o.fyeardum*) ///
    ctitle("(1) First stage", "One woman") ///
    addtext(Firm FE, Yes, Year FE, Yes, Detrended, No) ///
    addstat(Joint pre-trend F, r(F), Joint pre-trend p, r(p))
gen b_onewoman = 0
gen se_onewoman = .
foreach y in 2011 2012 2013 2014 2015 2016 2017 2019 2020 {
    replace b_onewoman = _b[caXyr`y'] if fyr==`y'
    replace se_onewoman = _se[caXyr`y'] if fyr==`y'
}

* (2) ln(market cap), original
xtreg lnmktcap caXyr* fyeardum* if onewoman ~= ., fe cluster(firm_id)
* joint test that the pre-law years (2011-2017) are all zero
test caXyr2011 caXyr2012 caXyr2013 caXyr2014 caXyr2015 caXyr2016 caXyr2017
outreg2 using output/table_event_study, excel tex(frag) append dec(3) ///
    drop(fyeardum* o.fyeardum*) ///
    ctitle("(2) ln(mkt cap)", "Original") ///
    addtext(Firm FE, Yes, Year FE, Yes, Detrended, No) ///
    addstat(Joint pre-trend F, r(F), Joint pre-trend p, r(p))
gen b_lnmktcap = 0
gen se_lnmktcap = .
foreach y in 2011 2012 2013 2014 2015 2016 2017 2019 2020 {
    replace b_lnmktcap = _b[caXyr`y'] if fyr==`y'
    replace se_lnmktcap = _se[caXyr`y'] if fyr==`y'
}

* (3) ln(market cap), detrended
xtreg lnmktcap_hat caXyr* fyeardum* if onewoman ~= ., fe cluster(firm_id)
* joint test that the pre-law years (2011-2017) are all zero
test caXyr2011 caXyr2012 caXyr2013 caXyr2014 caXyr2015 caXyr2016 caXyr2017
outreg2 using output/table_event_study, excel tex(frag) append dec(3) ///
    drop(fyeardum* o.fyeardum*) ///
    ctitle("(3) ln(mkt cap)", "Detrended") ///
    addtext(Firm FE, Yes, Year FE, Yes, Detrended, Yes) ///
    addstat(Joint pre-trend F, r(F), Joint pre-trend p, r(p))
gen b_lnmktcap_hat = 0
gen se_lnmktcap_hat = .
foreach y in 2011 2012 2013 2014 2015 2016 2017 2019 2020 {
    replace b_lnmktcap_hat = _b[caXyr`y'] if fyr==`y'
    replace se_lnmktcap_hat = _se[caXyr`y'] if fyr==`y'
}

*==============================================================
* GRAPH 1: first stage (not detrended)
*==============================================================
preserve
collapse (mean) b_onewoman se_onewoman, by(fyr)
gen upper = b_onewoman + 1.96*se_onewoman
gen lower = b_onewoman - 1.96*se_onewoman

gr two (rcap upper lower fyr, lc(cranberry)) (scatter b_onewoman fyr, mc(blue) ms(O)), ///
    yline(0, lc(black) lp(dash)) xline(2018.5, lp(dash) lc(black)) ///
    legend(off) ///
    xlabel(2011(1)2020) ///
    xtitle("Fiscal year (calendar year of fiscal year end)") ///
    ytitle("CA - TX difference in P(at least 1 woman), relative to 2018") ///
    title("First Stage Event Study" "California SB 826", size(medium)) ///
    note("Firm and year fixed effects. Pre-law = fiscal years 2011-2018, post-law = 2019-2020." ///
         "2018 is the omitted year. Bars show 95% CIs, standard errors clustered by firm.")
graph export "output/figures/es_onewoman.png", replace width(2000)
graph save "output/figures/es_onewoman.gph", replace
restore

*==============================================================
* GRAPH 2: ln(market cap), original vs detrended
*==============================================================
preserve
collapse (mean) b_lnmktcap se_lnmktcap b_lnmktcap_hat se_lnmktcap_hat, by(fyr)
gen upper = b_lnmktcap + 1.96*se_lnmktcap
gen lower = b_lnmktcap - 1.96*se_lnmktcap
gen upper_hat = b_lnmktcap_hat + 1.96*se_lnmktcap_hat
gen lower_hat = b_lnmktcap_hat - 1.96*se_lnmktcap_hat
* move the two series slightly apart so the bars do not overlap
gen x = fyr - 0.12
gen x_hat = fyr + 0.12

gr two (rcap upper lower x, lc(gs11)) (scatter b_lnmktcap x, mc(gs8) ms(Oh)) ///
       (rcap upper_hat lower_hat x_hat, lc(cranberry)) (scatter b_lnmktcap_hat x_hat, mc(blue) ms(O)), ///
    yline(0, lc(black) lp(dash)) xline(2018.5, lp(dash) lc(black)) ///
    legend(order(2 "Original" 4 "Detrended (CA linear pre-trend removed)") ring(0) pos(11)) ///
    xlabel(2011(1)2020) ///
    xtitle("Fiscal year (calendar year of fiscal year end)") ///
    ytitle("CA - TX difference in ln(market cap), relative to 2018") ///
    title("ln(Market Cap) Event Study" "California SB 826: Original vs. Detrended", size(medium)) ///
    note("Detrended: California's linear trend over the pre-law years (2011-2018) is removed from ln(market cap)." ///
         "Pre-law = fiscal years 2011-2018, post-law = 2019-2020. 2018 is the omitted year." ///
         "Bars show 95% CIs, standard errors clustered by firm.")
graph export "output/figures/es_lnmktcap_overlay.png", replace width(2000)
graph save "output/figures/es_lnmktcap_overlay.gph", replace
restore

cap log close
