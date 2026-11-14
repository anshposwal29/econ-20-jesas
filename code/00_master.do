*==============================================================================
* 00_master.do  --  RUNS THE WHOLE PAPER PIPELINE, IN ORDER
* Author:  Ansh
* Purpose: One do-file that reproduces every table and figure from
*          final_data.dta, on any teammate's machine (Mac or Windows).
* Run:     open Stata, then   do "<project folder>/code/00_master.do"
*          (or double-click it). The project folder is found automatically;
*          if that fails, put your folder in the PROJ line below.
*
* Steps (each script also runs on its own; see its header):
*   01   01_build_data.do          raw/ -> final_data.dta, temp/balance_candidates.dta
*                                  OFF by default (slow, overwrites final_data.dta)
*   01b  01b_collinearity_tests.do -> output/collinearity_tests.xlsx
*   02   02_balance_test.do        -> output/table1_means.csv, balance_prelaw.xml,
*                                     balance_did.xml, table1_balance.csv
*   03   03_table1_format.py       -> output/Table1_means_balance.xlsx (Python 3
*                                     with pandas + openpyxl; set python 0 to skip)
*   04   04_did_tests.do (Sophia)  -> output/did_table1-4.txt/.xml (main results)
*   05   05_did_graphs.do (Seohee) -> output/figures/fig_table*.png, figure_numbers.csv
*   06   06_panel_tables.do (Sophia) -> output/table2_main, table2_plcbo,
*                                     table3_pretrend, table4_iv (.txt/.xml)
*   07   07_panel_event_study_graphs.do (Seohee)
*                                  -> output/figures/es_onewoman_overlay.png,
*                                     es_lnmktcap_overlay.png (+ output/07_check_*)
* Each step writes its log to logs/<script name>.log.
* Afterwards, on a Mac, `bash code/run_check.sh` checks figures vs tables.
*==============================================================================
clear all
set more off

* --- Settings --------------------------------------------------------------
global PROJ ""          // leave empty to auto-detect, or e.g. "C:/Econ 20/proj"
local build  0          // 1 = rebuild final_data.dta from raw/ (slow)
local python 1          // 1 = run the Python Table 1 formatter (step 03)

* --- Project folder: same search as every script's header ------------------
if `"$PROJ"' == "" {
    capture confirm file "final_data.dta"
    if _rc {
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
        di as error "final_data.dta not found. Put your project folder in the"
        di as error "global PROJ line at the top of code/00_master.do."
        exit 601
    }
    global PROJ "`c(pwd)'"
}
cd `"$PROJ"'
capture confirm file "final_data.dta"
if _rc {
    di as error `"final_data.dta not found in "$PROJ": check the global PROJ line."'
    exit 601
}
di as text "Project folder: $PROJ"
capture mkdir "logs"
capture mkdir "output"
capture mkdir "output/figures"

* --- 01 / 01b: data --------------------------------------------------------
if `build' do "code/01_build_data.do"
do "code/01b_collinearity_tests.do"

* --- 02 / 03: Table 1 (means and balance) ----------------------------------
do "code/02_balance_test.do"
if `python' {
    local py = cond("`c(os)'" == "Windows", "python", "python3")
    shell `py' "code/03_table1_format.py"
}

* --- 04 / 05: two-period DiD tables and figures ----------------------------
do "code/04_did_tests.do"
do "code/05_did_graphs.do"

* --- 06 / 07: panel tables and panel event studies -------------------------
* 06 writes table2_plcbo with "append" only, so erase it first; otherwise every
* rerun adds two more columns to it.
capture erase "output/table2_plcbo.txt"
capture erase "output/table2_plcbo.xml"
do "code/06_panel_tables.do"
do "code/07_panel_event_study_graphs.do"

di as result "00_master.do finished: tables in output/, figures in output/figures/, logs in logs/"
