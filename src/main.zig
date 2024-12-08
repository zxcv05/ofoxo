const std = @import("std");
const jdz = @import("jdz");
const zgl = @import("zgl");
const glfw = @import("glfw");

const log = std.log.scoped(.main);

const Engine = @import("engine.zig");

var outer = jdz.JdzAllocator(.{}).init();
var alloc = outer.allocator();

fn glfw_proc_address(p: glfw.GLProc, proc: [:0]const u8) ?zgl.binding.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}

fn glfw_error_callback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("GLFW: {}: {s}", .{ error_code, description });
}

pub fn main() !void {
    log.info("Hello world", .{});

    glfw.setErrorCallback(glfw_error_callback);

    log.debug("glfw.init(...)", .{});
    if (!glfw.init(.{ .platform = .any })) {
        log.err("failed to init GLFW: {?s}", .{glfw.getErrorString()});
        return error.glfw;
    }
    defer glfw.terminate();

    log.debug("engine.init(...)", .{});
    const engine = try Engine.init(alloc);
    defer engine.deinit();

    log.debug("zgl.loadExtensions(...)", .{});
    const proc: glfw.GLProc = undefined;
    try zgl.loadExtensions(proc, glfw_proc_address);

    log.debug("engine.setup_gl()", .{});
    Engine.setup_gl();

    log.debug("engine.load_sprites()", .{});
    try engine.load_spritesheets();

    log.debug("engine.run()", .{});
    try engine.run();
}
