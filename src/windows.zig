const std = @import("std");
const glfw = @import("glfw");

const Windows = @This();

const log = std.log.scoped(.window);

const Bounds = struct {
    x: u32,
    y: u32,
    width: u32,
    height: u32,
};

const Window = struct {
    bounds: Bounds,
    backend: glfw.Window,

    pub fn init(bounds: Bounds, root_window: ?Window) !Window {
        const backend = glfw.Window.create(
            bounds.width,
            bounds.height,
            "ofoxo",
            null,
            if (root_window) |window| window.backend else null,
            .{
                .opengl_profile = .opengl_core_profile,
                .opengl_forward_compat = true,
                .context_version_major = 4,
                .context_version_minor = 5,

                .position_x = @intCast(bounds.x),
                .position_y = @intCast(bounds.y),

                .transparent_framebuffer = true,
                .mouse_passthrough = true,
                .doublebuffer = true,
                .decorated = false,
                .resizable = false,
                .floating = true,
                .visible = true,
            },
        ) orelse {
            log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
            return error.glfw;
        };

        return Window{
            .backend = backend,
            .bounds = bounds,
        };
    }

    pub fn deinit(this: Window) void {
        this.backend.destroy();
    }
};

windows: []Window,

pub fn init(allocator: std.mem.Allocator) !Windows {
    const monitors = try glfw.Monitor.getAll(allocator);
    defer allocator.free(monitors);

    var windows = try allocator.alloc(Window, monitors.len);
    for (monitors, 0..) |monitor, i| {
        const workarea = monitor.getWorkarea();
        const bounds = Bounds{
            .x = workarea.x,
            .y = workarea.y,
            .width = workarea.width,
            .height = workarea.height,
        };

        windows[i] = try Window.init(bounds, if (i > 0) windows[0] else null);
        log.debug("Window ({any}) created", .{windows[i].bounds});
    }

    glfw.makeContextCurrent(windows[0].backend);

    return Windows{
        .windows = windows,
    };
}

pub fn deinit(this: Windows, allocator: std.mem.Allocator) void {
    defer allocator.free(this.windows);
    for (this.windows) |window| {
        window.deinit();
    }
}

pub fn find_window_containing(this: Windows, x_pos: isize, y_pos: isize) ?*const Window {
    if (x_pos < 0 or y_pos < 0) return null;

    const x: u32 = @intCast(x_pos);
    const y: u32 = @intCast(y_pos);

    for (this.windows) |*window| {
        if (x >= window.bounds.x and
            y >= window.bounds.y and
            x <= window.bounds.x + window.bounds.width and
            y <= window.bounds.y + window.bounds.height)
            return window;
    }

    return null;
}

pub fn should_close(this: Windows) bool {
    for (this.windows) |window| {
        if (window.backend.shouldClose()) return true;
    }

    return false;
}

pub fn is_key(this: Windows, key: glfw.Key, action: glfw.Action) bool {
    for (this.windows) |window| {
        if (window.backend.getKey(key) == action) return true;
    }

    return false;
}
