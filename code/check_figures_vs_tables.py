"""Check that every number in Seohee's figures matches Sophia's regression tables.

Reads
  - Sophia's outreg2 tables from code/did_tests.do (did_table1.txt ... did_table4.txt)
    and her log (did_log.log) for the pre-trend joint test
  - output/figures/figure_numbers.csv, written by code/did_graphs.do
Compares coefficients and SEs at the 3 decimals the tables print, F-statistics at
the precision printed, and sample sizes exactly. Exits 1 if anything differs.

Usage (normally called by code/run_check.sh):
  python3 code/check_figures_vs_tables.py --tables DIR --figs output/figures/figure_numbers.csv
"""
import argparse
import csv
import re
import sys
from pathlib import Path


def parse_outreg(path):
    """Return {(col, var): (coef, se)} and {(col, stat): value} from an outreg2 .txt."""
    rows = [line.rstrip("\n").split("\t") for line in open(path, encoding="utf-8", errors="replace")]
    coefs, stats = {}, {}
    i = 0
    while i < len(rows):
        r = rows[i]
        name = r[0].strip()
        if name and name not in ("VARIABLES",) and len(r) > 1:
            nxt = rows[i + 1] if i + 1 < len(rows) else []
            is_coef = nxt and nxt[0].strip() == "" and any(c.strip().startswith("(") for c in nxt[1:])
            for c, cell in enumerate(r[1:], start=1):
                cell = cell.strip()
                if not cell:
                    continue
                num = re.sub(r"[*,]", "", cell)
                try:
                    val = float(num)
                except ValueError:
                    continue
                if is_coef:
                    se = nxt[c].strip().strip("()") if c < len(nxt) else ""
                    coefs[(c, name)] = (val, float(se) if se else None, cell.replace("*", ""))
                else:
                    stats[(c, name)] = (val, num)
            if is_coef:
                i += 1
        i += 1
    return coefs, stats


def decimals(s):
    return len(s.split(".")[1]) if "." in s else 0


def close(fig, table_val, table_str):
    """True if fig rounds to the printed table value."""
    tol = 0.5 * 10 ** (-decimals(table_str)) + 1e-9
    return abs(fig - table_val) <= tol


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tables", required=True, help="folder with did_table*.txt and did_log.log")
    ap.add_argument("--figs", required=True, help="output/figures/figure_numbers.csv")
    a = ap.parse_args()
    tdir = Path(a.tables)

    T = {k: parse_outreg(tdir / f"did_table{k}.txt") for k in (1, 2, 3, 4)}
    F = {}
    for r in csv.DictReader(open(a.figs)):
        F[(r["figure"], r["item"])] = (float(r["b"]), float(r["se"]) if r["se"] else None,
                                       float(r["n"]) if r["n"] else None)

    # (figure, item) -> (table, column, variable)
    links = {
        ("fig_table1_means", "raw_did"): (1, 1, "ca_post19"),
        ("fig_table1_means_detrended", "raw_did"): (1, 3, "ca_post19"),
        ("fig_table2_means", "raw_did"): (2, 1, "ca_post19"),
        ("table3_reduced_form", "ca_post19"): (3, 3, "ca_post19"),
        ("fig_table3_firststage_coef", "onewoman"): (3, 1, "ca_post19"),
        ("fig_table3_firststage_coef", "sharewoman"): (3, 2, "ca_post19"),
        ("fig_table3_iv_coef", "onewoman"): (3, 4, "onewoman"),
        ("fig_table3_iv_coef", "sharewoman"): (3, 5, "sharewoman"),
    }
    for k in range(1, 5):
        links[("fig_table1_coefplot", f"col{k}")] = (1, k, "ca_post19")
    for s, col in zip((1, 2, 3), (1, 2, 4)):
        links[("fig_table2_coefplot", f"full_spec{s}")] = (1, col, "ca_post19")
    for s in (1, 2, 3):
        links[("fig_table2_coefplot", f"placebo_spec{s}")] = (2, s, "ca_post19")
    for y in range(2010, 2018):
        links[("fig_table4_pretrend", f"ca_yr{y}")] = (4, 1, f"ca_yr{y}")
    fstats = {
        ("fig_table3_firststage_coef", "onewoman_F"): (3, 1),
        ("fig_table3_firststage_coef", "sharewoman_F"): (3, 2),
    }

    bad, rows = 0, []
    for key, (t, col, var) in links.items():
        if key not in F:
            rows.append(("MISSING", *key, f"T{t} col{col} {var}", "not in figure_numbers.csv", ""))
            bad += 1
            continue
        b, se, n = F[key]
        coefs, stats = T[t]
        if (col, var) not in coefs:
            rows.append(("MISSING", *key, f"T{t} col{col} {var}", "not in table", ""))
            bad += 1
            continue
        tb, tse, tbs = coefs[(col, var)]
        ok_b = close(b, tb, tbs)
        ok_se = se is None or tse is None or close(se, tse, f"{tse:.3f}")
        tn = stats.get((col, "Observations"))
        ok_n = n is None or tn is None or int(n) == int(tn[0])
        status = "OK" if (ok_b and ok_se and ok_n) else "DIFF"
        bad += status != "OK"
        fig_txt = f"b={b:.3f}" + (f" se={se:.3f}" if se is not None else "") + (f" N={int(n)}" if n else "")
        tab_txt = f"b={tbs}" + (f" se={tse:.3f}" if tse is not None else "") + (f" N={int(tn[0])}" if tn else "")
        rows.append((status, *key, f"T{t} col{col} {var}", fig_txt, tab_txt))

    for key, (t, col) in fstats.items():
        b = F[key][0]
        tv = T[t][1].get((col, "First-stage F"))
        status = "OK" if tv and close(b, tv[0], tv[1]) else "DIFF"
        bad += status != "OK"
        rows.append((status, *key, f"T{t} col{col} First-stage F", f"F={b:.3f}", f"F={tv[1] if tv else '?'}"))

    # pre-trend joint test: the table does not print it, so read Sophia's log
    log = (tdir / "did_log.log").read_text(errors="replace")
    m = re.search(r"test ca_yr2010.*?F\(\s*(\d+),\s*(\d+)\)\s*=\s*([\d.]+)\s*\n\s*Prob > F =\s*([\d.]+)", log, re.S)
    if m:
        for item, val in (("joint_F", m.group(3)), ("joint_p", m.group(4))):
            b = F[("fig_table4_pretrend", item)][0]
            status = "OK" if close(b, float(val), val) else "DIFF"
            bad += status != "OK"
            rows.append((status, "fig_table4_pretrend", item, "did_log.log pre-trend test", f"{b:.4f}", val))
    else:
        rows.append(("MISSING", "fig_table4_pretrend", "joint test", "did_log.log", "", "not found"))
        bad += 1

    for key in F:
        if key[0].startswith("fig_table3_means"):
            rows.append(("INFO", *key, "no table column (raw means, no controls)", f"raw DiD={F[key][0]:.3f}", ""))

    w = [max(len(str(r[i])) for r in rows) for i in range(6)]
    print("  ".join(h.ljust(w[i]) for i, h in enumerate(["status", "figure", "item", "table cell", "figure value", "table value"])))
    for r in rows:
        print("  ".join(str(x).ljust(w[i]) for i, x in enumerate(r)))
    print(f"\n{sum(r[0] == 'OK' for r in rows)} match, {bad} problem(s)")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
