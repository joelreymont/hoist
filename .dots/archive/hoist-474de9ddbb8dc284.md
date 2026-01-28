---
title: this
status: closed
priority: 2
issue-type: task
created-at: "2026-01-01T08:43:41.940633+02:00"
closed-at: "2026-01-01T09:05:17.954646+02:00"
close-reason: Replaced with correctly titled task
---

Port ISLE trie compiler from cranelift/isle/isle/src/trie_again.rs (~1000 LOC). Create src/dsl/isle/trie.zig with decision tree compilation for pattern matching. Depends on: sema (hoist-474de9a058740af5). Files: src/dsl/isle/trie.zig. Critical for efficient pattern matching.
