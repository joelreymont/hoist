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
        switch (builtin.os.tag) {
            .linux => try self.detectLinux(),
            .macos => try self.detectMacOS(),
            else => self.features = AArch64Features.baseline(),
        }
    }

    fn detectLinux(self: *FeatureDetector) !void {
        // Read /proc/cpuinfo or getauxval(AT_HWCAP)
        const hwcap = try getHwCap();
        self.features = featuresFromHwCap(hwcap);
    }

    fn detectMacOS(self: *FeatureDetector) !void {
        // Use sysctl to query CPU features
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

    fn featuresFromHwCap(hwcap: u64) AArch64Features {
        // Linux HWCAP bits (from linux/arch/arm64/include/uapi/asm/hwcap.h)
        const HWCAP_ASIMD = (1 << 1);
        const HWCAP_AES = (1 << 3);
        const HWCAP_SHA1 = (1 << 5);
        const HWCAP_SHA2 = (1 << 6);
        const HWCAP_CRC32 = (1 << 7);
        const HWCAP_ATOMICS = (1 << 8); // LSE
        const HWCAP_FPHP = (1 << 9); // FP16
        const HWCAP_ASIMDHP = (1 << 10); // FP16 vector
        const HWCAP_ASIMDDP = (1 << 20); // DotProd
        const HWCAP_SVE = (1 << 22);

        var feat = AArch64Features.baseline();

        if (hwcap & HWCAP_ASIMD != 0) feat.neon = true;
        if (hwcap & HWCAP_AES != 0) feat.aes = true;
        if (hwcap & HWCAP_SHA1 != 0) feat.sha2 = true;
        if (hwcap & HWCAP_SHA2 != 0) feat.sha2 = true;
        if (hwcap & HWCAP_CRC32 != 0) feat.crc = true;
        if (hwcap & HWCAP_ATOMICS != 0) feat.lse = true;
        if (hwcap & HWCAP_FPHP != 0) feat.fp16 = true;
        if (hwcap & HWCAP_ASIMDDP != 0) feat.dotprod = true;
        if (hwcap & HWCAP_SVE != 0) feat.sve = true;

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
    try testing.expect(features.has(AArch64Features.FP));
    try testing.expect(features.has(AArch64Features.NEON));
}
