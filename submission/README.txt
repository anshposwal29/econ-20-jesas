ECON 20 final project (JESAS) -- programs and log files

Run order (code/00_master.do runs 01b onward):
  01_build_data.do                 builds final_data.dta from the raw WRDS files
  01b_collinearity_tests.do        checks the candidate control variables
  02_balance_test.do               Table 1: means and balance test
  03_table1_format.py              formats Table 1 (Python; no regressions)
  04_did_tests.do                  Table 2 pre-trends, Table 3 DiD, Table 4 placebo, Table 5 IV
  07_panel_event_study_graphs.do   Figure 1: ln(market cap) event study, original vs detrended
  11_graphs_reduced_form.do        Figure 2: average ln(market cap) by year
  10_graphs_first_stage_sharewm.do Figure 3: average percent of the board that is women by year

Each program writes logs/<program name>.log.
