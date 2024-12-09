const std = @import("std");
const zgl = @import("zgl");
const glfw = @import("glfw");
const zimg = @import("zimg");

const Spritesheet = @import("spritesheet.zig");
const Windows = @import("windows.zig");
const State = @import("state.zig");
const Engine = @This();

const log = std.log.scoped(.engine);

allocator: std.mem.Allocator,

windows: Windows,
spritesheets: []Spritesheet,

state: State = .{},

pub fn init(allocator: std.mem.Allocator) !Engine {
    const windows = try Windows.init(allocator);
    const spritesheets = try allocator.alloc(Spritesheet, Spritesheet.NUM_SPRITESHEETS);

    return Engine{
        .allocator = allocator,

        .windows = windows,
        .spritesheets = spritesheets,
    };
}

pub fn setup_gl() void {
    zgl.enable(.blend);
    zgl.disable(.stencil_test);

    zgl.blendFunc(.src_alpha, .one_minus_src_alpha);
}

pub fn load_spritesheets(this: Engine) !void {
    this.spritesheets[0] = try Spritesheet.from_embedded(this.allocator, @embedFile("assets/spitesheet-1.png"));

    log.debug("Spritesheets loaded", .{});
}

pub fn deinit(this: Engine) void {
    this.windows.deinit(this.allocator);

    defer this.allocator.free(this.spritesheets);
    for (this.spritesheets) |*spritesheet| {
        spritesheet.deinit(this.allocator);
    }
}

pub fn run(this: *Engine) !void {
    const sprite_fbo = zgl.genFramebuffer();

    const root_window = this.windows.windows[0];

    this.state.position.x = root_window.bounds.x + root_window.bounds.width / 2;
    this.state.position.y = root_window.bounds.y + root_window.bounds.height / 2;

    this.state.start_idle_ts = std.time.milliTimestamp();
    this.state.start_awake_ts = std.time.milliTimestamp();

    while (!this.windows.should_close()) {
        if (this.windows.is_key(glfw.Key.escape, glfw.Action.press)) break;
        defer glfw.pollEvents();

        const cursor = root_window.backend.getCursorPos();
        const cursor_position = State.Position{
            .x = @as(isize, @intFromFloat(cursor.xpos)) + root_window.bounds.x,
            .y = @as(isize, @intFromFloat(cursor.ypos)) + root_window.bounds.y,
        };

        this.state.update(cursor_position);

        const sprite = this.state.get_sprite();
        sprite_fbo.texture2D(.read_buffer, .color0, .@"2d", this.spritesheets[sprite.n].texture, 0);

        // Rendering

        const draw_window = this.windows.find_window_containing(this.state.position.x, this.state.position.y);

        for (this.windows.windows) |*window| {
            glfw.makeContextCurrent(window.backend);

            zgl.clearColor(0.0, 0.0, 0.0, 0.0);
            zgl.clear(.{ .color = true });

            defer window.backend.swapBuffers();

            if (draw_window == null) continue;

            if (window == draw_window.?) {
                const draw_offset_x: isize = Spritesheet.Sprite.height / 2;
                const draw_offset_y: isize = Spritesheet.Sprite.width / 2;

                const draw_position_x = this.state.position.x - window.bounds.x - draw_offset_x;
                const draw_position_y = this.state.position.y - window.bounds.y + draw_offset_y;

                if (draw_position_x < 0 or draw_position_y < 0) continue;

                zgl.blitFramebuffer(
                    sprite.x,
                    sprite.y + Spritesheet.Sprite.height,
                    sprite.x + Spritesheet.Sprite.width,
                    sprite.y,

                    @as(usize, @intCast(draw_position_x)),
                    window.bounds.height - @as(usize, @intCast(draw_position_y)),
                    @as(usize, @intCast(draw_position_x)) + Spritesheet.Sprite.width,
                    window.bounds.height - @as(usize, @intCast(draw_position_y)) + Spritesheet.Sprite.height,

                    .{ .color = true, .stencil = true, .depth = true },
                    .nearest,
                );
            }
        }
    }
}
