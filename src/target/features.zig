const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

/// CPU feature bit flags.
pub const Features = struct {
    /// Feature bits (up to 64 features).
    bits: u64,

    pub fn init() Features {
        return .{ .bits = 0 };
    }

    /// Enable a feature.
    pub fn enable(self: *Features, feature_bit: u6) void {
        self.bits |= @as(u64, 1) << feature_bit;
    }

    /// Disable a feature.
    pub fn disable(self: *Features, feature_bit: u6) void {
        self.bits &= ~(@as(u64, 1) << feature_bit);
    }

    /// Check if feature is enabled.
    pub fn has(self: Features, feature_bit: u6) bool {
        return (self.bits & (@as(u64, 1) << feature_bit)) != 0;
    }

    /// Merge features from another set.
    pub fn merge(self: *Features, other: Features) void {
        self.bits |= other.bits;
    }
};

/// AArch64 CPU features.
pub const AArch64Features = struct {
    pub const NEON: u6 = 0;
    pub const FP: u6 = 1;
    pub const CRC: u6 = 2;
    pub const LSE: u6 = 3; // Large System Extensions (atomics)
    pub const SVE: u6 = 4;
    pub const SVE2: u6 = 5;
    pub const SHA2: u6 = 6;
    pub const SHA3: u6 = 7;
    pub const AES: u6 = 8;
    pub const DOTPROD: u6 = 9;
    pub const FLAGM: u6 = 10;
    pub const BF16: u6 = 11;
    pub const I8MM: u6 = 12;

    /// Baseline AArch64 features (FP + NEON).
    pub fn baseline() Features {
        var features = Features.init();
        features.enable(FP);
        features.enable(NEON);
        return features;
    }

    /// All available features.
    pub fn all() Features {
        var features = baseline();
        features.enable(CRC);
        features.enable(LSE);
        features.enable(SHA2);
        features.enable(AES);
        features.enable(DOTPROD);
        return features;
    }
};

/// x86_64 CPU features.
pub const X86Features = struct {
    pub const SSE: u6 = 0;
    pub const SSE2: u6 = 1;
    pub const SSE3: u6 = 2;
    pub const SSSE3: u6 = 3;
    pub const SSE41: u6 = 4;
    pub const SSE42: u6 = 5;
    pub const AVX: u6 = 6;
    pub const AVX2: u6 = 7;
    pub const AVX512F: u6 = 8;
    pub const AVX512VL: u6 = 9;
    pub const AVX512BW: u6 = 10;
    pub const AVX512DQ: u6 = 11;
    pub const FMA: u6 = 12;
    pub const BMI1: u6 = 13;
    pub const BMI2: u6 = 14;
    pub const LZCNT: u6 = 15;
    pub const POPCNT: u6 = 16;
    pub const AES: u6 = 17;
    pub const PCLMULQDQ: u6 = 18;

    /// Baseline x86_64 features (SSE2).
    pub fn baseline() Features {
        var features = Features.init();
        features.enable(SSE);
        features.enable(SSE2);
        return features;
    }

    /// Modern x86_64 features.
    pub fn modern() Features {
        var features = baseline();
        features.enable(SSE3);
        features.enable(SSSE3);
        features.enable(SSE41);
        features.enable(SSE42);
        features.enable(POPCNT);
        features.enable(LZCNT);
        return features;
    }
};

/// Feature detection from CPU.
pub const FeatureDetector = struct {
    features: Features,
    allocator: Allocator,

    pub fn init(allocator: Allocator) FeatureDetector {
        return .{
            .features = Features.init(),
            .allocator = allocator,
        };
    }

    /// Detect features from current CPU using OS-specific APIs.
    pub fn detect(self: *FeatureDetector) !void {
        switch (builtin.cpu.arch) {
            .x86_64 => try self.detectX86(),
            .aarch64 => switch (builtin.os.tag) {
                .linux => try self.detectAArch64Linux(),
                .macos => try self.detectAArch64MacOS(),
                else => self.features = AArch64Features.baseline(),
            },
            else => self.features = Features.init(),
        }
    }

    fn detectX86(self: *FeatureDetector) !void {
        self.features = X86Features.baseline();

        const leaf1 = cpuid(1, 0);
        const leaf7 = cpuid(7, 0);

        // ECX bits from leaf 1
        if (leaf1[2] & (1 << 0) != 0) self.features.enable(X86Features.SSE3);
        if (leaf1[2] & (1 << 9) != 0) self.features.enable(X86Features.SSSE3);
        if (leaf1[2] & (1 << 19) != 0) self.features.enable(X86Features.SSE41);
        if (leaf1[2] & (1 << 20) != 0) self.features.enable(X86Features.SSE42);
        if (leaf1[2] & (1 << 25) != 0) self.features.enable(X86Features.AES);
        if (leaf1[2] & (1 << 1) != 0) self.features.enable(X86Features.PCLMULQDQ);
        if (leaf1[2] & (1 << 28) != 0) self.features.enable(X86Features.AVX);
        if (leaf1[2] & (1 << 12) != 0) self.features.enable(X86Features.FMA);

        // EDX bits from leaf 1
        if (leaf1[3] & (1 << 23) != 0) self.features.enable(X86Features.POPCNT);

        // EBX bits from leaf 7
        if (leaf7[1] & (1 << 3) != 0) self.features.enable(X86Features.BMI1);
        if (leaf7[1] & (1 << 5) != 0) self.features.enable(X86Features.AVX2);
        if (leaf7[1] & (1 << 8) != 0) self.features.enable(X86Features.BMI2);
        if (leaf7[1] & (1 << 16) != 0) self.features.enable(X86Features.AVX512F);
        if (leaf7[1] & (1 << 17) != 0) self.features.enable(X86Features.AVX512DQ);
        if (leaf7[1] & (1 << 30) != 0) self.features.enable(X86Features.AVX512BW);
        if (leaf7[1] & (1 << 31) != 0) self.features.enable(X86Features.AVX512VL);

        // LZCNT check
        const leaf80000001 = cpuid(0x80000001, 0);
        if (leaf80000001[2] & (1 << 5) != 0) self.features.enable(X86Features.LZCNT);
    }

    fn cpuid(leaf: u32, subleaf: u32) [4]u32 {
        var eax: u32 = leaf;
        var ebx: u32 = undefined;
        var ecx: u32 = subleaf;
        var edx: u32 = undefined;

        asm volatile ("cpuid"
            : [eax] "={eax}" (eax),
              [ebx] "={ebx}" (ebx),
              [ecx] "={ecx}" (ecx),
              [edx] "={edx}" (edx),
            : [eax_in] "{eax}" (eax),
              [ecx_in] "{ecx}" (ecx),
        );

        return [4]u32{ eax, ebx, ecx, edx };
    }

    fn detectAArch64Linux(self: *FeatureDetector) !void {
        const hwcap = try getHwCap();
        self.features = featuresFromHwCap(hwcap);
    }

    fn detectAArch64MacOS(self: *FeatureDetector) !void {
        const hwcap = try getHwCapMacOS();
        self.features = featuresFromHwCap(hwcap);
    }

    fn getHwCap() !u64 {
        const AT_HWCAP = 16;
        const auxv_file = try std.fs.openFileAbsolute("/proc/self/auxv", .{});
        defer auxv_file.close();

        var buf: [16]u8 = undefined;
        while (true) {
            const n = try auxv_file.read(&buf);
            if (n < 16) break;

            const key = std.mem.readInt(u64, buf[0..8], .little);
            const val = std.mem.readInt(u64, buf[8..16], .little);

            if (key == AT_HWCAP) return val;
            if (key == 0) break; // AT_NULL
        }

        return 0; // Not found
    }

    fn getHwCapMacOS() !u64 {
        // Use sysctlbyname
        var hwcap: u64 = 0;
        var len: usize = @sizeOf(u64);

        // Query hw.optional features
        // This is simplified - real implementation would check multiple sysctls
        const rc = std.c.sysctlbyname("hw.optional.arm.FEAT_LSE", &hwcap, &len, null, 0);
        if (rc == 0) {
            return hwcap;
        }

        return 0; // Feature detection failed - use baseline
    }

    fn featuresFromHwCap(hwcap: u64) Features {
        // Linux HWCAP bits (from linux/arch/arm64/include/uapi/asm/hwcap.h)
        const HWCAP_ASIMD = (1 << 1);
        const HWCAP_AES = (1 << 3);
        const HWCAP_SHA1 = (1 << 5);
        const HWCAP_SHA2 = (1 << 6);
        const HWCAP_CRC32 = (1 << 7);
        const HWCAP_ATOMICS = (1 << 8); // LSE
        const HWCAP_ASIMDDP = (1 << 20); // DotProd
        const HWCAP_SVE = (1 << 22);

        var feat = AArch64Features.baseline();

        if (hwcap & HWCAP_ASIMD != 0) feat.enable(AArch64Features.NEON);
        if (hwcap & HWCAP_AES != 0) feat.enable(AArch64Features.AES);
        if (hwcap & HWCAP_SHA1 != 0) feat.enable(AArch64Features.SHA2);
        if (hwcap & HWCAP_SHA2 != 0) feat.enable(AArch64Features.SHA2);
        if (hwcap & HWCAP_CRC32 != 0) feat.enable(AArch64Features.CRC);
        if (hwcap & HWCAP_ATOMICS != 0) feat.enable(AArch64Features.LSE);
        if (hwcap & HWCAP_ASIMDDP != 0) feat.enable(AArch64Features.DOTPROD);
        if (hwcap & HWCAP_SVE != 0) feat.enable(AArch64Features.SVE);

        return feat;
    }

    /// Parse features from string like "+neon,+crc,-sve".
    pub fn parseFeatures(self: *FeatureDetector, feature_str: []const u8) !void {
        var iter = std.mem.splitScalar(u8, feature_str, ',');
        while (iter.next()) |feature| {
            if (feature.len < 2) continue;

            const enable = feature[0] == '+';
            const disable = feature[0] == '-';
            if (!enable and !disable) continue;

            const name = feature[1..];
            const bit = try self.featureNameToBit(name);

            if (enable) {
                self.features.enable(bit);
            } else {
                self.features.disable(bit);
            }
        }
    }

    fn featureNameToBit(self: *FeatureDetector, name: []const u8) !u6 {
        _ = self;
        if (std.mem.eql(u8, name, "neon")) return AArch64Features.NEON;
        if (std.mem.eql(u8, name, "fp")) return AArch64Features.FP;
        if (std.mem.eql(u8, name, "crc")) return AArch64Features.CRC;
        if (std.mem.eql(u8, name, "lse")) return AArch64Features.LSE;
        if (std.mem.eql(u8, name, "sve")) return AArch64Features.SVE;
        if (std.mem.eql(u8, name, "sha2")) return AArch64Features.SHA2;
        if (std.mem.eql(u8, name, "aes")) return AArch64Features.AES;
        return error.UnknownFeature;
    }

    pub fn getFeatures(self: *const FeatureDetector) Features {
        return self.features;
    }
};

test "Features enable and has" {
    var features = Features.init();

    features.enable(5);
    try testing.expect(features.has(5));
    try testing.expect(!features.has(6));
}

test "Features disable" {
    var features = Features.init();

    features.enable(3);
    try testing.expect(features.has(3));

    features.disable(3);
    try testing.expect(!features.has(3));
}

test "Features merge" {
    var f1 = Features.init();
    f1.enable(1);
    f1.enable(2);

    var f2 = Features.init();
    f2.enable(2);
    f2.enable(3);

    f1.merge(f2);

    try testing.expect(f1.has(1));
    try testing.expect(f1.has(2));
    try testing.expect(f1.has(3));
}

test "AArch64Features baseline" {
    const features = AArch64Features.baseline();

    try testing.expect(features.has(AArch64Features.FP));
    try testing.expect(features.has(AArch64Features.NEON));
    try testing.expect(!features.has(AArch64Features.SVE));
}

test "FeatureDetector parseFeatures" {
    var detector = FeatureDetector.init(testing.allocator);

    try detector.parseFeatures("+neon,+crc,-fp");

    const features = detector.getFeatures();
    try testing.expect(features.has(AArch64Features.NEON));
    try testing.expect(features.has(AArch64Features.CRC));
    try testing.expect(!features.has(AArch64Features.FP));
}

test "FeatureDetector detect" {
    var detector = FeatureDetector.init(testing.allocator);
    try detector.detect();

    const features = detector.getFeatures();

    switch (builtin.cpu.arch) {
        .aarch64 => {
            try testing.expect(features.has(AArch64Features.FP));
            try testing.expect(features.has(AArch64Features.NEON));
        },
        .x86_64 => {
            try testing.expect(features.has(X86Features.SSE));
            try testing.expect(features.has(X86Features.SSE2));
        },
        else => {},
    }
}
