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

pub fn run(this: Engine) !void {
    const sprite_fbo = zgl.genFramebuffer();

    while (!this.windows.should_close()) {
        if (this.windows.is_key(glfw.Key.escape, glfw.Action.press)) break;
        defer glfw.pollEvents();

        const draw_window = this.windows.find_window_containing_cursor() orelse continue;

        const cursor = draw_window.backend.getCursorPos();
        const cursor_x: usize = @intFromFloat(@max(cursor.xpos, 0));
        const cursor_y: usize = @intFromFloat(@max(cursor.ypos, 0));

        const sprite = this.state.get_sprite();
        sprite_fbo.texture2D(.read_buffer, .color0, .@"2d", this.spritesheets[sprite.n].texture, 0);

        // Rendering

        for (this.windows.windows) |*window| {
            glfw.makeContextCurrent(window.backend);

            zgl.clearColor(0.0, 0.0, 0.0, 0.0);
            zgl.clear(.{ .color = true });

            defer window.backend.swapBuffers();

            if (window == draw_window) {
                zgl.blitFramebuffer(
                    sprite.x,
                    sprite.y + Spritesheet.Sprite.height,
                    sprite.x + Spritesheet.Sprite.width,
                    sprite.y,

                    cursor_x,
                    window.bounds.height - cursor_y,
                    cursor_x + Spritesheet.Sprite.width,
                    window.bounds.height - cursor_y + Spritesheet.Sprite.height,

                    .{ .color = true, .stencil = true, .depth = true },
                    .nearest,
                );
            }
        }
    }
}
