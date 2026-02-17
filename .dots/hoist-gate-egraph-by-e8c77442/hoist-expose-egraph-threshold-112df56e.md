---
title: Expose egraph threshold option
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-02-17T13:08:21.907546+01:00\\\"\""
closed-at: "2026-02-17T13:28:27.929750+01:00"
close-reason: added configurable egraph_min_complexity on compile.Target with default, threaded through src/context.zig Context and ContextBuilder, and covered by tests (target init, shouldRunEGraph custom threshold, Context builder/value tests); full suite passed
---

Context: src/context.zig builder options and target config; cause: threshold tuning requires source edits today; fix: add configurable threshold through context/build options; deps: Gate egraph on complexity threshold; verification: option toggles behavior and is validated by tests.
