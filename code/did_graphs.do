*==============================================================
* GRAPHS FOR SB 826 PROJECT (CA vs TX), based on class handouts
* Author: Seohee. Companion to Sophia's code/did_tests.do: every
* coefficient plotted here is the same regression as a column in
* her did_table1-did_table4, in the same units.
*
* Output: output/figures/fig_table*.png
*         output/figures/figure_numbers.csv  (every number plotted;
*         code/check_figures_vs_tables.py compares it to the tables)
*==============================================================
clear all
set more off

* --- project folder: tries each teammate's folder; otherwise stays in the
*     current folder (cd to the project folder yourself before running) ---
foreach d in "~/Desktop/Dartmouth Classes/Economics/ECON20/project" ///
             "C:/Users/shinz/OneDrive/Desktop/Econ20 FinalProject" ///
             "C:/Econ 20/proj" {
    capture cd "`d'"
    if !_rc continue, break
}
capture confirm file "final_data.dta"
if _rc {
    di as error "final_data.dta not found: cd to the project folder first"
    exit 601
}
capture mkdir "output"
capture mkdir "output/figures"
capture mkdir "logs"
capture log close
log using "logs/did_graphs.log", replace text

use final_data.dta, clear

encode gvkey, gen(firm_id)
gen fyr = fyeyear
local controls "lnassets roa leverage multinational"

* every plotted number is posted here (figure, item, coefficient, SE, N)
capture postclose fignums
postfile fignums str32 figure str32 item double(b se n) ///
    using "output/figures/figure_numbers.dta", replace

* Detrending (same as did_tests.do): CA-specific linear trend, pre-2018 years
gen ca_year = ca*fyr
reg lnmktcap ca i.fyr ca_year if fyr < 2018, cluster(firm_id)
predict lnmktcap_hat, resid


*==============================================================
* TABLE 4 GRAPH: PRE-TRENDS EVENT STUDY (full panel, 2010-2018)
* "Fully differenced event study" from the handout. 2018 = omitted year.
* Same regression as did_table4 column (1).
*==============================================================
forvalues y = 2010/2017 {
    gen ca_yr`y' = ca * (fyr == `y')
}

preserve
areg lnmktcap ca_yr2010-ca_yr2017 i.fyr ///
    if fyr >= 2010 & fyr <= 2018, ///
    absorb(firm_id) vce(cluster firm_id)
local N = e(N)

test ca_yr2010 ca_yr2011 ca_yr2012 ca_yr2013 ///
     ca_yr2014 ca_yr2015 ca_yr2016 ca_yr2017
local pjoint : display %5.3f r(p)
post fignums ("fig_table4_pretrend") ("joint_F") (r(F)) (.) (`N')
post fignums ("fig_table4_pretrend") ("joint_p") (r(p)) (.) (`N')

* step 1: empty variables for slope and standard error (2018 = 0 reference)
gen slope = 0
gen se = .

* step 2: copy slopes and SEs year by year
foreach y of numlist 2010/2017 {
    replace slope = _b[ca_yr`y'] if fyr==`y'
    replace se    = _se[ca_yr`y'] if fyr==`y'
    post fignums ("fig_table4_pretrend") ("ca_yr`y'") (_b[ca_yr`y']) (_se[ca_yr`y']) (`N')
}

* step 3: collapse to year level
keep if fyr >= 2010 & fyr <= 2018
collapse (mean) slope se, by(fyr)

* step 4: confidence interval
gen upper = slope + 1.96*se
gen lower = slope - 1.96*se

* step 5: plot
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
* TWO-PERIOD DiD SAMPLE (2018 vs 2019), same as did_tests.do
*==============================================================
keep if fyr==2018 | fyr==2019

gen post19    = (fyr==2019)
gen ca_post19 = ca*post19

gen onewoman   = (women >= 1) if women ~= .
gen sharewoman = women / boardsize if women ~= . & boardsize ~= . & boardsize > 0

* percent versions for graphing means
gen onewoman100   = 100*onewoman
gen sharewoman100 = 100*sharewoman

gen woman_obs = (women >= 1) if fyr==2018
bysort firm_id: egen woman18 = max(woman_obs)


*==============================================================
* HELPER PROGRAM: 2x2 means graph (collapse + gr two + rcap)
* CA vs TX, 2018 vs 2019, with 95% CI bars and raw DiD in the note.
* With no controls, the raw DiD equals the regression coefficient on
* ca_post19 (the 2x2 regression is saturated), so it is posted too.
*==============================================================
capture program drop did_means
program define did_means
    syntax varname [if], TTL(string) YTTL(string) FNAME(string)
    preserve
    if "`if'" != "" keep `if'
    quietly count if `varlist' < .
    local N = r(N)
    collapse (mean) m=`varlist' (semean) se=`varlist', by(ca fyr)
    gen upper = m + 1.96*se
    gen lower = m - 1.96*se
    gen x = fyr + cond(ca==1, .03, -.03)      // small offset so bars do not overlap
    sort ca fyr
    * obs 1=TX2018, 2=TX2019, 3=CA2018, 4=CA2019
    local didraw = (m[4]-m[3]) - (m[2]-m[1])
    local fig = subinstr("`fname'", ".png", "", .)
    post fignums ("`fig'") ("raw_did") (`didraw') (.) (`N')
    local did : display %6.3f `didraw'
    gr two (line m x if ca==1) ///
           (line m x if ca==0, xline(2018.5, lp(dash))) ///
           (rcap upper lower x if ca==1) ///
           (rcap upper lower x if ca==0), ///
        legend(label(1 "California") label(2 "Texas") order(1 2)) ///
        title("`ttl'", size(medium)) ytitle("`yttl'") xtitle("Fiscal year") ///
        xlabel(2018 "2018 (pre)" 2019 "2019 (post)") xscale(range(2017.7 2019.3)) ///
        note("Raw DiD (CA change - TX change) = `did'. Bars show 95% confidence intervals.")
    graph export "output/figures/`fname'", replace width(1600)
    restore
end


*==============================================================
* TABLE 1 GRAPHS: MAIN DiD
*==============================================================
* (a) 2x2 means: ln(market cap)   [raw DiD = did_table1 col (1)]
did_means lnmktcap, ttl("ln(Market Cap) Before and After SB 826") ///
    yttl("Average ln(market cap)") fname("fig_table1_means.png")

* (b) 2x2 means: detrended ln(market cap)   [raw DiD = did_table1 col (3)]
did_means lnmktcap_hat, ttl("Detrended ln(Market Cap) Before and After SB 826") ///
    yttl("Average detrended ln(market cap)") fname("fig_table1_means_detrended.png")

* (c) coefficient plot of ca_post19 across the 4 columns of did_table1
qui reg lnmktcap ca post19 ca_post19, cluster(firm_id)
local b1 = _b[ca_post19]
local s1 = _se[ca_post19]
local n1 = e(N)

qui reg lnmktcap ca post19 ca_post19 `controls', cluster(firm_id)
local b2 = _b[ca_post19]
local s2 = _se[ca_post19]
local n2 = e(N)

qui reg lnmktcap_hat ca post19 ca_post19, cluster(firm_id)
local b3 = _b[ca_post19]
local s3 = _se[ca_post19]
local n3 = e(N)

qui reg lnmktcap_hat ca post19 ca_post19 `controls', cluster(firm_id)
local b4 = _b[ca_post19]
local s4 = _se[ca_post19]
local n4 = e(N)

forvalues k = 1/4 {
    post fignums ("fig_table1_coefplot") ("col`k'") (`b`k'') (`s`k'') (`n`k'')
}

preserve
clear
set obs 4
gen spec = _n
gen b = .
gen se = .
forvalues k = 1/4 {
    replace b  = `b`k'' in `k'
    replace se = `s`k'' in `k'
}
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
* TABLE 2 GRAPHS: PLACEBO (firms with >=1 woman on board in 2018)
*==============================================================
* (a) 2x2 means in placebo sample   [raw DiD = did_table2 col (1)]
did_means lnmktcap if woman18==1, ///
    ttl("ln(Market Cap): Firms with a Woman on Board in 2018") ///
    yttl("Average ln(market cap)") fname("fig_table2_means.png")

* (b) coefficient plot: full sample vs placebo sample
*     full sample  = did_table1 cols (1), (2), (4)
*     placebo      = did_table2 cols (1), (2), (3)
foreach g in 0 1 {
    local cond ""
    if `g'==1 local cond "if woman18==1"

    qui reg lnmktcap ca post19 ca_post19 `cond', cluster(firm_id)
    local pb`g'_1 = _b[ca_post19]
    local ps`g'_1 = _se[ca_post19]
    local pn`g'_1 = e(N)

    qui reg lnmktcap ca post19 ca_post19 `controls' `cond', cluster(firm_id)
    local pb`g'_2 = _b[ca_post19]
    local ps`g'_2 = _se[ca_post19]
    local pn`g'_2 = e(N)

    qui reg lnmktcap_hat ca post19 ca_post19 `controls' `cond', cluster(firm_id)
    local pb`g'_3 = _b[ca_post19]
    local ps`g'_3 = _se[ca_post19]
    local pn`g'_3 = e(N)

    forvalues s = 1/3 {
        local grpname = cond(`g'==0, "full", "placebo")
        post fignums ("fig_table2_coefplot") ("`grpname'_spec`s'") (`pb`g'_`s'') (`ps`g'_`s'') (`pn`g'_`s'')
    }
}

preserve
clear
set obs 6
gen grp  = int((_n-1)/3)          // 0 = full sample, 1 = placebo sample
gen spec = mod(_n-1, 3) + 1
gen b = .
gen se = .
foreach g in 0 1 {
    forvalues s = 1/3 {
        replace b  = `pb`g'_`s'' if grp==`g' & spec==`s'
        replace se = `ps`g'_`s'' if grp==`g' & spec==`s'
    }
}
gen upper = b + 1.96*se
gen lower = b - 1.96*se
gen x = spec + cond(grp==1, .15, -.15)

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
* Coefficients are plotted in the SAME units as did_table3:
*   onewoman   = 0/1, sharewoman = 0-1 (0.01 = 1 percentage point)
*==============================================================
* (a) first-stage 2x2 means (raw, no controls; shown in percent for
*     readability -- these have no regression column in did_table3,
*     which includes controls)
did_means onewoman100, ttl("Firms with at Least One Woman on Board") ///
    yttl("Percent of firms") fname("fig_table3_means_onewoman.png")

did_means sharewoman100, ttl("Share of Board that is Women") ///
    yttl("Average percent of board") fname("fig_table3_means_share.png")

* (b) reduced form: did_table3 col (3) keeps only firm-years with board
*     data (if onewoman ~= .), so it is NOT the same as did_table1 col (2).
*     It is posted here so the check covers it; no separate graph.
qui reg lnmktcap ca post19 ca_post19 `controls' if onewoman ~= ., cluster(firm_id)
post fignums ("table3_reduced_form") ("ca_post19") (_b[ca_post19]) (_se[ca_post19]) (e(N))

* (c) first-stage and IV coefficients
qui reg onewoman ca post19 ca_post19 `controls', cluster(firm_id)
local fn1 = e(N)
local fb1 = _b[ca_post19]
local fs1 = _se[ca_post19]
test ca_post19
local F1 : display %5.1f r(F)
post fignums ("fig_table3_firststage_coef") ("onewoman") (`fb1') (`fs1') (`fn1')
post fignums ("fig_table3_firststage_coef") ("onewoman_F") (r(F)) (.) (`fn1')

qui reg sharewoman ca post19 ca_post19 `controls', cluster(firm_id)
local fn2 = e(N)
local fb2 = _b[ca_post19]
local fs2 = _se[ca_post19]
test ca_post19
local F2 : display %5.1f r(F)
post fignums ("fig_table3_firststage_coef") ("sharewoman") (`fb2') (`fs2') (`fn2')
post fignums ("fig_table3_firststage_coef") ("sharewoman_F") (r(F)) (.) (`fn2')

qui ivregress 2sls lnmktcap ca post19 `controls' (onewoman = ca_post19), vce(cluster firm_id)
local ib1 = _b[onewoman]
local is1 = _se[onewoman]
post fignums ("fig_table3_iv_coef") ("onewoman") (`ib1') (`is1') (e(N))

qui ivregress 2sls lnmktcap ca post19 `controls' (sharewoman = ca_post19), vce(cluster firm_id)
local ib2 = _b[sharewoman]
local is2 = _se[sharewoman]
post fignums ("fig_table3_iv_coef") ("sharewoman") (`ib2') (`is2') (e(N))

preserve
clear
set obs 2
gen spec = _n
gen b = .
gen se = .
forvalues k = 1/2 {
    replace b  = `fb`k'' in `k'
    replace se = `fs`k'' in `k'
}
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

preserve
clear
set obs 2
gen spec = _n
gen b = .
gen se = .
forvalues k = 1/2 {
    replace b  = `ib`k'' in `k'
    replace se = `is`k'' in `k'
}
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

*==============================================================
* Save every plotted number for code/check_figures_vs_tables.py
*==============================================================
postclose fignums
use "output/figures/figure_numbers.dta", clear
export delimited using "output/figures/figure_numbers.csv", replace
erase "output/figures/figure_numbers.dta"

*==============================================================
* END
*==============================================================
capture log close
