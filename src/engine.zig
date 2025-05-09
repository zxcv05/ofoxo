const std = @import("std");
const zgl = @import("zgl");
const glfw = @import("glfw");
const zimg = @import("zimg");

const Spritesheet = @import("spritesheet.zig");
const Context = @import("context.zig");
const Windows = @import("windows.zig");
const State = @import("state.zig");
const Engine = @This();

const log = std.log.scoped(.engine);

allocator: std.mem.Allocator,

spritesheet: *Spritesheet,
context: Context,
windows: Windows,

state: State = .{},

pub fn init(allocator: std.mem.Allocator, context: Context) !Engine {
    const windows = try Windows.init(allocator, context);
    const spritesheet = try allocator.create(Spritesheet);

    return Engine{
        .allocator = allocator,

        .spritesheet = spritesheet,
        .context = context,
        .windows = windows,
    };
}

pub fn setup_gl() void {
    zgl.enable(.blend);
    zgl.disable(.stencil_test);

    zgl.blendFunc(.src_alpha, .one_minus_src_alpha);
}

pub fn load_spritesheet(this: Engine) !void {
    this.spritesheet.* = try Spritesheet.from_embedded(this.allocator, @embedFile("assets/spitesheet.png"));

    log.debug("Spritesheet loaded", .{});
}

pub fn deinit(this: Engine) void {
    this.windows.deinit(this.allocator);

    defer this.allocator.destroy(this.spritesheet);
    this.spritesheet.deinit(this.allocator);
}

pub fn run(this: *Engine) !void {
    const sprite_fbo = zgl.genFramebuffer();

    const root_window = this.windows.windows[0];

    this.state.position.x = root_window.workarea.x + @as(isize, @intCast(@divFloor(root_window.workarea.w, 2)));
    this.state.position.y = root_window.workarea.y + @as(isize, @intCast(@divFloor(root_window.workarea.h, 2)));

    this.state.start_idle_ts = std.time.milliTimestamp();
    this.state.start_awake_ts = std.time.milliTimestamp();

    while (!this.windows.should_close()) {
        const loop_start_ts = std.time.nanoTimestamp();

        if (this.windows.is_key(glfw.KeyEscape, glfw.Press)) break;
        defer glfw.pollEvents();

        // shorthand: cursor_[xy]
        var cx: f64 = undefined;
        var cy: f64 = undefined;
        glfw.getCursorPos(root_window.backend, &cx, &cy);

        const cursor_position = State.Position{
            .x = @as(isize, @intFromFloat(cx)) + root_window.workarea.x,
            .y = @as(isize, @intFromFloat(cy)) + root_window.workarea.y,
        };

        this.state.update(cursor_position);
        sprite_fbo.texture2D(.read_buffer, .color0, .@"2d", this.spritesheet.texture, 0);

        const sprite = this.state.get_sprite();

        // Rendering

        const draw_window = this.windows.find_window_containing(this.state.position.x, this.state.position.y);

        for (this.windows.windows) |*window| {
            glfw.makeContextCurrent(window.backend);

            zgl.clearColor(0.0, 0.0, 0.0, 0.0);
            zgl.clear(.{ .color = true });

            defer glfw.swapBuffers(window.backend);

            if (draw_window == null) continue;

            if (window == draw_window.?) {
                const draw_offset_x: isize = Spritesheet.Sprite.height / 2;
                const draw_offset_y: isize = Spritesheet.Sprite.width / 2;

                const draw_position_x = this.state.position.x - window.workarea.x - draw_offset_x;
                const draw_position_y = this.state.position.y - window.workarea.y + draw_offset_y;

                if (draw_position_x < 0 or draw_position_y < 0) continue;

                zgl.blitFramebuffer(
                    sprite.x,
                    sprite.y + Spritesheet.Sprite.height,
                    sprite.x + Spritesheet.Sprite.width,
                    sprite.y,

                    @as(usize, @intCast(draw_position_x)),
                    @as(usize, @intCast(window.workarea.h)) - @as(usize, @intCast(draw_position_y)),
                    @as(usize, @intCast(draw_position_x)) + Spritesheet.Sprite.width,
                    @as(usize, @intCast(window.workarea.h)) - @as(usize, @intCast(draw_position_y)) + Spritesheet.Sprite.height,

                    .{ .color = true, .stencil = true, .depth = true },
                    .nearest,
                );
            }
        }

        const loop_end_ts = std.time.nanoTimestamp();
        const loop_delta: u64 = @intCast(loop_end_ts - loop_start_ts);

        const target = std.time.ns_per_s / 30;
        if (loop_delta >= target) continue;

        std.time.sleep(target - loop_delta);
    }
}
