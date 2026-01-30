---
title: Fix probestack loop
status: closed
priority: 2
issue-type: task
created-at: "\"\\\"2026-01-30T11:27:10.542983+01:00\\\"\""
closed-at: "2026-01-30T12:58:43.173751+01:00"
close-reason: completed
---

Context: src/backends/aarch64/probestack.zig:144; cause: probestack loop TODO; fix: implement loop with label support; deps: label allocation; verification: add probestack tests + zig build test
