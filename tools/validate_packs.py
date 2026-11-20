#!/usr/bin/env python3
"""Validate Recall pack files. Usage: validate_packs.py Recall/Packs/*.json"""
import json, sys

ok = True
total = 0
for path in sys.argv[1:]:
    try:
        d = json.load(open(path))
        ids = [c["id"] for c in d["cards"]]
        assert len(ids) == len(set(ids)), "duplicate card ids"
        topics = {t["id"] for t in d["topics"]}
        for c in d["cards"]:
            assert c["topic"] in topics, f"{c['id']}: unknown topic {c['topic']}"
            assert c.get("q"), f"{c['id']}: empty question"
            if c["type"] == "flash":
                assert c.get("back"), f"{c['id']}: flash without back"
            elif c["type"] == "choice":
                o = c.get("options") or []
                assert len(o) >= 2 and 0 <= c["answer"] < len(o), f"{c['id']}: bad options/answer"
                assert len(set(o)) == len(o), f"{c['id']}: duplicate options"
            else:
                raise AssertionError(f"{c['id']}: unknown type {c['type']}")
        n = len(ids)
        total += n
        print(f"ok   {n:4d}  {d['id']:24s} {path}")
    except Exception as e:
        ok = False
        print(f"FAIL {path}: {e}")
print(f"total {total}")
sys.exit(0 if ok else 1)
