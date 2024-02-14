const std = @import("std");

pub fn Matrix(comptime h: usize, comptime w: usize, comptime T: type) type {
    return struct {
        const Self = @This();

        d: [h][w]T,

        pub fn init(data: [h][w]T) Self {
            return .{ .d = data };
        }

        pub fn identity() Self {
            if (h != w) {
                @compileError("only a squared matrix can have an identity");
            }

            var data: [h][w]T = [_][w]T{[_]T{0} ** w} ** h;
            inline for (0..h) |i| data[i][i] = 1;

            return Self.init(data);
        }

        /// h x w matrix multiplied by a w x n matrix gives a h x n
        pub fn multiply(self: *const Self, comptime n: usize, other: *const Matrix(w, n, T)) Matrix(h, n, T) {
            var data: [h][n]T = [_][n]T{[_]T{0} ** n} ** h;

            inline for (0..w) |w_i| {
                inline for (0..n) |n_i| {
                    inline for (0..h) |h_i| {
                        data[h_i][n_i] += self.d[h_i][w_i] * other.d[w_i][n_i];
                    }
                }
            }

            return Matrix(h, n, T).init(data);
        }

        // index hell
        pub fn inverse(self: *const Self) error{ NoInverse, OutOfBound }!Self {
            const FloatT = switch (@typeInfo(T)) {
                .Float => T,
                .Int => |i| switch (i.bits) {
                    0...16 => f16,
                    17...32 => f32,
                    33...64 => f64,
                    else => f128,
                },
                else => @compileError("invalid type"),
            };

            var foutput = Matrix(h, w, FloatT).identity().d;
            var fdata: [h][w]FloatT = switch (@typeInfo(T)) {
                .Float => self.d,
                .Int => arr: {
                    var array: [h][w]FloatT = undefined;
                    inline for (0..h) |i| {
                        inline for (0..w) |j| array[i][j] = @floatFromInt(self.d[i][j]);
                    }
                    break :arr array;
                },
                else => unreachable,
            };

            for (0..h - 1) |i| {
                var pivot = i;
                var pivot_value = fdata[i][i];
                if (pivot_value < 0) pivot_value = -pivot_value;

                for (i + 1..h) |j| {
                    var temp = fdata[j][i];
                    if (temp < 0) temp = -temp;

                    if (temp > pivot_value) {
                        pivot = j;
                        pivot_value = temp;
                    }
                }

                if (pivot_value == 0) return error.NoInverse;

                if (pivot != i) {
                    std.mem.swap([w]FloatT, &fdata[i], &fdata[pivot]);
                    std.mem.swap([w]FloatT, &foutput[i], &foutput[pivot]);
                }

                for (i + 1..h) |j| {
                    const v = fdata[j][i] / fdata[i][i];
                    for (0..h) |k| {
                        fdata[j][k] -= v * fdata[i][k];
                        foutput[j][k] -= v * foutput[i][k];
                    }
                }
            }

            for (0..h) |i| {
                const v = fdata[i][i];
                for (0..h) |j| {
                    fdata[i][j] = fdata[i][j] / v;
                    foutput[i][j] = foutput[i][j] / v;
                }
            }

            for (0..h - 1) |i| {
                for (i + 1..h) |j| {
                    const v = fdata[i][j];
                    for (0..h) |k| {
                        fdata[i][k] -= v * fdata[j][k];
                        foutput[i][k] -= v * foutput[j][k];
                    }
                }
            }

            return switch (@typeInfo(T)) {
                .Float => Matrix(h, w, T).init(foutput),
                .Int => |int| m: {
                    var array: [h][w]T = undefined;
                    inline for (0..h) |i| {
                        inline for (0..w) |j| {
                            if (int.signedness == .unsigned and foutput[i][j] < 0)
                                return error.OutOfBound;

                            array[i][j] = @intFromFloat(@round(foutput[i][j]));
                        }
                    }
                    break :m Matrix(h, w, T).init(array);
                },
                else => unreachable,
            };
        }
    };
}

/// It is a Homogeneous Point
pub fn Point3D(comptime T: type) type {
    return struct {
        const Self = @This();

        m: Matrix(4, 1, T),

        pub fn init(d: [3]T) Self {
            return .{ .m = Matrix(4, 1, T).init(.{ .{d[0]}, .{d[1]}, .{d[2]}, .{1} }) };
        }

        pub fn multiply(self: *const Self, matrix: *const Matrix(4, 4, T)) Self {
            const a = self.m.d[0][0] * matrix.d[0][0] + self.m.d[1][0] * matrix.d[1][0] + self.m.d[2][0] * matrix.d[2][0] + matrix.d[3][0];
            const b = self.m.d[0][0] * matrix.d[0][1] + self.m.d[1][0] * matrix.d[1][1] + self.m.d[2][0] * matrix.d[2][1] + matrix.d[3][1];
            const c = self.m.d[0][0] * matrix.d[0][2] + self.m.d[1][0] * matrix.d[1][2] + self.m.d[2][0] * matrix.d[2][2] + matrix.d[3][2];
            const w = self.m.d[0][0] * matrix.d[0][3] + self.m.d[1][0] * matrix.d[1][3] + self.m.d[2][0] * matrix.d[2][3] + matrix.d[3][3];

            return Self.init(.{ a / w, b / w, c / w });
        }
    };
}

test "matrix multiplication" {
    const matrix = Matrix(3, 4, u32).init(.{
        .{ 1, 2, 1, 2 },
        .{ 5, 1, 5, 1 },
        .{ 2, 3, 2, 3 },
    });

    const data = Matrix(4, 6, u32).init(.{
        .{ 2, 5, 1, 1, 5, 2 },
        .{ 6, 7, 8, 8, 7, 6 },
        .{ 1, 8, 3, 3, 8, 1 },
        .{ 2, 3, 1, 1, 3, 2 },
    });

    const result = matrix.multiply(6, &data);

    try std.testing.expectEqualSlices(u32, &[6]u32{ 19, 33, 22, 22, 33, 19 }, &result.d[0]);
    try std.testing.expectEqualSlices(u32, &[6]u32{ 23, 75, 29, 29, 75, 23 }, &result.d[1]);
    try std.testing.expectEqualSlices(u32, &[6]u32{ 30, 56, 35, 35, 56, 30 }, &result.d[2]);
}

test "matrix inverse" {
    const data = .{
        .{ 2, 1 },
        .{ 7, 4 },
    };
    const data_i = .{
        .{ 4, -1 },
        .{ -7, 2 },
    };

    const m1 = Matrix(2, 2, i32).init(data);
    const m1i = try m1.inverse();
    try std.testing.expectEqual(@as(i32, data_i[0][1]), m1i.d[0][1]);
    try std.testing.expectEqual(@as(i32, data_i[1][0]), m1i.d[1][0]);
    try std.testing.expectEqual(@as(i32, data_i[1][1]), m1i.d[1][1]);

    const m2 = Matrix(2, 2, f32).init(data);
    const m2i = try m2.inverse();
    try std.testing.expectApproxEqAbs(@as(f32, data_i[0][0]), m2i.d[0][0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, data_i[0][1]), m2i.d[0][1], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, data_i[1][0]), m2i.d[1][0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, data_i[1][1]), m2i.d[1][1], 1e-5);

    const m3 = Matrix(2, 2, u32).init(data);
    try std.testing.expectError(error.OutOfBound, m3.inverse());
}
