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
        pub fn inverse(self: *const Self) !Self {
            var output = Self.identity();
            var clone = Self.init(self.d);

            for (0..h - 1) |i| {
                var pivot = i;
                var pivot_value = clone.d[i][i];
                if (pivot_value < 0) pivot_value = -pivot_value;

                for (i + 1..h) |j| {
                    var temp = clone.d[j][i];
                    if (temp < 0) temp = -temp;

                    if (temp > pivot_value) {
                        pivot = j;
                        pivot_value = temp;
                    }
                }

                if (pivot_value == 0)
                    return error.NoInverse;

                if (pivot != i) {
                    std.mem.swap([w]T, &clone.d[i], &clone.d[pivot]);
                    std.mem.swap([w]T, &output.d[i], &output.d[pivot]);
                }

                for (i + 1..h) |j| {
                    const v = clone.d[j][i] / clone.d[i][i];

                    for (0..h) |k| {
                        clone.d[j][k] -= v * clone.d[i][k];
                        output.d[j][k] -= v * output.d[i][k];
                    }
                }
            }

            for (0..h) |i| {
                const v = clone.d[i][i];
                for (0..h) |j| {
                    clone.d[i][j] = clone.d[i][j] / v;
                    output.d[i][j] = output.d[i][j] / v;
                }
            }

            for (0..h - 1) |i| {
                for (i + 1..h) |j| {
                    const v = clone.d[i][j];
                    for (0..h) |k| {
                        clone.d[i][k] -= v * clone.d[j][k];
                        output.d[i][k] -= v * output.d[j][k];
                    }
                }
            }

            return output;
        }
    };
}

/// It is a Homogeneous Point
pub fn Point3D(comptime T: type) type {
    return struct {
        const Self = @This();

        m: Matrix(4, 1, T),

        pub fn init(d: [3]T) Self {
            return .{ .d = [4]T{ d[0], d[1], d[2], 1 } };
        }

        pub fn multiply(self: *Self, matrix: *const Matrix(4, 4, T)) *Self {
            const result = matrix.multiply(1, self.m);

            self.m[0][0] = @as(T, @divExact(result.d[0], result.d[3]));
            self.m[1][0] = @as(T, @divExact(result.d[1], result.d[3]));
            self.m[2][0] = @as(T, @divExact(result.d[2], result.d[3]));
            self.m[3][0] = 1;

            return self;
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
    const matrix = Matrix(2, 2, f32).init(.{
        .{ 2, 1 },
        .{ 7, 4 },
    });

    const inverse = try matrix.inverse();

    try std.testing.expectApproxEqAbs(@as(f32, 4), inverse.d[0][0], 1E-5);
    try std.testing.expectApproxEqAbs(@as(f32, -1), inverse.d[0][1], 1E-5);

    try std.testing.expectApproxEqAbs(@as(f32, -7), inverse.d[1][0], 1E-5);
    try std.testing.expectApproxEqAbs(@as(f32, 2), inverse.d[1][1], 1E-5);
}
