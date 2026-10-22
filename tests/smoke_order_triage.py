"""Smoke test for the OrderTriage rules. Runs in the PR validation stage, no UiPath login needed."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "solutions/CicdDemo/OrderTriage"))

from main import GraphState, triage  # noqa: E402

CASES = [
    ({"order_id": "A-1", "amount_eur": 12500, "country": "DE"}, ("high", "manual-review")),
    ({"order_id": "A-2", "amount_eur": 300, "country": "ro"}, ("normal", "express")),
    ({"order_id": "A-3", "amount_eur": 300, "country": "FR"}, ("normal", "standard")),
    ({"order_id": "A-4", "amount_eur": 300, "country": "NL"}, ("normal", "express")),
]

failed = 0
for given, (priority, route) in CASES:
    out = triage(GraphState(**given))
    ok = (out.priority, out.route) == (priority, route)
    failed += not ok
    print(f"{'PASS' if ok else 'FAIL'} {given} -> {out.priority}/{out.route} (rules v{out.rules_version})")

sys.exit(1 if failed else 0)
