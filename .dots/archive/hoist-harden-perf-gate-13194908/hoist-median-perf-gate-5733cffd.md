---
title: Median perf gate
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T12:20:58.195056+01:00\\\"\""
closed-at: "2026-02-17T12:27:52.307167+01:00"
close-reason: implemented multi-sample metric parsing, median comparison, markdown table with sample counts, and JSON artifact emission in tools/perf_gate.zig
---

file: tools/perf_gate.zig. cause: gate compares single samples and loses stability. fix: parse all samples, compare medians, emit markdown+json. why: robust regression detection and tracking artifacts.
