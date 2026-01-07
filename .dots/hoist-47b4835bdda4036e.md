---
title: Integrate rematerialization into spilling
status: closed
priority: 2
issue-type: task
created-at: "2026-01-06T11:08:03.785136+02:00"
closed-at: "2026-01-07T06:30:44.180915+02:00"
---

File: src/regalloc/spilling.zig - In chooseSpillCandidate: prefer spilling rematerializable values (lower cost). When inserting reload: check if rematerializable, call insertRemat instead of insertReload. Track remat_count for metrics. Dependencies: hoist-47b482e90bfdbd62, hoist-47b46fed94cea143, hoist-47b470c17cefd762.
