### Reference
- Cranelift source: `~/Work/wasmtime/cranelift/`

### Code Quality
- No dead code
- No `@panic` - use `!` error returns
- Type safety - enums, tagged unions, comptime
- Named constants, no magic numbers
- **Prefer Zig stdlib over blind porting**: Carefully consider `std.bit_set`, `std.HashMap`, `std.ArrayList`, etc. before reimplementing Rust data structures; add thin wrappers only when necessary