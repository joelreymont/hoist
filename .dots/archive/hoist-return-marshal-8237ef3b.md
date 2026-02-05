---
title: Return marshal
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-02T21:35:56.700575+01:00\""
closed-at: "2026-02-05T20:17:24.310037+01:00"
close-reason: Re-enable return marshaling tests with updated signature API
blocks:
  - hoist-struct-args-tests-4ddf9dee
---

File: build.zig:272; cause: aarch64_return_marshaling gated by makeSig API; fix: restore makeSig or update tests; why: return ABI coverage.
