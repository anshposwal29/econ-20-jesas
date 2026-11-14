*==============================================================================
* 05_did_graphs.do -- figures for Sophia's two-period DiD tables (did_table1-4)
* Author: Seohee (was code/did_graphs.do)
* Every coefficient plotted here is the same regression as a column in Sophia's
* tables, in the same units. Each plotted number is also printed in the log;
* code/check_figures_vs_tables.py reads those lines and compares them with the tables.
* Input:  final_data.dta
* Output: output/figures/fig_table1-4_*.png, logs/05_did_graphs.log
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
log using "logs/05_did_graphs.log", replace text

use final_data.dta, clear

encode gvkey, gen(firm_id)
gen fyr = fyeyear

* year dummies: yrdum1 = 2010, yrdum2 = 2011, ..., yrdum16 = 2025
tab fyr, gen(yrdum)

* Detrending, same as Sophia's 04_did_tests.do: fit a CA-specific linear trend
* on the years before 2018 and keep the residuals. yrdum1 (2010) is the base year.
gen ca_year = ca*fyr
reg lnmktcap ca yrdum2-yrdum16 ca_year if fyr < 2018, cluster(firm_id)
predict lnmktcap_hat, resid


*==============================================================
* TABLE 4 GRAPH: PRE-TRENDS EVENT STUDY (2010-2018, 2018 = reference year)
* Same regression as did_table4 column (1).
*==============================================================
foreach y in 2010 2011 2012 2013 2014 2015 2016 2017 {
    gen ca_yr`y' = ca*(fyr==`y')
}

preserve
* step (0): regression with firm and year fixed effects
areg lnmktcap ca_yr2010-ca_yr2017 yrdum* if fyr >= 2010 & fyr <= 2018, ///
    absorb(firm_id) cluster(firm_id)
display "fig_table4_pretrend ca_yr2010: b = " _b[ca_yr2010] ", se = " _se[ca_yr2010] ", N = " e(N)
display "fig_table4_pretrend ca_yr2011: b = " _b[ca_yr2011] ", se = " _se[ca_yr2011] ", N = " e(N)
display "fig_table4_pretrend ca_yr2012: b = " _b[ca_yr2012] ", se = " _se[ca_yr2012] ", N = " e(N)
display "fig_table4_pretrend ca_yr2013: b = " _b[ca_yr2013] ", se = " _se[ca_yr2013] ", N = " e(N)
display "fig_table4_pretrend ca_yr2014: b = " _b[ca_yr2014] ", se = " _se[ca_yr2014] ", N = " e(N)
display "fig_table4_pretrend ca_yr2015: b = " _b[ca_yr2015] ", se = " _se[ca_yr2015] ", N = " e(N)
display "fig_table4_pretrend ca_yr2016: b = " _b[ca_yr2016] ", se = " _se[ca_yr2016] ", N = " e(N)
display "fig_table4_pretrend ca_yr2017: b = " _b[ca_yr2017] ", se = " _se[ca_yr2017] ", N = " e(N)

* step (1): create empty variables for the slope and standard error
gen slope = 0
gen se = .

* step (2): copy the slopes and standard errors of each year into these variables
foreach y in 2010 2011 2012 2013 2014 2015 2016 2017 {
    replace slope = _b[ca_yr`y'] if fyr==`y'
    replace se = _se[ca_yr`y'] if fyr==`y'
}

* joint test that all pre-period coefficients are zero (p-value goes in the note)
test ca_yr2010 ca_yr2011 ca_yr2012 ca_yr2013 ///
     ca_yr2014 ca_yr2015 ca_yr2016 ca_yr2017
display "fig_table4_pretrend joint_F: b = " r(F)
display "fig_table4_pretrend joint_p: b = " r(p)
local pjoint : display %5.3f r(p)

* step (3): collapse to the year level
keep if fyr >= 2010 & fyr <= 2018
collapse (mean) slope se, by(fyr)

* step (4): confidence interval
gen upper = slope + 1.96*se
gen lower = slope - 1.96*se

* step (5): plot
gr two (scatter slope fyr, yline(0, lc(black))) ///
       (rcap upper lower fyr, xline(2018.5, lp(dash))), ///
    legend(off) ///
    title("ln(Market Cap) Pre-trend Event Study" "California SB 826", size(medium)) ///
    xtitle("Fiscal year") ytitle("CA - TX difference, relative to 2018") ///
    xlabel(2010(1)2018) ///
    note("Firm and year FE; SEs clustered by firm. TX is the comparison group. Bars show 95% CI." ///
         "Joint test that all pre-period coefficients = 0: p = `pjoint'.")
graph export "output/figures/fig_table4_pretrend.png", replace width(1600)
restore


*==============================================================
* TWO-PERIOD DiD SAMPLE (2018 vs 2019), same as 04_did_tests.do
*==============================================================
keep if fyr==2018 | fyr==2019

gen post19    = (fyr==2019)
gen ca_post19 = ca*post19

gen onewoman   = (women >= 1) if women ~= .
gen sharewoman = women / boardsize if women ~= . & boardsize ~= . & boardsize > 0

* percent versions, for the means graphs
gen onewoman100   = 100*onewoman
gen sharewoman100 = 100*sharewoman

* woman18 = 1 if the firm had at least one woman on its board in 2018
gen woman_obs = (women >= 1) if fyr==2018
bysort firm_id: egen woman18 = max(woman_obs)

* The means graphs below are 2x2: CA vs TX, 2018 vs 2019, with 95% CI bars.
* With no controls, the raw DiD in the note equals the regression coefficient
* on ca_post19 (did_table1 or did_table2 column 1).


*==============================================================
* TABLE 1 GRAPHS: MAIN DiD
*==============================================================
* (a) means of ln(market cap)
preserve
collapse (mean) lnmktcap (semean) se_lnmktcap=lnmktcap, by(ca fyr)
gen upper = lnmktcap + 1.96*se_lnmktcap
gen lower = lnmktcap - 1.96*se_lnmktcap
* move CA and TX slightly apart so the bars do not overlap
gen x = fyr - .03
replace x = fyr + .03 if ca==1
* raw DiD = (CA 2019 - CA 2018) - (TX 2019 - TX 2018)
sort ca fyr     // rows: TX 2018, TX 2019, CA 2018, CA 2019
display "fig_table1_means raw_did: b = " (lnmktcap[4]-lnmktcap[3]) - (lnmktcap[2]-lnmktcap[1])
local did : display %6.3f (lnmktcap[4]-lnmktcap[3]) - (lnmktcap[2]-lnmktcap[1])
gr two (line lnmktcap x if ca==1) ///
       (line lnmktcap x if ca==0, xline(2018.5, lp(dash))) ///
       (rcap upper lower x if ca==1) ///
       (rcap upper lower x if ca==0), ///
    legend(label(1 "California") label(2 "Texas") order(1 2)) ///
    title("ln(Market Cap) Before and After SB 826", size(medium)) ///
    ytitle("Average ln(market cap)") xtitle("Fiscal year") ///
    xlabel(2018 "2018 (pre)" 2019 "2019 (post)") xscale(range(2017.7 2019.3)) ///
    note("Raw DiD (CA change - TX change) = `did'. Bars show 95% confidence intervals.")
graph export "output/figures/fig_table1_means.png", replace width(1600)
restore

* (b) means of detrended ln(market cap)
preserve
collapse (mean) lnmktcap_hat (semean) se_lnmktcap_hat=lnmktcap_hat, by(ca fyr)
gen upper = lnmktcap_hat + 1.96*se_lnmktcap_hat
gen lower = lnmktcap_hat - 1.96*se_lnmktcap_hat
gen x = fyr - .03
replace x = fyr + .03 if ca==1
sort ca fyr     // rows: TX 2018, TX 2019, CA 2018, CA 2019
display "fig_table1_means_detrended raw_did: b = " (lnmktcap_hat[4]-lnmktcap_hat[3]) - (lnmktcap_hat[2]-lnmktcap_hat[1])
local did : display %6.3f (lnmktcap_hat[4]-lnmktcap_hat[3]) - (lnmktcap_hat[2]-lnmktcap_hat[1])
gr two (line lnmktcap_hat x if ca==1) ///
       (line lnmktcap_hat x if ca==0, xline(2018.5, lp(dash))) ///
       (rcap upper lower x if ca==1) ///
       (rcap upper lower x if ca==0), ///
    legend(label(1 "California") label(2 "Texas") order(1 2)) ///
    title("Detrended ln(Market Cap) Before and After SB 826", size(medium)) ///
    ytitle("Average detrended ln(market cap)") xtitle("Fiscal year") ///
    xlabel(2018 "2018 (pre)" 2019 "2019 (post)") xscale(range(2017.7 2019.3)) ///
    note("Raw DiD (CA change - TX change) = `did'. Bars show 95% confidence intervals.")
graph export "output/figures/fig_table1_means_detrended.png", replace width(1600)
restore

* (c) coefficient on ca_post19 in the 4 columns of did_table1
* column (1): no controls
reg lnmktcap ca post19 ca_post19, cluster(firm_id)
display "fig_table1_coefplot col1: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)
local b1 = _b[ca_post19]
local s1 = _se[ca_post19]

* column (2): controls
reg lnmktcap ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
display "fig_table1_coefplot col2: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)
local b2 = _b[ca_post19]
local s2 = _se[ca_post19]

* column (3): detrended, no controls
reg lnmktcap_hat ca post19 ca_post19, cluster(firm_id)
display "fig_table1_coefplot col3: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)
local b3 = _b[ca_post19]
local s3 = _se[ca_post19]

* column (4): detrended, controls
reg lnmktcap_hat ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
display "fig_table1_coefplot col4: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)
local b4 = _b[ca_post19]
local s4 = _se[ca_post19]

* put the 4 coefficients in a small dataset and plot them
preserve
clear
set obs 4
gen spec = _n
gen b = .
gen se = .
replace b = `b1' in 1
replace b = `b2' in 2
replace b = `b3' in 3
replace b = `b4' in 4
replace se = `s1' in 1
replace se = `s2' in 2
replace se = `s3' in 3
replace se = `s4' in 4
gen upper = b + 1.96*se
gen lower = b - 1.96*se
gr two (scatter b spec, yline(0, lc(black))) (rcap upper lower spec), legend(off) ///
    title("DiD Estimates of SB 826 on ln(Market Cap)", size(medium)) ///
    xtitle("") ytitle("Coefficient on CA x Post") ///
    xlabel(1 `""(1)" "No controls""' 2 `""(2)" "Controls""' ///
           3 `""(3) Detrended" "No controls""' 4 `""(4) Detrended" "Controls""', labsize(small)) ///
    xscale(range(0.5 4.5)) ///
    note("2018 vs 2019, CA vs TX. SEs clustered by firm. Bars show 95% confidence intervals.")
graph export "output/figures/fig_table1_coefplot.png", replace width(1600)
restore


*==============================================================
* TABLE 2 GRAPHS: PLACEBO (firms with a woman on the board in 2018)
*==============================================================
* (a) means of ln(market cap) in the placebo sample
preserve
keep if woman18==1
collapse (mean) lnmktcap (semean) se_lnmktcap=lnmktcap, by(ca fyr)
gen upper = lnmktcap + 1.96*se_lnmktcap
gen lower = lnmktcap - 1.96*se_lnmktcap
gen x = fyr - .03
replace x = fyr + .03 if ca==1
sort ca fyr     // rows: TX 2018, TX 2019, CA 2018, CA 2019
display "fig_table2_means raw_did: b = " (lnmktcap[4]-lnmktcap[3]) - (lnmktcap[2]-lnmktcap[1])
local did : display %6.3f (lnmktcap[4]-lnmktcap[3]) - (lnmktcap[2]-lnmktcap[1])
gr two (line lnmktcap x if ca==1) ///
       (line lnmktcap x if ca==0, xline(2018.5, lp(dash))) ///
       (rcap upper lower x if ca==1) ///
       (rcap upper lower x if ca==0), ///
    legend(label(1 "California") label(2 "Texas") order(1 2)) ///
    title("ln(Market Cap): Firms with a Woman on Board in 2018", size(medium)) ///
    ytitle("Average ln(market cap)") xtitle("Fiscal year") ///
    xlabel(2018 "2018 (pre)" 2019 "2019 (post)") xscale(range(2017.7 2019.3)) ///
    note("Raw DiD (CA change - TX change) = `did'. Bars show 95% confidence intervals.")
graph export "output/figures/fig_table2_means.png", replace width(1600)
restore

* (b) full sample vs placebo sample
* full sample = did_table1 columns (1), (2), (4); placebo = did_table2 columns (1), (2), (3)
reg lnmktcap ca post19 ca_post19, cluster(firm_id)
display "fig_table2_coefplot full_spec1: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)
local b1 = _b[ca_post19]
local s1 = _se[ca_post19]

reg lnmktcap ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
display "fig_table2_coefplot full_spec2: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)
local b2 = _b[ca_post19]
local s2 = _se[ca_post19]

reg lnmktcap_hat ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
display "fig_table2_coefplot full_spec3: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)
local b3 = _b[ca_post19]
local s3 = _se[ca_post19]

reg lnmktcap ca post19 ca_post19 if woman18==1, cluster(firm_id)
display "fig_table2_coefplot placebo_spec1: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)
local b4 = _b[ca_post19]
local s4 = _se[ca_post19]

reg lnmktcap ca post19 ca_post19 lnassets roa leverage multinational if woman18==1, cluster(firm_id)
display "fig_table2_coefplot placebo_spec2: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)
local b5 = _b[ca_post19]
local s5 = _se[ca_post19]

reg lnmktcap_hat ca post19 ca_post19 lnassets roa leverage multinational if woman18==1, cluster(firm_id)
display "fig_table2_coefplot placebo_spec3: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)
local b6 = _b[ca_post19]
local s6 = _se[ca_post19]

* rows 1-3 = full sample (grp 0), rows 4-6 = placebo sample (grp 1)
preserve
clear
set obs 6
gen grp = 0
replace grp = 1 in 4/6
gen spec = _n
replace spec = _n - 3 in 4/6
gen b = .
gen se = .
replace b = `b1' in 1
replace b = `b2' in 2
replace b = `b3' in 3
replace b = `b4' in 4
replace b = `b5' in 5
replace b = `b6' in 6
replace se = `s1' in 1
replace se = `s2' in 2
replace se = `s3' in 3
replace se = `s4' in 4
replace se = `s5' in 5
replace se = `s6' in 6
gen upper = b + 1.96*se
gen lower = b - 1.96*se
* move the two samples slightly apart so the bars do not overlap
gen x = spec - .15
replace x = spec + .15 if grp==1

gr two (scatter b x if grp==0, yline(0, lc(black))) (rcap upper lower x if grp==0) ///
       (scatter b x if grp==1) (rcap upper lower x if grp==1), ///
    legend(order(1 "Full sample" 3 "Placebo: woman on board in 2018")) ///
    title("DiD Estimates: Full vs Placebo Sample", size(medium)) ///
    xtitle("") ytitle("Coefficient on CA x Post") ///
    xlabel(1 `""(1)" "No controls""' 2 `""(2)" "Controls""' ///
           3 `""(3) Detrended" "Controls""', labsize(small)) ///
    xscale(range(0.5 3.5)) ///
    note("Dependent variable: ln(market cap). SEs clustered by firm. Bars show 95% confidence intervals.")
graph export "output/figures/fig_table2_coefplot.png", replace width(1600)
restore


*==============================================================
* TABLE 3 GRAPHS: FIRST STAGE, REDUCED FORM, IV
* Coefficients are in the same units as did_table3:
* onewoman is 0/1, sharewoman is 0-1 (0.01 = 1 percentage point)
*==============================================================
* (a) first-stage means, in percent (raw means, no controls, so no table column)
preserve
collapse (mean) onewoman100 (semean) se_onewoman100=onewoman100, by(ca fyr)
gen upper = onewoman100 + 1.96*se_onewoman100
gen lower = onewoman100 - 1.96*se_onewoman100
gen x = fyr - .03
replace x = fyr + .03 if ca==1
sort ca fyr     // rows: TX 2018, TX 2019, CA 2018, CA 2019
display "fig_table3_means_onewoman raw_did: b = " (onewoman100[4]-onewoman100[3]) - (onewoman100[2]-onewoman100[1])
local did : display %6.3f (onewoman100[4]-onewoman100[3]) - (onewoman100[2]-onewoman100[1])
gr two (line onewoman100 x if ca==1) ///
       (line onewoman100 x if ca==0, xline(2018.5, lp(dash))) ///
       (rcap upper lower x if ca==1) ///
       (rcap upper lower x if ca==0), ///
    legend(label(1 "California") label(2 "Texas") order(1 2)) ///
    title("Firms with at Least One Woman on Board", size(medium)) ///
    ytitle("Percent of firms") xtitle("Fiscal year") ///
    xlabel(2018 "2018 (pre)" 2019 "2019 (post)") xscale(range(2017.7 2019.3)) ///
    note("Raw DiD (CA change - TX change) = `did'. Bars show 95% confidence intervals.")
graph export "output/figures/fig_table3_means_onewoman.png", replace width(1600)
restore

preserve
collapse (mean) sharewoman100 (semean) se_sharewoman100=sharewoman100, by(ca fyr)
gen upper = sharewoman100 + 1.96*se_sharewoman100
gen lower = sharewoman100 - 1.96*se_sharewoman100
gen x = fyr - .03
replace x = fyr + .03 if ca==1
sort ca fyr     // rows: TX 2018, TX 2019, CA 2018, CA 2019
display "fig_table3_means_share raw_did: b = " (sharewoman100[4]-sharewoman100[3]) - (sharewoman100[2]-sharewoman100[1])
local did : display %6.3f (sharewoman100[4]-sharewoman100[3]) - (sharewoman100[2]-sharewoman100[1])
gr two (line sharewoman100 x if ca==1) ///
       (line sharewoman100 x if ca==0, xline(2018.5, lp(dash))) ///
       (rcap upper lower x if ca==1) ///
       (rcap upper lower x if ca==0), ///
    legend(label(1 "California") label(2 "Texas") order(1 2)) ///
    title("Share of Board that is Women", size(medium)) ///
    ytitle("Average percent of board") xtitle("Fiscal year") ///
    xlabel(2018 "2018 (pre)" 2019 "2019 (post)") xscale(range(2017.7 2019.3)) ///
    note("Raw DiD (CA change - TX change) = `did'. Bars show 95% confidence intervals.")
graph export "output/figures/fig_table3_means_share.png", replace width(1600)
restore

* (b) reduced form = did_table3 column (3). It keeps only firm-years with board
* data, so it differs from did_table1 column (2). No graph; printed for the check.
reg lnmktcap ca post19 ca_post19 lnassets roa leverage multinational if onewoman ~= ., cluster(firm_id)
display "table3_reduced_form ca_post19: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)

* (c) first stages = did_table3 columns (1) and (2), with their F-statistics
reg onewoman ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
display "fig_table3_firststage_coef onewoman: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)
local b1 = _b[ca_post19]
local s1 = _se[ca_post19]
test ca_post19
display "fig_table3_firststage_coef onewoman_F: b = " r(F)
local F1 : display %5.1f r(F)

reg sharewoman ca post19 ca_post19 lnassets roa leverage multinational, cluster(firm_id)
display "fig_table3_firststage_coef sharewoman: b = " _b[ca_post19] ", se = " _se[ca_post19] ", N = " e(N)
local b2 = _b[ca_post19]
local s2 = _se[ca_post19]
test ca_post19
display "fig_table3_firststage_coef sharewoman_F: b = " r(F)
local F2 : display %5.1f r(F)

preserve
clear
set obs 2
gen spec = _n
gen b = .
gen se = .
replace b = `b1' in 1
replace b = `b2' in 2
replace se = `s1' in 1
replace se = `s2' in 2
gen upper = b + 1.96*se
gen lower = b - 1.96*se
gr two (scatter b spec, yline(0, lc(black))) (rcap upper lower spec), legend(off) ///
    title("First Stage: Effect of SB 826 on Board Gender", size(medium)) ///
    xtitle("") ytitle("Coefficient on CA x Post") yscale(range(0)) ylabel(#6) ///
    xlabel(1 `""At least one woman" "(0/1)""' 2 `""Share of board that is" "women (0-1)""', labsize(small)) ///
    xscale(range(0.5 2.5)) ///
    note("Same units as Table 3: 0.01 = 1 percentage point. Controls included; SEs clustered by firm." ///
         "First-stage F: `F1' (col 1), `F2' (col 2). Bars show 95% CI.")
graph export "output/figures/fig_table3_firststage_coef.png", replace width(1600)
restore

* (d) IV = did_table3 columns (4) and (5)
* not from class: ivregress (not ivreg), so the SEs match Sophia's Table 3 exactly
ivregress 2sls lnmktcap ca post19 lnassets roa leverage multinational (onewoman = ca_post19), vce(cluster firm_id)
display "fig_table3_iv_coef onewoman: b = " _b[onewoman] ", se = " _se[onewoman] ", N = " e(N)
local b1 = _b[onewoman]
local s1 = _se[onewoman]

* not from class: ivregress (not ivreg), so the SEs match Sophia's Table 3 exactly
ivregress 2sls lnmktcap ca post19 lnassets roa leverage multinational (sharewoman = ca_post19), vce(cluster firm_id)
display "fig_table3_iv_coef sharewoman: b = " _b[sharewoman] ", se = " _se[sharewoman] ", N = " e(N)
local b2 = _b[sharewoman]
local s2 = _se[sharewoman]

preserve
clear
set obs 2
gen spec = _n
gen b = .
gen se = .
replace b = `b1' in 1
replace b = `b2' in 2
replace se = `s1' in 1
replace se = `s2' in 2
gen upper = b + 1.96*se
gen lower = b - 1.96*se
gr two (scatter b spec, yline(0, lc(black))) (rcap upper lower spec), legend(off) ///
    title("IV Estimates: Effect of Women on Boards on ln(Market Cap)", size(medium)) ///
    xtitle("") ytitle("Coefficient (effect on ln(market cap))") ///
    xlabel(1 `""At least one woman" "(0 to 1)""' 2 `""Share of board that is" "women (0 to 1)""', labsize(small)) ///
    xscale(range(0.5 2.5)) ///
    note("Same units as Table 3: divide by 100 for the effect of 1 percentage point." ///
         "Instrument: CA x Post. Controls included; SEs clustered by firm. Bars show 95% CI.")
graph export "output/figures/fig_table3_iv_coef.png", replace width(1600)
restore

cap log close
