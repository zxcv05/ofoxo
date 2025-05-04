const std = @import("std");
const zgl = @import("zgl");
const glfw = @import("glfw");

const cli = @import("cli.zig");

const Context = @import("context.zig");
const Engine = @import("engine.zig");

const log = std.log.scoped(.main);

fn glfw_proc_address(p: glfw.GLproc, proc: [:0]const u8) ?zgl.binding.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}

fn glfw_error_callback(error_code: glfw.ErrorCode, description: [*:0]u8) callconv(.c) void {
    std.log.err("GLFW: {}: {s}", .{ error_code, description });
}

pub fn main() !void {
    var outer: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const alloc = outer.allocator();

    log.info("Hello world", .{});

    log.debug("cli.parse_cli(...)", .{});
    var context = Context{};
    if (!try cli.parse_cli(alloc, &context)) return;

    _ = glfw.setErrorCallback(glfw_error_callback);

    log.debug("glfw.init(...)", .{});
    glfw.init() catch |e| {
        log.err("failed to init GLFW: {s}", .{@errorName(e)});
        return e;
    };
    defer glfw.terminate();

    log.debug("engine.init(...)", .{});
    var engine = try Engine.init(alloc, context);
    defer engine.deinit();

    log.debug("zgl.loadExtensions(...)", .{});
    const proc: glfw.GLproc = undefined;
    try zgl.loadExtensions(proc, glfw_proc_address);

    log.debug("engine.setup_gl()", .{});
    Engine.setup_gl();

    log.debug("engine.load_spritesheet()", .{});
    try engine.load_spritesheet();

    log.debug("engine.run()", .{});
    try engine.run();
}
