#!/bin/bash
# run_check.sh -- check that every number in the figures matches the tables
# Author: Ansh
#
# Re-runs Sophia's code/04_did_tests.do (tables) and Seohee's
# code/05_did_graphs.do (figures), then runs code/check_figures_vs_tables.py,
# which compares the 30 plotted numbers with the outreg2 tables. Must end with
# "30 match, 0 problem(s)".
#
#   bash code/run_check.sh            (from any folder)
#
# Outputs (same as running the two do-files): output/did_table1-4.txt/.xml,
# logs/04_did_tests.log, output/figures/fig_table*.png, figure_numbers.csv,
# logs/05_did_graphs.log.
# Set STATA=/path/to/stata if yours is somewhere else (e.g. stata-mp).
set -euo pipefail
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
STATA="${STATA:-/Applications/Stata/StataSE.app/Contents/MacOS/stata-se}"
TMP="$(mktemp -d)"   # batch-mode driver logs go here, not into the project
trap 'rm -rf "$TMP"' EXIT

fail() { echo "ERROR in $1 (see $2)"; exit 1; }

run_do() {  # run one project do-file in batch mode with $PROJ set
    printf 'global PROJ "%s"\ndo "%s/code/%s"\n' "$PROJ" "$PROJ" "$1" > "$TMP/run_$1"
    (cd "$TMP" && "$STATA" -b do "run_$1")
    local log="$TMP/run_${1%.do}.log"
    if grep -q '^r([0-9]*);' "$log"; then
        cp "$log" "$PROJ/logs/run_check_error.log"
        fail "$1" "logs/run_check_error.log"
    fi
}

echo "1/3 Running Sophia's code/04_did_tests.do ..."
run_do 04_did_tests.do

echo "2/3 Running Seohee's code/05_did_graphs.do ..."
run_do 05_did_graphs.do

echo "3/3 Comparing figures with tables ..."
python3 "$PROJ/code/check_figures_vs_tables.py" \
    --tables "$PROJ/output" --log "$PROJ/logs/04_did_tests.log" \
    --figs "$PROJ/output/figures/figure_numbers.csv"
