---
title: Add +5 win gate
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-02-21T19:21:15.501773+01:00\\\"\""
closed-at: "2026-02-21T19:23:24.562010+01:00"
close-reason: completed
---

Context: tools/perf_gate.zig:160-420; cause: gate blocks regressions but allows low-value wins; fix: add minimum positive improvement threshold gate for keep/discard loop; deps:none; verification: perf_gate tests + bench-compare self-check.
