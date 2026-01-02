Rebuild the LALRPOP grammar after changes.

When grammar.lalrpop is modified, the pre-generated grammar.rs must be deleted and rebuilt:

1. Delete: `rm parser/src/grammar.rs`
2. Rebuild: `cargo build -p bebop-parser`
3. Verify the new grammar.rs was generated
4. Run tests: `cargo test -p bebop-parser`

Report any grammar errors or conflicts.
