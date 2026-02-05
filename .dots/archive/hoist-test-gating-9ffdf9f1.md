---
title: Test gating
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-02T21:35:56.686657+01:00\\\"\""
closed-at: "2026-02-06T00:54:17.592798+01:00"
close-reason: Re-enabled isle_memory and fixed lowering coverage tests
blocks:
  - hoist-feature-plumbing-39b6ae02
---

File: build.zig:231-300; cause: multiple tests commented out due to API/feature gaps; fix: address gaps and re-enable tests; why: coverage and parity.
