---
title: Persist perf history json
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.948979+01:00"
---

Context: tools/perf_gate.zig and build.zig bench-gate; cause: only latest report exists in /tmp and historical trend is lost; fix: add optional append-to-history JSON artifact with timestamped runs; deps: Track perf budgets continuously; verification: repeated bench-gate runs append valid entries.
