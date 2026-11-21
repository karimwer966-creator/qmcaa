#!/usr/bin/env python3
"""Evaluate exported QSMC opportunity audit rows with a chronological OOS split.

This is a descriptive close-to-close forward-return study, not an order-fill
simulator. It intentionally reports no result unless the user supplies an
actual Strategy Tester/live-history audit CSV.
"""
from __future__ import annotations

import argparse
import csv
import statistics
from collections import defaultdict
from datetime import datetime
from pathlib import Path


def parse_time(raw: str) -> datetime:
    raw = raw.strip()
    for fmt in ("%Y.%m.%d %H:%M", "%Y-%m-%d %H:%M", "%Y.%m.%d %H:%M:%S"):
        try:
            return datetime.strptime(raw, fmt)
        except ValueError:
            pass
    raise ValueError(f"unsupported audit timestamp: {raw!r}")


def number(row: dict[str, str], field: str) -> float:
    value = row.get(field, "").strip()
    return float(value) if value else 0.0


def load_rows(path: Path):
    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        sample = stream.read(2048)
        stream.seek(0)
        delimiter = ";" if sample.count(";") > sample.count(",") else ","
        reader = csv.DictReader(stream, delimiter=delimiter)
        required = {"time", "symbol", "timeframe", "model", "status", "direction", "close", "atr"}
        missing = required.difference(reader.fieldnames or [])
        if missing:
            raise ValueError("audit CSV missing columns: " + ", ".join(sorted(missing)))
        groups = defaultdict(list)
        for row in reader:
            if row.get("model") not in {"Sweep-MSS-FVG", "BOS-CHoCH-OB-Retest"}:
                continue
            row["_time"] = parse_time(row["time"])
            groups[(row["symbol"], row["timeframe"], row["model"])].append(row)
    for rows in groups.values():
        rows.sort(key=lambda row: row["_time"])
    return groups


def collect_events(groups, horizon: int, split: datetime, cost_r: float):
    reports = {"IN_SAMPLE": [], "OUT_OF_SAMPLE": []}
    for (_, _, model), rows in groups.items():
        last_used_index = -1
        for i, signal in enumerate(rows):
            if signal["status"] != "ACCEPTED" or signal["direction"] not in {"BUY", "SELL"}:
                continue
            future_i = i + horizon
            if future_i >= len(rows) or i <= last_used_index:
                continue
            entry_time, exit_time = signal["_time"], rows[future_i]["_time"]
            # Keep all forward outcomes on their side of the chronological split.
            bucket = "IN_SAMPLE" if entry_time < split else "OUT_OF_SAMPLE"
            if bucket == "IN_SAMPLE" and exit_time >= split:
                continue
            entry, exit_price, atr = number(signal, "close"), number(rows[future_i], "close"), number(signal, "atr")
            if entry <= 0 or atr <= 0:
                continue
            side = 1.0 if signal["direction"] == "BUY" else -1.0
            net_r = side * (exit_price - entry) / atr - cost_r
            reports[bucket].append((model, net_r, entry_time, exit_time))
            # Avoid repeated overlapping signals from the same active setup.
            last_used_index = future_i
    return reports


def summarize(label: str, events):
    print(f"{label}: n={len(events)}")
    if not events:
        print("  no evaluable events")
        return
    values = [event[1] for event in events]
    gains = sum(x for x in values if x > 0)
    losses = -sum(x for x in values if x < 0)
    pf = gains / losses if losses else float("inf") if gains else 0.0
    equity = peak = max_dd = 0.0
    for event in sorted(events, key=lambda item: item[2]):
        equity += event[1]
        peak = max(peak, equity)
        max_dd = max(max_dd, peak - equity)
    print(f"  win_rate={sum(x > 0 for x in values) / len(values):.3f} "
          f"mean_R={statistics.mean(values):.3f} median_R={statistics.median(values):.3f} "
          f"profit_factor={pf:.3f} max_drawdown_R={max_dd:.3f}")
    for model in sorted({event[0] for event in events}):
        subset = [event[1] for event in events if event[0] == model]
        print(f"  {model}: n={len(subset)} mean_R={statistics.mean(subset):.3f} "
              f"win_rate={sum(x > 0 for x in subset) / len(subset):.3f}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audit_csv", type=Path)
    parser.add_argument("--test-start", required=True,
                        help="first out-of-sample date/time in broker-server time (YYYY-MM-DD[ HH:MM])")
    parser.add_argument("--horizon", type=int, default=12, help="forward closed bars per evaluation")
    parser.add_argument("--cost-r", type=float, default=0.0,
                        help="round-trip friction in R units; set from symbol/spread assumptions")
    args = parser.parse_args()
    if args.horizon < 1 or args.cost_r < 0:
        parser.error("horizon must be positive and cost-r non-negative")
    split_raw = args.test_start
    split = datetime.strptime(split_raw, "%Y-%m-%d %H:%M" if " " in split_raw else "%Y-%m-%d")
    reports = collect_events(load_rows(args.audit_csv), args.horizon, split, args.cost_r)
    print("Descriptive close-to-close R study only; no fill/slippage model or probability claim.")
    print(f"split={split} horizon={args.horizon} bars cost={args.cost_r:.3f}R")
    summarize("IN_SAMPLE", reports["IN_SAMPLE"])
    summarize("OUT_OF_SAMPLE", reports["OUT_OF_SAMPLE"])


if __name__ == "__main__":
    main()
