#!/bin/bash
# run_check.sh -- checks that every number in Seohee's figures matches Sophia's tables
# Author: Ansh
# Reruns code/04_did_tests.do (tables) and code/05_did_graphs.do (figures), then
# code/check_figures_vs_tables.py compares them. Must end with "30 match, 0 problem(s)".
# Run from any folder:  bash code/run_check.sh
# If Stata is somewhere else on your Mac, run:  STATA=/path/to/stata bash code/run_check.sh
set -euo pipefail
PROJ="$(cd "$(dirname "$0")/.." && pwd)"     # the project folder (one up from code/)
STATA="${STATA:-/Applications/Stata/StataSE.app/Contents/MacOS/stata-se}"
TMP="$(mktemp -d)"                            # Stata batch logs go here, not into the project
trap 'rm -rf "$TMP"' EXIT

# small Stata driver that goes to the project folder and runs one do-file
printf 'cd "%s"\ndo "code/04_did_tests.do"\n' "$PROJ" > "$TMP/run04.do"
printf 'cd "%s"\ndo "code/05_did_graphs.do"\n' "$PROJ" > "$TMP/run05.do"

echo "1/3 Running Sophia's code/04_did_tests.do ..."
(cd "$TMP" && "$STATA" -b do run04.do)
if grep -q '^r([0-9]*);' "$TMP/run04.log"; then
    cp "$TMP/run04.log" "$PROJ/logs/run_check_error.log"
    echo "ERROR in 04_did_tests.do (see logs/run_check_error.log)"
    exit 1
fi

echo "2/3 Running Seohee's code/05_did_graphs.do ..."
(cd "$TMP" && "$STATA" -b do run05.do)
if grep -q '^r([0-9]*);' "$TMP/run05.log"; then
    cp "$TMP/run05.log" "$PROJ/logs/run_check_error.log"
    echo "ERROR in 05_did_graphs.do (see logs/run_check_error.log)"
    exit 1
fi

echo "3/3 Comparing figures with tables ..."
python3 "$PROJ/code/check_figures_vs_tables.py"
