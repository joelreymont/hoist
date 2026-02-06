---
title: Implement i128 bit-count lowering
status: closed
priority: 2
issue-type: task
created-at: "\"2026-02-06T23:16:30.475952+01:00\""
closed-at: "2026-02-06T23:39:29.024501+01:00"
close-reason: Wired clz/cls/popcnt i128 rules; added helper-level tests; fixed missing type extractors in aarch64 ISLE glue
---

Full context: /Users/joel/Work/hoist/src/backends/aarch64/lower.isle:1729-1744 still lowers clz/ctz/cls/popcnt i128 to aarch64_unimplemented while /Users/joel/Work/hoist/src/backends/aarch64/isle_helpers.zig:6387-6616 already implements lower_clz128/lower_cls128/lower_popcnt128. Cause: missing ISLE rule wiring. Fix: wire rules via emit_regs + helper constructors and add lowering tests proving unimplemented opcode is no longer emitted for i128 clz/cls/popcnt. Dependencies: none. Est: 30m
