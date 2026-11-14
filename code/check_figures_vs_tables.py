"""Check that every number in Seohee's figures matches Sophia's regression tables.

Author: Ansh (code/check_figures_vs_tables.py)
Reads Sophia's tables output/did_table1-4.txt and her log logs/04_did_tests.log
(for the pre-trend joint F-test), and the plotted numbers that
code/05_did_graphs.do prints in logs/05_did_graphs.log, one line each, e.g.
    fig_table1_coefplot col1: b = .0123, se = .0456, N = 2402
Coefficients and SEs are compared at the decimals the table prints, N exactly.
Exits with 1 if anything differs. Writes nothing.
Run: python3 code/check_figures_vs_tables.py   (normally via bash code/run_check.sh)
"""
import re
import sys
from pathlib import Path

PROJ = Path(__file__).resolve().parents[1]  # the project folder (one up from code/)
TABLES = PROJ / "output"
LOG04 = PROJ / "logs" / "04_did_tests.log"
LOG05 = PROJ / "logs" / "05_did_graphs.log"


def parse_outreg(path):
    """Read an outreg2 .txt table: {(col, var): (coef, se, coef text)} and {(col, row name): (value, text)}."""
    rows = [line.rstrip("\n").split("\t") for line in open(path, encoding="utf-8", errors="replace")]
    coefs, stats = {}, {}
    i = 0
    while i < len(rows):
        r = rows[i]
        name = r[0].strip()
        if name and name != "VARIABLES" and len(r) > 1:
            # a coefficient row is followed by a row of (SEs) with a blank first cell
            nxt = rows[i + 1] if i + 1 < len(rows) else []
            is_coef = nxt and nxt[0].strip() == "" and any(c.strip().startswith("(") for c in nxt[1:])
            for c, cell in enumerate(r[1:], start=1):
                cell = cell.strip()
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


def read_figure_numbers(path):
    """Read the lines 05_did_graphs.do prints: {(figure, item): (b, se, N)}."""
    pattern = re.compile(r"^(\w+) (\w+): b = (\S+?)(?:, se = (\S+?))?(?:, N = (\S+))?\s*$")
    F = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        m = pattern.match(line)
        if m:
            b, se, n = m.group(3), m.group(4), m.group(5)
            F[(m.group(1), m.group(2))] = (float(b), float(se) if se else None, float(n) if n else None)
    return F


def decimals(s):
    return len(s.split(".")[1]) if "." in s else 0


def close(fig, table_val, table_str):
    """True if the figure number rounds to the number printed in the table."""
    tol = 0.5 * 10 ** (-decimals(table_str)) + 1e-9
    return abs(fig - table_val) <= tol


def main():
    T = {k: parse_outreg(TABLES / f"did_table{k}.txt") for k in (1, 2, 3, 4)}
    F = read_figure_numbers(LOG05)

    # which table cell each plotted number should equal: (figure, item) -> (table, column, variable)
    links = {
        ("fig_table1_means", "raw_did"): (1, 1, "ca_post19"),
        ("fig_table1_means_detrended", "raw_did"): (1, 3, "ca_post19"),
        ("fig_table2_means", "raw_did"): (2, 1, "ca_post19"),
        ("fig_table1_coefplot", "col1"): (1, 1, "ca_post19"),
        ("fig_table1_coefplot", "col2"): (1, 2, "ca_post19"),
        ("fig_table1_coefplot", "col3"): (1, 3, "ca_post19"),
        ("fig_table1_coefplot", "col4"): (1, 4, "ca_post19"),
        ("fig_table2_coefplot", "full_spec1"): (1, 1, "ca_post19"),
        ("fig_table2_coefplot", "full_spec2"): (1, 2, "ca_post19"),
        ("fig_table2_coefplot", "full_spec3"): (1, 4, "ca_post19"),
        ("fig_table2_coefplot", "placebo_spec1"): (2, 1, "ca_post19"),
        ("fig_table2_coefplot", "placebo_spec2"): (2, 2, "ca_post19"),
        ("fig_table2_coefplot", "placebo_spec3"): (2, 3, "ca_post19"),
        ("table3_reduced_form", "ca_post19"): (3, 3, "ca_post19"),
        ("fig_table3_firststage_coef", "onewoman"): (3, 1, "ca_post19"),
        ("fig_table3_firststage_coef", "sharewoman"): (3, 2, "ca_post19"),
        ("fig_table3_iv_coef", "onewoman"): (3, 4, "onewoman"),
        ("fig_table3_iv_coef", "sharewoman"): (3, 5, "sharewoman"),
    }
    for y in range(2010, 2018):
        links[("fig_table4_pretrend", f"ca_yr{y}")] = (4, 1, f"ca_yr{y}")
    fstats = {
        ("fig_table3_firststage_coef", "onewoman_F"): (3, 1),
        ("fig_table3_firststage_coef", "sharewoman_F"): (3, 2),
    }

    bad, rows = 0, []

    # coefficients, SEs and N
    for key, (t, col, var) in links.items():
        if key not in F:
            rows.append(("MISSING", *key, f"T{t} col{col} {var}", "not in 05_did_graphs.log", ""))
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

    # first-stage F statistics
    for key, (t, col) in fstats.items():
        tv = T[t][1].get((col, "First-stage F"))
        if key not in F:
            rows.append(("MISSING", *key, f"T{t} col{col} First-stage F", "not in 05_did_graphs.log", ""))
            bad += 1
            continue
        b = F[key][0]
        status = "OK" if tv and close(b, tv[0], tv[1]) else "DIFF"
        bad += status != "OK"
        rows.append((status, *key, f"T{t} col{col} First-stage F", f"F={b:.3f}", f"F={tv[1] if tv else '?'}"))

    # pre-trend joint test: the table does not print it, so read Sophia's log
    log = LOG04.read_text(errors="replace")
    m = re.search(r"test ca_yr2010.*?F\(\s*(\d+),\s*(\d+)\)\s*=\s*([\d.]+)\s*\n\s*Prob > F =\s*([\d.]+)", log, re.S)
    for item, group in (("joint_F", 3), ("joint_p", 4)):
        key = ("fig_table4_pretrend", item)
        if not m or key not in F:
            rows.append(("MISSING", *key, "04_did_tests.log pre-trend test", "", "not found"))
            bad += 1
            continue
        val = m.group(group)
        b = F[key][0]
        status = "OK" if close(b, float(val), val) else "DIFF"
        bad += status != "OK"
        rows.append((status, *key, "04_did_tests.log pre-trend test", f"{b:.4f}", val))

    # raw means graphs for the first stage: no table column (no controls), shown for information
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
