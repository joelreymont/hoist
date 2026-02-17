---
title: Repeat baseline runs
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T12:20:58.149268+01:00\\\"\""
closed-at: "2026-02-17T12:21:24.656164+01:00"
close-reason: added --repeat support with per-run bench sections and input validation in tools/baseline.zig
---

file: tools/baseline.zig. cause: one-shot sampling is noisy. fix: add --repeat and emit repeated bench sections. why: improve confidence for median-based gating.
