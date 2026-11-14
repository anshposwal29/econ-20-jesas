*==============================================================================
* 07_panel_event_study_graphs.do -- panel event studies, original vs detrended
* Author: Seohee (was code/paneldata_outreg2_graphs.do)
* Event studies for fiscal years 2011-2021 (2017 = reference year), for the
* first stage (onewoman) and the reduced form (lnmktcap), each shown as is and
* after removing a California-specific linear pre-trend.
* Input:  final_data.dta
* Output: output/figures/es_onewoman_overlay.png/.gph, es_lnmktcap_overlay.png/.gph
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

* year dummies (all years in the data). xtset on firm only: some firms have two
* fiscal year-ends in one calendar year, which would break xtset firm_id fyr.
tab fyr, gen(fyeardum)
xtset firm_id

gen onewoman = (women >= 1) if women ~= .

*==============================================================
* DETRENDING: fit a CA-specific linear trend on the pre-law years (post==0)
* and keep the residuals. Same as Table 2 column (3) of Sophia's panel tables.
*==============================================================
gen ca_year = ca*fyr

reg lnmktcap ca fyeardum* ca_year if post==0, cluster(firm_id)
predict lnmktcap_hat, resid

reg onewoman ca fyeardum* ca_year if post==0, cluster(firm_id)
predict onewoman_hat, resid

*==============================================================
* EVENT STUDIES (2011-2021, 2017 = reference year)
* Same sample in all four: firm-years with board data (onewoman ~= .)
*==============================================================
foreach y in 2011 2012 2013 2014 2015 2016 2018 2019 2020 2021 {
    gen caXyr`y' = ca*(fyr==`y')
}

* (1) first stage, original
xtreg onewoman caXyr* fyeardum* if onewoman ~= . & fyr >= 2011 & fyr <= 2021, fe cluster(firm_id)
gen b_onewoman = 0
gen se_onewoman = .
foreach y in 2011 2012 2013 2014 2015 2016 2018 2019 2020 2021 {
    replace b_onewoman = _b[caXyr`y'] if fyr==`y'
    replace se_onewoman = _se[caXyr`y'] if fyr==`y'
}

* (2) first stage, detrended
xtreg onewoman_hat caXyr* fyeardum* if onewoman ~= . & fyr >= 2011 & fyr <= 2021, fe cluster(firm_id)
gen b_onewoman_hat = 0
gen se_onewoman_hat = .
foreach y in 2011 2012 2013 2014 2015 2016 2018 2019 2020 2021 {
    replace b_onewoman_hat = _b[caXyr`y'] if fyr==`y'
    replace se_onewoman_hat = _se[caXyr`y'] if fyr==`y'
}

* (3) reduced form, original
xtreg lnmktcap caXyr* fyeardum* if onewoman ~= . & fyr >= 2011 & fyr <= 2021, fe cluster(firm_id)
gen b_lnmktcap = 0
gen se_lnmktcap = .
foreach y in 2011 2012 2013 2014 2015 2016 2018 2019 2020 2021 {
    replace b_lnmktcap = _b[caXyr`y'] if fyr==`y'
    replace se_lnmktcap = _se[caXyr`y'] if fyr==`y'
}

* (4) reduced form, detrended
xtreg lnmktcap_hat caXyr* fyeardum* if onewoman ~= . & fyr >= 2011 & fyr <= 2021, fe cluster(firm_id)
gen b_lnmktcap_hat = 0
gen se_lnmktcap_hat = .
foreach y in 2011 2012 2013 2014 2015 2016 2018 2019 2020 2021 {
    replace b_lnmktcap_hat = _b[caXyr`y'] if fyr==`y'
    replace se_lnmktcap_hat = _se[caXyr`y'] if fyr==`y'
}

*==============================================================
* GRAPH 1: first stage, original vs detrended
*==============================================================
preserve
keep if fyr >= 2011 & fyr <= 2021
collapse (mean) b_onewoman se_onewoman b_onewoman_hat se_onewoman_hat, by(fyr)
gen upper = b_onewoman + 1.96*se_onewoman
gen lower = b_onewoman - 1.96*se_onewoman
gen upper_hat = b_onewoman_hat + 1.96*se_onewoman_hat
gen lower_hat = b_onewoman_hat - 1.96*se_onewoman_hat
* move the two series slightly apart so the bars do not overlap
gen x = fyr - 0.12
gen x_hat = fyr + 0.12

gr two (rcap upper lower x, lc(gs11)) (scatter b_onewoman x, mc(gs8) ms(Oh)) ///
       (rcap upper_hat lower_hat x_hat, lc(cranberry)) (scatter b_onewoman_hat x_hat, mc(blue) ms(O)), ///
    yline(0, lc(black) lp(dash)) xline(2017.5, lp(dash) lc(black)) ///
    legend(order(2 "Original" 4 "Detrended (CA linear pre-trend removed)") ring(0) pos(11)) ///
    xlabel(2011(2)2021) ///
    xtitle("Fiscal year (calendar year of fiscal year end; SB 826 applies from FY2018)") ///
    ytitle("CA - TX difference in P(at least 1 woman), relative to 2017") ///
    title("First Stage Event Study" "California SB 826: Original vs. Detrended", size(medium)) ///
    note("CA-specific linear trend estimated on pre-law observations (post==0) and removed from the outcome." ///
         "Bars show 95% CIs, standard errors clustered by firm. Dashed line = SB 826 signed 30 Sep 2018.")
graph export "output/figures/es_onewoman_overlay.png", replace width(2000)
graph save "output/figures/es_onewoman_overlay.gph", replace
restore

*==============================================================
* GRAPH 2: reduced form, original vs detrended
*==============================================================
preserve
keep if fyr >= 2011 & fyr <= 2021
collapse (mean) b_lnmktcap se_lnmktcap b_lnmktcap_hat se_lnmktcap_hat, by(fyr)
gen upper = b_lnmktcap + 1.96*se_lnmktcap
gen lower = b_lnmktcap - 1.96*se_lnmktcap
gen upper_hat = b_lnmktcap_hat + 1.96*se_lnmktcap_hat
gen lower_hat = b_lnmktcap_hat - 1.96*se_lnmktcap_hat
gen x = fyr - 0.12
gen x_hat = fyr + 0.12

gr two (rcap upper lower x, lc(gs11)) (scatter b_lnmktcap x, mc(gs8) ms(Oh)) ///
       (rcap upper_hat lower_hat x_hat, lc(cranberry)) (scatter b_lnmktcap_hat x_hat, mc(blue) ms(O)), ///
    yline(0, lc(black) lp(dash)) xline(2017.5, lp(dash) lc(black)) ///
    legend(order(2 "Original" 4 "Detrended (CA linear pre-trend removed)") ring(0) pos(11)) ///
    xlabel(2011(2)2021) ///
    xtitle("Fiscal year (calendar year of fiscal year end; SB 826 applies from FY2018)") ///
    ytitle("CA - TX difference in ln(market cap), relative to 2017") ///
    title("Reduced Form Event Study" "California SB 826: Original vs. Detrended", size(medium)) ///
    note("CA-specific linear trend estimated on pre-law observations (post==0) and removed from the outcome." ///
         "Bars show 95% CIs, standard errors clustered by firm. Dashed line = SB 826 signed 30 Sep 2018.")
graph export "output/figures/es_lnmktcap_overlay.png", replace width(2000)
graph save "output/figures/es_lnmktcap_overlay.gph", replace
restore

cap log close
