const std = @import("std");
const zmath = @import("zmath");

const constants = @import("constants.zig");

const Point3f = zmath.Point3D(f32);
const Point3i = zmath.Point3D(i32);
const Matrix44f = zmath.Matrix(4, 4, f32);

pub fn main() !void {
    const cameraToWorld = Matrix44f.init([4][4]f32{
        .{ 0.871214, 0, -0.490904, 0 },
        .{ -0.192902, 0.919559, -0.342346, 0 },
        .{ 0.451415, 0.392953, 0.801132, 0 },
        .{ 14.777467, 29.361945, 27.993464, 1 },
    });
    const worldToCamera = try cameraToWorld.inverse();

    const file = try std.fs.cwd().createFile("render.svg", .{});
    defer file.close();
    var bw = std.io.bufferedWriter(file.writer());

    _ = try bw.write("<svg version=\"1.1\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" xmlns=\"http://www.w3.org/2000/svg\" height=\"512\" width=\"512\">\n");
    for (0..constants.NUM_TRIS) |i| {
        const v_world0 = constants.verts[constants.tris[i * 3]];
        const v_world1 = constants.verts[constants.tris[i * 3 + 1]];
        const v_world2 = constants.verts[constants.tris[i * 3 + 2]];

        const v_raster0 = computePixelCoordinates(2, 2, 512, 512, &v_world0, &worldToCamera);
        const v_raster1 = computePixelCoordinates(2, 2, 512, 512, &v_world1, &worldToCamera);
        const v_raster2 = computePixelCoordinates(2, 2, 512, 512, &v_world2, &worldToCamera);

        try writeLine(i32, v_raster0, v_raster1, bw.writer());
        try writeLine(i32, v_raster1, v_raster2, bw.writer());
        try writeLine(i32, v_raster2, v_raster0, bw.writer());
    }

    _ = try bw.write("</svg>\n");
    try bw.flush();
}

fn computePixelCoordinates(
    comptime canvas_height: f32,
    comptime canvas_width: f32,
    comptime image_height: u32,
    comptime image_width: u32,
    world: *const Point3f,
    world_to_camera: *const Matrix44f,
) Point3i {
    const camera = world.multiply(world_to_camera);

    const screen = Point3f.init(.{
        camera.m.d[0][0] / -camera.m.d[2][0],
        camera.m.d[1][0] / -camera.m.d[2][0],
        0,
    });

    const ndc = Point3f.init(.{
        (screen.m.d[0][0] + canvas_width * 0.5) / canvas_width,
        (screen.m.d[1][0] + canvas_height * 0.5) / canvas_height,
        0,
    });

    return Point3i.init(.{
        @as(i32, @intFromFloat(ndc.m.d[0][0] * image_width)),
        @as(i32, @intFromFloat((1 - ndc.m.d[1][0]) * image_height)),
        0,
    });
}

fn writeLine(comptime T: type, a: zmath.Point3D(T), b: zmath.Point3D(T), writer: anytype) !void {
    const fmt = "<line x1=\"{d}\" y1=\"{d}\" x2=\"{d}\" y2=\"{d}\" style=\"stroke:rgb(0,0,0);stroke-width:1\" />\n";
    return std.fmt.format(writer, fmt, .{ a.m.d[0][0], a.m.d[1][0], b.m.d[0][0], b.m.d[1][0] });
}
