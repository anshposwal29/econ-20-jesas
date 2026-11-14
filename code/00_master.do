*==============================================================================
* 00_master.do -- runs the whole pipeline, in order, from final_data.dta
* Author: Ansh
* Run: open Stata, then  do "<your project folder>/code/00_master.do"
* Each script also runs on its own and writes its log to logs/<script name>.log.
* Afterwards, on a Mac, run  bash code/run_check.sh  to check figures vs tables.
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

* 01: builds final_data.dta from raw/. Slow, and overwrites final_data.dta,
* so it is off. Remove the * only when the data must be rebuilt.
* do "code/01_build_data.do"

* 01b and 02: collinearity tests and Table 1 (means and balance test)
do "code/01b_collinearity_tests.do"
do "code/02_balance_test.do"

* 03: Python formats Table 1 into output/Table1_means_balance.xlsx
* (needs Python 3 with pandas and openpyxl; put a * in front of the shell lines to skip it)
* On Windows the command is python, on a Mac python3.
if "`c(os)'" == "Windows" {
    shell python "code/03_table1_format.py"
}
else {
    shell python3 "code/03_table1_format.py"
}

* 04 and 05: Sophia's two-period DiD tables and Seohee's figures for them
do "code/04_did_tests.do"
do "code/05_did_graphs.do"

* 06 and 07: Sophia's panel tables and Seohee's panel event studies.
* 06 writes table2_plcbo with "append" only, so erase it first; otherwise
* every rerun adds two more columns to it.
capture erase "output/table2_plcbo.txt"
capture erase "output/table2_plcbo.xml"
do "code/06_panel_tables.do"
do "code/07_panel_event_study_graphs.do"

display "00_master.do finished: tables in output/, figures in output/figures/, logs in logs/"
