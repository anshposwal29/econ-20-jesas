#!/bin/bash
# Re-runs Sophia's did_tests.do and Seohee's did_graphs.do, then checks that
# every number in the figures matches the regression tables.
#
#   bash code/run_check.sh
#
# Sophia's code is never edited: a temporary copy with only her `cd` line
# pointed at a temp folder is run there. Her tables and log are then copied to
# output/ and logs/. Set STATA=/path/to/stata if yours is somewhere else.
set -euo pipefail
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
STATA="${STATA:-/Applications/Stata/StataSE.app/Contents/MacOS/stata-se}"
TMP="$(mktemp -d)"
ln -s "$PROJ/final_data.dta" "$TMP/final_data.dta"

fail() { echo "ERROR in $1 (see $2)"; exit 1; }

echo "1/3 Running Sophia's code/did_tests.do ..."
sed "s#^cd .*#cd \"$TMP\"#" "$PROJ/code/did_tests.do" > "$TMP/did_tests.do"
(cd "$TMP" && "$STATA" -b do did_tests.do)
grep -q '^r([0-9]*);' "$TMP/did_tests.log" && fail did_tests.do "$TMP/did_tests.log"
cp "$TMP"/did_table*.txt "$TMP"/did_table*.xml "$PROJ/output/"
cp "$TMP/did_log.log" "$PROJ/logs/did_tests.log"

echo "2/3 Running Seohee's code/did_graphs.do ..."
printf 'cd "%s"\ndo "code/did_graphs.do"\n' "$PROJ" > "$TMP/run_graphs.do"
(cd "$TMP" && "$STATA" -b do run_graphs.do)
grep -q '^r([0-9]*);' "$TMP/run_graphs.log" && fail did_graphs.do "$TMP/run_graphs.log"

echo "3/3 Comparing figures with tables ..."
python3 "$PROJ/code/check_figures_vs_tables.py" --tables "$TMP" \
    --figs "$PROJ/output/figures/figure_numbers.csv"
