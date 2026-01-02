Run VM-specific tests.

Run tests for all VM crates:
```
cargo test -p bebop-vm-core -p bebop-vm-jit -p bebop-vm-validator
```

Report test results for each crate separately.
If validator tests fail, this indicates SSA/JIT semantic mismatch - investigate carefully.
