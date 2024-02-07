const std = @import("std");
const zmath = @import("zmath");

const Point3f = zmath.Point3D(f32);
const Point3u = zmath.Point3D(u32);
const Matrix44f = zmath.Matrix(4, 4, f32);

fn computePixelCoordinates(
    comptime canvas_height: f32,
    comptime canvas_width: f32,
    comptime image_height: f32,
    comptime image_width: f32,
    world: *const Point3f,
    world_to_camera: *const Matrix44f,
) Point3u {
    const camera = world_to_camera.multiply(world);
    const screen = Point3f.init(.{ camera.m[0] / -camera.m[2], camera.m[0] / -camera.m[2], 0 });
    const ndc = Point3f.init(.{
        (screen.m[0] + canvas_width * 0.5) / canvas_width,
        (screen.m[1] + canvas_height * 0.5) / canvas_height,
        0,
    });

    return Point3u.init(.{
        @as(u32, ndc.m[0] * image_width),
        @as(u32, ndc.m[1] * image_height),
        0,
    });
}

pub fn main() !void {
    const cameraToWorld = Matrix44f.init(.{
        .{ 0.871214, 0, -0.490904, 0 },
        .{ -0.192902, 0.919559, -0.342346, 0 },
        .{ 0.451415, 0.392953, 0.801132, 0 },
        .{ 14.777467, 29.361945, 27.993464, 1 },
    });
    const worldToCamera = cameraToWorld.inverse();
    _ = worldToCamera;
}
