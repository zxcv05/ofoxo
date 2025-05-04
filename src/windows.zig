const std = @import("std");
const glfw = @import("glfw");

const Context = @import("context.zig");
const Windows = @This();

const log = std.log.scoped(.window);

const Workarea = struct {
    x: isize,
    y: isize,
    w: isize,
    h: isize,
};

const WorkareaC = struct {
    x: c_int,
    y: c_int,
    w: c_int,
    h: c_int,

    pub fn convert(this: WorkareaC) Workarea {
        return Workarea{
            .x = @intCast(this.x),
            .y = @intCast(this.y),
            .w = @intCast(this.w),
            .h = @intCast(this.h),
        };
    }
};

const Window = struct {
    workarea: Workarea,
    backend: *glfw.Window,

    pub fn init(workarea: WorkareaC, root_window: ?Window) !Window {
        glfw.windowHint(glfw.Doublebuffer, 1);
        glfw.windowHint(glfw.TransparentFramebuffer, 1);
        glfw.windowHint(glfw.Floating, 1);
        glfw.windowHint(glfw.Visible, 1);
        glfw.windowHint(0x0002000D, 1); // Mouse passthrough, missing for some reason

        glfw.windowHint(glfw.Decorated, 0);
        glfw.windowHint(glfw.Resizable, 0);

        glfw.windowHint(glfw.ContextVersionMajor, 3);
        glfw.windowHint(glfw.ContextVersionMinor, 2);
        glfw.windowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile);

        const backend = try glfw.createWindow(
            workarea.w,
            workarea.h,
            "ofoxo",
            null,
            if (root_window) |window| window.backend else null,
        );

        glfw.setWindowPos(backend, workarea.x, workarea.y);

        return Window{
            .backend = backend,
            .workarea = workarea.convert(),
        };
    }

    pub inline fn deinit(this: Window) void {
        glfw.destroyWindow(this.backend);
    }
};

windows: []Window,

pub fn init(allocator: std.mem.Allocator, context: Context) !Windows {
    if (context.primary_display_only) {
        const window_container = try allocator.alloc(Window, 1);

        const monitor = glfw.getPrimaryMonitor();

        var workarea: WorkareaC = undefined;
        glfw.getMonitorWorkarea(monitor, &workarea.x, &workarea.y, &workarea.w, &workarea.h);

        window_container[0] = try Window.init(workarea, null);
        log.debug("Window ({any}) created on primary display", .{window_container[0].workarea});

        glfw.makeContextCurrent(window_container[0].backend);

        return Windows{ .windows = window_container };
    }

    var num_monitors: c_int = 0;
    const monitors = glfw.getMonitors(&num_monitors) orelse return error.FailedToGetMonitors;

    if (num_monitors < 1) return error.NoMonitors;

    var windows = try allocator.alloc(Window, @intCast(num_monitors));
    for (monitors[0..@intCast(num_monitors)], 0..) |monitor, i| {
        var workarea: WorkareaC = undefined;
        glfw.getMonitorWorkarea(monitor, &workarea.x, &workarea.y, &workarea.w, &workarea.h);

        windows[i] = try Window.init(workarea, if (i > 0) windows[0] else null);
        log.debug("Window ({any}) created", .{windows[i].workarea});
    }

    glfw.makeContextCurrent(windows[0].backend);

    return Windows{
        .windows = windows,
    };
}

pub fn deinit(this: Windows, allocator: std.mem.Allocator) void {
    defer allocator.free(this.windows);
    for (this.windows) |window| window.deinit();
}

pub fn find_window_containing(this: Windows, x: isize, y: isize) ?*const Window {
    if (x < 0 or y < 0) return null;

    for (this.windows) |*window| {
        if (x >= window.workarea.x and
            y >= window.workarea.y and
            x <= window.workarea.x + window.workarea.w and
            y <= window.workarea.y + window.workarea.h)
            return window;
    } else return null;
}

pub fn should_close(this: Windows) bool {
    for (this.windows) |window| {
        if (glfw.windowShouldClose(window.backend)) return true;
    } else return false;
}

pub fn is_key(this: Windows, key: glfw.Key, key_state: glfw.KeyState) bool {
    for (this.windows) |window| {
        if (glfw.getKey(window.backend, key) == key_state) return true;
    } else return false;
}
