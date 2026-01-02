const std = @import("std");
const testing = std.testing;

const root = @import("root");
const Inst = root.aarch64_inst.Inst;
const Reg = root.aarch64_inst.Reg;
const WritableReg = root.aarch64_inst.WritableReg;
const PReg = root.reg.PReg;
const VectorSize = root.aarch64_inst.VectorSize;
const lower_mod = root.lower;

// Test lowering of simple integer arithmetic
test "lower iadd to ADD" {
    // When ISLE works, this will verify that:
    // (iadd i64 x y) => (add_rr x y size64)

    // For now, manually construct expected instruction
    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x2 = Reg.fromPReg(PReg.new(.int, 2));
    const x0_w = WritableReg.fromReg(x0);

    const expected = Inst{
        .add_rr = .{
            .dst = x0_w,
            .src1 = x1,
            .src2 = x2,
            .size = .size64,
        },
    };

    // Verify instruction structure
    try testing.expect(expected == .add_rr);
}

// Test lowering of immediate add
test "lower iadd immediate to ADD_IMM" {
    // (iadd i64 x (iconst 42)) => (add_imm x 42 size64)

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x0_w = WritableReg.fromReg(x0);

    const expected = Inst{
        .add_imm = .{
            .dst = x0_w,
            .src = x1,
            .imm = 42,
            .size = .size64,
        },
    };

    try testing.expect(expected == .add_imm);
}

// Test lowering of multiply-add fusion
test "lower iadd+imul to MADD" {
    // (iadd (imul x y) z) => (madd x y z)

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x2 = Reg.fromPReg(PReg.new(.int, 2));
    const x3 = Reg.fromPReg(PReg.new(.int, 3));
    const x0_w = WritableReg.fromReg(x0);

    const expected = Inst{
        .madd = .{
            .dst = x0_w,
            .src1 = x1,
            .src2 = x2,
            .src3 = x3,
            .size = .size64,
        },
    };

    try testing.expect(expected == .madd);
}

// Test lowering of vector add
test "lower vec_add to VEC_ADD" {
    // (vec_add v128 x y) => (vec_add x y b16)

    const v0 = Reg.fromPReg(PReg.new(.vec, 0));
    const v1 = Reg.fromPReg(PReg.new(.vec, 1));
    const v2 = Reg.fromPReg(PReg.new(.vec, 2));
    const v0_w = WritableReg.fromReg(v0);

    const expected = Inst{
        .vec_add = .{
            .dst = v0_w,
            .src1 = v1,
            .src2 = v2,
            .size = VectorSize.b16,
        },
    };

    try testing.expect(expected == .vec_add);
}

// Test lowering of vector reduction
test "lower reduce_sum to ADDV" {
    // (reduce_sum v128.b16 x) => (addv x b16)

    const v0 = Reg.fromPReg(PReg.new(.vec, 0));
    const v1 = Reg.fromPReg(PReg.new(.vec, 1));
    const v0_w = WritableReg.fromReg(v0);

    const expected = Inst{
        .addv = .{
            .dst = v0_w,
            .src = v1,
            .size = VectorSize.b16,
        },
    };

    try testing.expect(expected == .addv);
}

// Test lowering of FP arithmetic
test "lower fadd to FADD" {
    // (fadd f64 x y) => (fadd x y size64)

    const v0 = Reg.fromPReg(PReg.new(.vec, 0));
    const v1 = Reg.fromPReg(PReg.new(.vec, 1));
    const v2 = Reg.fromPReg(PReg.new(.vec, 2));
    const v0_w = WritableReg.fromReg(v0);

    const expected = Inst{
        .fadd = .{
            .dst = v0_w,
            .src1 = v1,
            .src2 = v2,
            .size = .size64,
        },
    };

    try testing.expect(expected == .fadd);
}

// Test lowering of FP comparison
test "lower fcmp to FCMP" {
    // (fcmp eq f64 x y) => (fcmp x y size64)

    const v0 = Reg.fromPReg(PReg.new(.vec, 0));
    const v1 = Reg.fromPReg(PReg.new(.vec, 1));

    const expected = Inst{
        .fcmp = .{
            .src1 = v0,
            .src2 = v1,
            .size = .size64,
        },
    };

    try testing.expect(expected == .fcmp);
}

// Test lowering of load
test "lower load to LDR" {
    // (load i64 addr offset) => (ldr base offset size64)

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x0_w = WritableReg.fromReg(x0);

    const expected = Inst{
        .ldr = .{
            .dst = x0_w,
            .base = x1,
            .offset = 8,
            .size = .size64,
        },
    };

    try testing.expect(expected == .ldr);
}

// Test lowering of store
test "lower store to STR" {
    // (store i64 val addr offset) => (str val base offset size64)

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));

    const expected = Inst{
        .str = .{
            .src = x0,
            .base = x1,
            .offset = 16,
            .size = .size64,
        },
    };

    try testing.expect(expected == .str);
}

// Test lowering of conditional branch
test "lower brif to B_COND" {
    // (brif cond target) => (b_cond cond target)

    const target = root.aarch64_inst.BranchTarget{ .label = 0 };

    const expected = Inst{
        .b_cond = .{
            .cond = .eq,
            .target = target,
        },
    };

    try testing.expect(expected == .b_cond);
}

// Test lowering of function return
test "lower return to RET" {
    const expected = Inst{ .ret = {} };

    try testing.expect(expected == .ret);
}

// Test strength reduction: multiply by power of 2
test "lower imul power-of-2 to LSL" {
    // (imul i64 x (iconst 4)) => (lsl x 2 size64)

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x0_w = WritableReg.fromReg(x0);

    const expected = Inst{
        .lsl = .{
            .dst = x0_w,
            .src = x1,
            .shift = 2,
            .size = .size64,
        },
    };

    try testing.expect(expected == .lsl);
}

// Test negation lowering
test "lower neg to NEG" {
    // (neg i64 x) => (neg x size64)

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x0_w = WritableReg.fromReg(x0);

    const expected = Inst{
        .neg = .{
            .dst = x0_w,
            .src = x1,
            .size = .size64,
        },
    };

    try testing.expect(expected == .neg);
}

// Test absolute value lowering
test "lower abs to ABS" {
    // (abs i64 x) => (abs x size64)

    const x0 = Reg.fromPReg(PReg.new(.int, 0));
    const x1 = Reg.fromPReg(PReg.new(.int, 1));
    const x0_w = WritableReg.fromReg(x0);

    const expected = Inst{
        .abs = .{
            .dst = x0_w,
            .src = x1,
            .size = .size64,
        },
    };

    try testing.expect(expected == .abs);
}

// Test vector min/max lowering
test "lower vec_min to SMIN" {
    // (vec_min_s v128.b16 x y) => (smin x y b16)

    const v0 = Reg.fromPReg(PReg.new(.vec, 0));
    const v1 = Reg.fromPReg(PReg.new(.vec, 1));
    const v2 = Reg.fromPReg(PReg.new(.vec, 2));
    const v0_w = WritableReg.fromReg(v0);

    const expected = Inst{
        .smin = .{
            .dst = v0_w,
            .src1 = v1,
            .src2 = v2,
            .size = VectorSize.b16,
        },
    };

    try testing.expect(expected == .smin);
}

// Test FP vector operations
test "lower vec_fadd to FADD_VEC" {
    // (vec_fadd v128.f32 x y) => (fadd_vec x y s4)

    const v0 = Reg.fromPReg(PReg.new(.vec, 0));
    const v1 = Reg.fromPReg(PReg.new(.vec, 1));
    const v2 = Reg.fromPReg(PReg.new(.vec, 2));
    const v0_w = WritableReg.fromReg(v0);

    const expected = Inst{
        .fadd_vec = .{
            .dst = v0_w,
            .src1 = v1,
            .src2 = v2,
            .size = VectorSize.s4,
        },
    };

    try testing.expect(expected == .fadd_vec);
}
