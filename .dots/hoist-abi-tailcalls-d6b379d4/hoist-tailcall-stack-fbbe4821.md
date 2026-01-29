---
title: Tailcall stack
status: closed
priority: 1
issue-type: task
created-at: "\"\\\"2026-01-29T12:34:39.861365+01:00\\\"\""
closed-at: "2026-01-29T15:17:41.172951+01:00"
---

File: src/backends/aarch64/isle_helpers.zig:3519; cause: stack arg TODO in tailcall helpers; fix: marshal overflow args and deallocate frame before branch; why: correct tailcalls.
