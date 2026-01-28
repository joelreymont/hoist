---
title: "P0.3: Disassemble generated code manually"
status: closed
priority: 2
issue-type: task
created-at: "2026-01-05T20:09:59.892479+02:00"
closed-at: "2026-01-05T21:00:38.212358+02:00"
---

Extract hex bytes from test output, write to /tmp/test.bin, disassemble with objdump -D -b binary -m aarch64 or lldb. Compare against expected assembly. Document in docs/e2e_failure_analysis.md
