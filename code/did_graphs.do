*==============================================================
* GRAPHS FOR SB 826 PROJECT (CA vs TX), based on class handouts
* Run from the top. Uses the same setup as your regression do-file.
* Graphs are saved as .png in the working directory.
*==============================================================
* cd "your/project/folder"
use final_data.dta, clear

encode gvkey, gen(firm_id)
gen fyr = fyeyear
local controls "lnassets roa leverage multinational"

* Detrending (same as your code): CA-specific linear trend, pre-2018 years
gen ca_year = ca*fyr
reg lnmktcap ca i.fyr ca_year if fyr < 2018, cluster(firm_id)
predict lnmktcap_hat, resid


*==============================================================
* TABLE 4 GRAPH: PRE-TRENDS EVENT STUDY (full panel, 2010-2018)
* "Fully differenced event study" from the handout. 2018 = omitted year.
*==============================================================
forvalues y = 2010/2017 {
    gen ca_yr`y' = ca * (fyr == `y')
}

preserve
areg lnmktcap ca_yr2010-ca_yr2017 i.fyr ///
    if fyr >= 2010 & fyr <= 2018, ///
    absorb(firm_id) vce(cluster firm_id)

test ca_yr2010 ca_yr2011 ca_yr2012 ca_yr2013 ///
     ca_yr2014 ca_yr2015 ca_yr2016 ca_yr2017
local pjoint : display %5.3f r(p)

* step 1: empty variables for slope and standard error (2018 = 0 reference)
gen slope = 0
gen se = .

* step 2: copy slopes and SEs year by year
foreach y of numlist 2010/2017 {
    replace slope = _b[ca_yr`y'] if fyr==`y'
    replace se    = _se[ca_yr`y'] if fyr==`y'
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
graph export "fig_table4_pretrend.png", replace width(1600)
restore


*==============================================================
* TWO-PERIOD DiD SAMPLE (2018 vs 2019), same as your code
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
* CA vs TX, 2018 vs 2019, with 95% CI bars and raw DiD in the note
*==============================================================
capture program drop did_means
program define did_means
    syntax varname [if], TTL(string) YTTL(string) FNAME(string)
    preserve
    if "`if'" != "" keep `if'
    collapse (mean) m=`varlist' (semean) se=`varlist', by(ca fyr)
    gen upper = m + 1.96*se
    gen lower = m - 1.96*se
    gen x = fyr + cond(ca==1, .03, -.03)      // small offset so bars do not overlap
    sort ca fyr
    * obs 1=TX2018, 2=TX2019, 3=CA2018, 4=CA2019
    local did = (m[4]-m[3]) - (m[2]-m[1])
    local did : display %6.3f `did'
    gr two (line m x if ca==1) ///
           (line m x if ca==0, xline(2018.5, lp(dash))) ///
           (rcap upper lower x if ca==1) ///
           (rcap upper lower x if ca==0), ///
        legend(label(1 "California") label(2 "Texas") order(1 2)) ///
        title("`ttl'", size(medium)) ytitle("`yttl'") xtitle("Fiscal year") ///
        xlabel(2018 "2018 (pre)" 2019 "2019 (post)") xscale(range(2017.7 2019.3)) ///
        note("Raw DiD (CA change - TX change) = `did'. Bars show 95% confidence intervals.")
    graph export "`fname'", replace width(1600)
    restore
end


*==============================================================
* TABLE 1 GRAPHS: MAIN DiD
*==============================================================
* (a) 2x2 means: ln(market cap)
did_means lnmktcap, ttl("ln(Market Cap) Before and After SB 826") ///
    yttl("Average ln(market cap)") fname("fig_table1_means.png")

* (b) 2x2 means: detrended ln(market cap)
did_means lnmktcap_hat, ttl("Detrended ln(Market Cap) Before and After SB 826") ///
    yttl("Average detrended ln(market cap)") fname("fig_table1_means_detrended.png")

* (c) coefficient plot of ca_post19 across the 4 columns
qui reg lnmktcap ca post19 ca_post19, cluster(firm_id)
local b1 = _b[ca_post19]
local s1 = _se[ca_post19]

qui reg lnmktcap ca post19 ca_post19 `controls', cluster(firm_id)
local b2 = _b[ca_post19]
local s2 = _se[ca_post19]

qui reg lnmktcap_hat ca post19 ca_post19, cluster(firm_id)
local b3 = _b[ca_post19]
local s3 = _se[ca_post19]

qui reg lnmktcap_hat ca post19 ca_post19 `controls', cluster(firm_id)
local b4 = _b[ca_post19]
local s4 = _se[ca_post19]

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
graph export "fig_table1_coefplot.png", replace width(1600)
restore


*==============================================================
* TABLE 2 GRAPHS: PLACEBO (firms with >=1 woman on board in 2018)
*==============================================================
* (a) 2x2 means in placebo sample
did_means lnmktcap if woman18==1, ///
    ttl("ln(Market Cap): Firms with a Woman on Board in 2018") ///
    yttl("Average ln(market cap)") fname("fig_table2_means.png")

* (b) coefficient plot: full sample vs placebo sample
foreach g in 0 1 {
    local cond ""
    if `g'==1 local cond "if woman18==1"

    qui reg lnmktcap ca post19 ca_post19 `cond', cluster(firm_id)
    local pb`g'_1 = _b[ca_post19]
    local ps`g'_1 = _se[ca_post19]

    qui reg lnmktcap ca post19 ca_post19 `controls' `cond', cluster(firm_id)
    local pb`g'_2 = _b[ca_post19]
    local ps`g'_2 = _se[ca_post19]

    qui reg lnmktcap_hat ca post19 ca_post19 `controls' `cond', cluster(firm_id)
    local pb`g'_3 = _b[ca_post19]
    local ps`g'_3 = _se[ca_post19]
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
graph export "fig_table2_coefplot.png", replace width(1600)
restore


*==============================================================
* TABLE 3 GRAPHS: FIRST STAGE, REDUCED FORM, IV
*==============================================================
* (a) first-stage 2x2 means
did_means onewoman100, ttl("Firms with at Least One Woman on Board") ///
    yttl("Percent of firms") fname("fig_table3_means_onewoman.png")

did_means sharewoman100, ttl("Share of Board that is Women") ///
    yttl("Average percent of board") fname("fig_table3_means_share.png")

* (b) reduced form 2x2 means = ln(market cap) means (same as Table 1 graph)
*     Table 3 col (3) is the same spec as Table 1 col (2), so see fig_table1_means.png

* (c) first-stage and IV coefficients
qui reg onewoman ca post19 ca_post19 `controls', cluster(firm_id)
test ca_post19
local F1 : display %5.1f r(F)
local fb1 = _b[ca_post19]*100          // rescale to percentage points
local fs1 = _se[ca_post19]*100

qui reg sharewoman ca post19 ca_post19 `controls', cluster(firm_id)
test ca_post19
local F2 : display %5.1f r(F)
local fb2 = _b[ca_post19]*100
local fs2 = _se[ca_post19]*100

qui ivregress 2sls lnmktcap ca post19 `controls' (onewoman = ca_post19), vce(cluster firm_id)
local ib1 = _b[onewoman]/100             // log points per 1 pp
local is1 = _se[onewoman]/100

qui ivregress 2sls lnmktcap ca post19 `controls' (sharewoman = ca_post19), vce(cluster firm_id)
local ib2 = _b[sharewoman]/100
local is2 = _se[sharewoman]/100

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
    xtitle("") ytitle("Coefficient on CA x Post (percentage points)") ///
    xlabel(1 `""At least one" "woman (pp of firms)""' 2 `""Share of board" "that is women (pp)""', labsize(small)) ///
    xscale(range(0.5 2.5)) ///
    note("Controls included; SEs clustered by firm. First-stage F: `F1' (col 1), `F2' (col 2). Bars show 95% CI.")
graph export "fig_table3_firststage_coef.png", replace width(1600)
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
    xtitle("") ytitle("Change in ln(market cap) per 1 percentage point") ///
    xlabel(1 `""At least one" "woman (per 1 pp of firms)""' 2 `""Share of board" "that is women (per 1 pp)""', labsize(small)) ///
    xscale(range(0.5 2.5)) ///
    note("Instrument: CA x Post. Controls included; SEs clustered by firm. Bars show 95% CI.")
graph export "fig_table3_iv_coef.png", replace width(1600)
restore

*==============================================================
* END
*==============================================================
