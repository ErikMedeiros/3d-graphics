const std = @import("std");
const zmath = @import("zmath");
const KONST = @import("konstant.zig");

const Point3f = zmath.Point3D(f32);
const Point3i = zmath.Point3D(i32);
const Matrix44f = zmath.Matrix(4, 4, f32);

const FitResolutionGate = enum { fill, overscan };

pub fn main() !void {
    try render("35_0825x0446_01_512x512.svg", 35, .{ 0.825, 0.446 }, .{ 512, 512 }, 0.1, .overscan);
    std.debug.print("\n", .{});
    try render("55_0825x0446_01_512x512.svg", 55, .{ 0.825, 0.446 }, .{ 512, 512 }, 0.1, .overscan);
    std.debug.print("\n", .{});
    try render("35_0980x0735_01_640x480.svg", 35, .{ 0.980, 0.735 }, .{ 640, 480 }, 0.1, .overscan);
    std.debug.print("\n", .{});
    try render("55_0980x0735_01_640x480.svg", 55, .{ 0.980, 0.735 }, .{ 640, 480 }, 0.1, .overscan);
    std.debug.print("\n", .{});
    try render("35_1995x1500_01_640x480.svg", 35, .{ 1.995, 1.500 }, .{ 640, 480 }, 0.1, .overscan);
}

const inchToMm = 25.4;

fn render(
    comptime filename: []const u8,
    /// in mm
    comptime focalLength: f32,
    /// in inches
    comptime filmAperture: [2]f32,
    /// in pixels
    comptime image_resolution: [2]usize,
    comptime nearClippingPlane: f32,
    comptime fitFilm: FitResolutionGate,
) !void {
    const filmAspectRatio = filmAperture[0] / filmAperture[1];
    const deviceAspectRatio = image_resolution[0] / image_resolution[1];

    comptime var top = ((filmAperture[1] * inchToMm / 2) / focalLength) * nearClippingPlane;
    comptime var right = ((filmAperture[0] * inchToMm / 2) / focalLength) * nearClippingPlane;

    comptime var xscale = 1.0;
    comptime var yscale = 1.0;

    switch (fitFilm) {
        .fill => if (filmAspectRatio > deviceAspectRatio) {
            xscale = deviceAspectRatio / filmAspectRatio;
        } else {
            yscale = filmAspectRatio / deviceAspectRatio;
        },
        .overscan => if (filmAspectRatio > deviceAspectRatio) {
            yscale = filmAspectRatio / deviceAspectRatio;
        } else {
            xscale = deviceAspectRatio / filmAspectRatio;
        },
    }

    right *= xscale;
    top *= yscale;
    const bottom = -top;
    const left = -right;

    std.debug.print("Screen window coordinates: ({d:.2}, {d:.2}, {d:.2}, {d:.2})\n", .{ top, right, bottom, left });
    std.debug.print("Film Aspect Ratio: {d:.2}\nDevice Aspect Ratio: {d:.2}\n", .{ filmAspectRatio, deviceAspectRatio });
    std.debug.print("Angle of view: {d:.2} (deg)\n", .{2 * std.math.atan((filmAperture[0] * inchToMm / 2) / focalLength) * 180 / std.math.pi});

    const cameraToWorld = Matrix44f.init(.{
        .{ -0.95424, 0, 0.299041, 0 },
        .{ 0.0861242, 0.95763, 0.274823, 0 },
        .{ -0.28637, 0.288002, -0.913809, 0 },
        .{ -3.734612, 7.610426, -14.152769, 1 },
    });
    const worldToCamera = try cameraToWorld.inverse();

    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    var bw = std.io.bufferedWriter(file.writer());

    try std.fmt.format(
        bw.writer(),
        "<svg version=\"1.1\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" xmlns=\"http://www.w3.org/2000/svg\" height=\"{d}\" width=\"{d}\">\n",
        .{ image_resolution[1], image_resolution[0] },
    );

    for (0..KONST.NUM_TRIS) |i| {
        const v_world0 = KONST.verts[KONST.tris[i * 3]];
        const v_world1 = KONST.verts[KONST.tris[i * 3 + 1]];
        const v_world2 = KONST.verts[KONST.tris[i * 3 + 2]];

        var p_raster0: Point3i = undefined;
        const v_raster0 = computePixelCoordinates(image_resolution, top, right, bottom, left, nearClippingPlane, &worldToCamera, &v_world0, &p_raster0);

        var p_raster1: Point3i = undefined;
        const v_raster1 = computePixelCoordinates(image_resolution, top, right, bottom, left, nearClippingPlane, &worldToCamera, &v_world1, &p_raster1);

        var p_raster2: Point3i = undefined;
        const v_raster2 = computePixelCoordinates(image_resolution, top, right, bottom, left, nearClippingPlane, &worldToCamera, &v_world2, &p_raster2);

        const color: u8 = if (v_raster0 and v_raster1 and v_raster2) 0 else 255;

        const fmt = "<line x1=\"{d:.2}\" y1=\"{d:.2}\" x2=\"{d:.2}\" y2=\"{d:.2}\" style=\"stroke:rgb({d:.2},0,0);stroke-width:1\" />\n";

        try std.fmt.format(bw.writer(), fmt, .{ p_raster0.x(), p_raster0.y(), p_raster1.x(), p_raster1.y(), color });
        try std.fmt.format(bw.writer(), fmt, .{ p_raster1.x(), p_raster1.y(), p_raster2.x(), p_raster2.y(), color });
        try std.fmt.format(bw.writer(), fmt, .{ p_raster2.x(), p_raster2.y(), p_raster0.x(), p_raster0.y(), color });
    }

    _ = try bw.write("</svg>\n");
    try bw.flush();
}

fn computePixelCoordinates(
    comptime image_resolution: [2]usize,
    comptime top: f32,
    comptime right: f32,
    comptime bottom: f32,
    comptime left: f32,
    comptime near: f32,
    world_to_camera: *const Matrix44f,
    world: *const Point3f,
    raster: *Point3i,
) bool {
    const camera = world.multiply(world_to_camera);

    const screen = Point3f.init(.{
        camera.x() / -camera.z() * near,
        camera.y() / -camera.z() * near,
        0,
    });

    const ndc = Point3f.init(.{
        (screen.x() + right) / (2 * right),
        (screen.y() + top) / (2 * top),
        0,
    });

    raster.* = Point3i.init(.{
        @as(i32, @intFromFloat(ndc.x() * image_resolution[0])),
        @as(i32, @intFromFloat((1 - ndc.y()) * image_resolution[1])),
        0,
    });

    return !(screen.x() < left or screen.x() > right or screen.y() < bottom or screen.y() > top);
}
