---
title: Expose egraph threshold option
status: open
priority: 2
issue-type: task
created-at: "2026-02-17T13:08:21.907546+01:00"
---

Context: src/context.zig builder options and target config; cause: threshold tuning requires source edits today; fix: add configurable threshold through context/build options; deps: Gate egraph on complexity threshold; verification: option toggles behavior and is validated by tests.
