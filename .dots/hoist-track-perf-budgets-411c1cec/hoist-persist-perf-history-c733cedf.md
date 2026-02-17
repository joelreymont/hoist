---
title: Persist perf history json
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-17T13:08:21.948979+01:00\""
closed-at: "2026-02-17T13:31:36.621494+01:00"
close-reason: implemented --history-json in tools/perf_gate.zig with timestamped JSONL append entries, wired through build.zig bench-gate via -Dbench-history-json-path, added unit test appendHistoryEntry appends JSON lines, and verified two consecutive bench-gate runs append 2 valid entries in /tmp/hoist-bench-history.jsonl
---

Context: tools/perf_gate.zig and build.zig bench-gate; cause: only latest report exists in /tmp and historical trend is lost; fix: add optional append-to-history JSON artifact with timestamped runs; deps: Track perf budgets continuously; verification: repeated bench-gate runs append valid entries.
