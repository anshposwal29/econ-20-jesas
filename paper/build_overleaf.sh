#!/bin/bash
# build_overleaf.sh -- copies the tables and figures the paper uses into paper/,
# then zips paper/ into paper/overleaf.zip for Overleaf (New Project > Upload Project).
# Run after rerunning the Stata/Python code:  bash paper/build_overleaf.sh
set -euo pipefail
P="$(cd "$(dirname "$0")" && pwd)"     # the paper folder
OUT="$P/../output"
mkdir -p "$P/tables" "$P/figures"

# every table and figure that main.tex uses
for t in $(grep -o 'input{tables/[^}]*}' "$P/main.tex" | sed 's#input{tables/##; s#}##'); do
    cp "$OUT/$t" "$P/tables/"
done
for f in $(grep -o '{[A-Za-z0-9_]*\.png}' "$P/main.tex" | tr -d '{}'); do
    if [ -f "$OUT/figures/$f" ]; then cp "$OUT/figures/$f" "$P/figures/"; fi   # doc_* figures are already in figures/
done

cd "$P" && rm -f overleaf.zip && zip -qr overleaf.zip main.tex tables figures
echo "wrote paper/overleaf.zip"
