---
title: Add CCMP AND chain pattern
status: closed
priority: 2
issue-type: task
created-at: "\"2026-01-16T14:52:31.694759+02:00\""
closed-at: "2026-01-23T14:56:42.542221+02:00"
---

In lower.isle, add CCMP pattern for AND of comparisons. Emit CCMP instead of CMP+B.cond+CMP. Deps: none. Verify: zig build test
