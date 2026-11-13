// olib_sample/src/batcher 的 Jai 版本：直接驱动 foster 的 Batcher。
// 基于 kit 的游戏用 kit/rendering/2d 的 Render2D 绘制，本示例只展示底层接口。
#import "Basic";
M :: #import "Math";
using M;
F :: #import "foster";

batcher: *F.Batcher;

main :: () {
    F.App.startup = startup;
    F.App.shutdown = shutdown;
    F.App.update = update;
    F.App.render = render;
    F.app_run(.{application_name = "BatcherExample", window_title = "JaiLib / batcher",
        width = 1280, height = 720, update_mode = F.update_mode_unlocked()});
    F.app_destroy();
}

startup :: () {
    batcher = F.batcher_create(F.App.device, "BatcherExample");
    print("Batcher ready\n");
}

shutdown :: () { F.batcher_destroy(batcher); }
update :: () {}

render :: () {
    target := F.drawable_target_window(F.App.window);
    F.graphics_device_clear_color(F.App.device, target, .{ 24, 28, 36, 255 });

    F.batcher_clear(batcher);
    F.batcher_rect(batcher, .{ 80, 60, 220, 140 }, .{ 220, 80, 70, 255 });
    F.batcher_circle(batcher, .{ 430, 130 }, 70, 32, .{ 70, 170, 235, 255 });
    F.batcher_line(batcher, .{ 80, 260 }, .{ 560, 300 }, 8, .{ 245, 205, 70, 255 });
    F.batcher_render(batcher, target);
}
