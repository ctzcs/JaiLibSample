// olib_sample/src/gizmo2d 的 Jai 版本：三视口的 2D 变换手柄（移动 / 旋转 / 缩放），
// 带撤销/重做、相机平移旋转缩放，以及 `shot` 下的脚本化输入自检。
#import "Basic";
M :: #import "Math";

using M;

FILE :: #import "File";
FU :: #import "File_Utilities";
F :: #import "foster";
GZ :: #import "kit/gizmo";
W :: #import "kit/world";
R :: #import "kit/rendering/2d";
MAT :: #import "kit/rendering/material";

#load "editor.jai";
#load "../../shared/library_assets.jai";

has_arg :: (value: string) -> bool {
    for arg: get_command_line_arguments() if arg == value return true;
    return false;
}

Demo :: struct {
    materials: MAT.Material_Library;
    batch: R.Render2D;
    font_source: *F.Font;
    font: *F.Sprite_Font;
    target: *F.Target;
    editor: Session;
    viewports: [3] F.Rect;
    frame: int;
    shot, failed, ready: bool;
    pointer, scripted_end: F.Vector2;
    scripted_pointer:F.Vector2;
    scripted_down,scripted_pressed:bool;
    ui_scale: float32;
}

demo: Demo;

main :: () {
    F.App.startup = startup;
    F.App.shutdown = shutdown;
    F.App.update = update;
    F.App.render = render;
    width: s32 = 1280;
    height: s32 = 720;
    if has_arg("scaled") {
        width = 1600;
        height = 900;
    }
    if has_arg("narrow") {
        width = 960;
        height = 600;
    }
    F.app_run(.{ application_name = "Gizmo2D", width = width, height = height,
        window_title = "JaiLib / 2D Gizmos | Drag handles | Arrows pan | Q/E rotate camera | R reset",
        update_mode = F.update_mode_unlocked() });
    F.app_destroy();
    if demo.failed exit(1);
}

startup :: () {
    demo.shot = has_arg("shot");
    demo.materials.device = F.App.device;
    _ = F.defaults_batch_material(F.App.device);
    _ = F.defaults_msdf_material(F.App.device);
    reason := R.init(*demo.batch, *demo.materials);
    if reason != "" {
        print("Gizmo2D: %\n", reason);
        demo.failed = true;
        F.app_exit();
        return;
    }
    demo.font_source = sample_load_bitmap_font();
    if demo.font_source != null {
        codepoints: [95] s32;
        for i: 0..94 codepoints[i] = 32 + cast(s32) i;
        demo.font = F.sprite_font_create_from_font(F.App.device, demo.font_source, 16, array_view(codepoints, 0, 95));
    }
    if demo.font == null {
        print("Gizmo2D: no usable demo font\n");
        demo.failed = true;
        F.app_exit();
        return;
    }
    editor_init(*demo.editor);
    demo.ready = true;
}

shutdown :: () {
    if !demo.ready return;
    editor_destroy(*demo.editor);
    if demo.target != null F.target_dispose(demo.target);
    if demo.font != null F.sprite_font_destroy(demo.font);
    if demo.font_source != null F.font_destroy(demo.font_source);
    R.dispose(*demo.batch);
    MAT.material_library_dispose(*demo.materials);
}

// ==============================================================================
// 输入与自动验收
// ==============================================================================

update :: () {
    demo.frame += 1;
    if !demo.ready || demo.shot return;
    keys := F.input_keyboard(F.App.input);
    if F.keyboard_pressed(keys, .ESCAPE) {
        if demo.editor.active cancel(*demo.editor);
        else F.app_exit();
    }
    if F.keyboard_ctrl(keys) {
        if F.keyboard_pressed(keys, .Z) undo(*demo.editor);
        if F.keyboard_pressed(keys, .Y) redo(*demo.editor);
    }
    if F.keyboard_pressed(keys, .R) reset(*demo.editor);
    dt := cast(float32) (F.App.time.elapsed - F.App.time.previous);
    for *c: demo.editor.cameras {
        p := c.position;
        if F.keyboard_down(keys, .LEFT) p.x -= dt * 2;
        if F.keyboard_down(keys, .RIGHT) p.x += dt * 2;
        if F.keyboard_down(keys, .UP) p.y -= dt * 2;
        if F.keyboard_down(keys, .DOWN) p.y += dt * 2;
        W.camera2d_set_position(c, p);
        if F.keyboard_down(keys, .Q) W.camera2d_set_rotation(c, c.rotation - dt);
        if F.keyboard_down(keys, .E) W.camera2d_set_rotation(c, c.rotation + dt);
        if !F.keyboard_ctrl(keys) && F.keyboard_down(keys, .Z) W.camera2d_set_zoom(c, max(cast(float32) 0.1, c.zoom - dt));
        if F.keyboard_down(keys, .X) W.camera2d_set_zoom(c, min(cast(float32) 5, c.zoom + dt));
    }
}

// Deterministic editor input, isolated from OS pointer/focus events during the probe.
smoke :: () {
    f := demo.frame;
    if f == 10 || f == 40 || f == 70 || f == 100 {
        i := ifx f == 10 then 0 else (ifx f == 40 then 1 else 2);
        g := GZ.transform2d_geometry(*demo.editor.cameras[i], demo.editor.values[i],
            demo.viewports[i], cast(GZ.Mode) i, demo.ui_scale);
        start := g.axes.origin;
        if i == 0 {
            demo.scripted_end, _ = GZ.project2d(*demo.editor.cameras[i], .{ 0.75, -0.5 }, demo.viewports[i]);
        } else if i == 1 {
            start.x += g.radius;
            demo.scripted_end = F.Vector2.{ g.axes.origin.x + cos(cast(float32) 0.5) * g.radius,
                g.axes.origin.y + sin(cast(float32) 0.5) * g.radius };
        } else if f == 70 {
            start = g.axes.ends[0];
            demo.scripted_end = F.Vector2.{ start.x + (start.x - g.axes.origin.x) * 0.5,
                start.y + (start.y - g.axes.origin.y) * 0.5 };
        } else {
            demo.scripted_end = F.Vector2.{ start.x + 0.70710678 * 25 * demo.ui_scale,
                start.y - 0.70710678 * 25 * demo.ui_scale };
        }
        pointer(start, true);
    } else if f == 20 || f == 50 || f == 80 || f == 105 {
        pointer(demo.scripted_end, true);
    } else if f == 30 || f == 60 || f == 90 || f == 110 {
        demo.scripted_down=false;
        F.input_mouse_button(F.App.input, cast(s32) F.Mouse_Buttons.LEFT, false, F.App.time.elapsed);
    } else if f == 114 {
        d := F.Vector2.{ demo.editor.values[0].position.x - 0.75, demo.editor.values[0].position.y + 0.5 };
        check(d.x * d.x + d.y * d.y < 0.00001, "free movement");
        check(abs(demo.editor.values[1].rotation - 0.75) < 0.001, "rotation");
        check(abs(demo.editor.values[2].scale.x - 2.25) < 0.001
            && abs(demo.editor.values[2].scale.y - 1) < 0.001, "axis and uniform scaling");
    } else if f == 117 {
        check(demo.editor.history.count == 4 && !demo.editor.active, "one record per gesture");
        undo(*demo.editor);
        check(abs(demo.editor.values[2].scale.x - 1.8) < 0.001, "undo uniform scaling");
        redo(*demo.editor);
        check(abs(demo.editor.values[2].scale.x - 2.25) < 0.001, "redo uniform scaling");
    } else if f == 120 {
        F.window_set_size(F.App.window, .{ 1100, 650 });
    } else if f == 142 {
        check(abs(demo.editor.values[1].rotation - 0.75) < 0.001 && demo.editor.cursor == 4,
            "history and rotation survive undo/redo and resize");
        if demo.failed print("GIZMO2D SMOKE FAIL\n");
        else print("GIZMO2D SMOKE PASS: move, rotate, scale, offset viewports and resize\n");
        F.app_exit();
    }
}

check :: (condition: bool, reason: string) {
    if condition return;
    demo.failed = true;
    print("Gizmo2D: %\n", reason);
}

pointer :: (pixel: F.Vector2, down: bool) {
    demo.scripted_pointer=pixel;
    demo.scripted_pressed=down && !demo.scripted_down;
    demo.scripted_down=down;
    size := F.window_size(F.App.window);
    target := F.drawable_target_window(F.App.window);
    pixels := F.Vector2.{ cast(float32) F.drawable_target_width_in_pixels(target),
        cast(float32) F.drawable_target_height_in_pixels(target) };
    F.input_mouse_motion(F.App.input, F.Vector2.{ pixel.x * size.x / max(cast(float32) 1, pixels.x),
        pixel.y * size.y / max(cast(float32) 1, pixels.y) }, F.Vector2.{ 0, 0 }, F.App.time.elapsed);
    F.input_mouse_button(F.App.input, cast(s32) F.Mouse_Buttons.LEFT, down, F.App.time.elapsed);
}

// ==============================================================================
// 原生像素绘制
// ==============================================================================

render :: () {
    if !demo.ready return;
    target := F.drawable_target_window(F.App.window);
    w := cast(float32) F.drawable_target_width_in_pixels(target);
    h := cast(float32) F.drawable_target_height_in_pixels(target);
    if w <= 0 || h <= 0 return;
    if demo.target == null || demo.target.Width != cast(s32) w || demo.target.Height != cast(s32) h {
        if demo.target != null F.target_dispose(demo.target);
        demo.target = F.target_create(F.App.device, cast(s32) w, cast(s32) h, "Gizmo2D");
    }
    demo.ui_scale = min(w / 1280, h / 720);

    width := cast(float32) cast(int) ((w - 64) / 3);
    for i: 0..2 {
        demo.viewports[i] = .{ 16 + cast(float32) i * (width + 16), 104, width, cast(float32) cast(int) (h - 184) };
        W.camera2d_set_viewport(*demo.editor.cameras[i], cast(s32) width, cast(s32) (h - 184));
    }
    // 脚本化输入在渲染帧内注入，保证同一帧就能被 editor_input 读到。
    demo.scripted_pressed=false;
    if demo.shot smoke();
    size := F.window_size(F.App.window);
    mouse := F.input_mouse(F.App.input);
    demo.pointer = .{ mouse.Position.x * w / cast(float32) max(1, size.x),
        mouse.Position.y * h / cast(float32) max(1, size.y) };
    if demo.shot demo.pointer=demo.scripted_pointer;
    editor_input(*demo.editor, demo.viewports,
        .{ pointer = demo.pointer, pressed = ifx demo.shot then demo.scripted_pressed else F.mouse_pressed(mouse, .LEFT), down = ifx demo.shot then demo.scripted_down else F.mouse_down(mouse, .LEFT),
           enabled = F.window_focused(F.App.window) || demo.shot, allow_start = true }, demo.ui_scale);

    R.reset(*demo.batch);
    F.graphics_device_clear_color(F.App.device, target, .{ 18, 26, 36, 255 });
    _ = R.rect(*demo.batch, .{ 0, 0, w, h }, .{ 18, 26, 36, 255 });
    text("2D GIZMOS / Camera2D", .{ 24, 22 });
    text("Drag handles | Arrows: pan | Q/E: camera rotation | Z/X: zoom | R: reset | Ctrl Z/Y: undo/redo | Esc: cancel",
        .{ 24, 48 });
    names: [3] string = .["MOVE / WORLD X,Y", "ROTATE / Z", "SCALE / LOCAL X,Y"];
    for i: 0..2 {
        rect := demo.viewports[i];
        text(names[i], .{ rect.x + 8, 80 });
        R.push_scissor(*demo.batch, .{ cast(s32) rect.x, cast(s32) rect.y, cast(s32) rect.w, cast(s32) rect.h });
        _ = R.rect(*demo.batch, rect, .{ 29, 42, 55, 255 });
        for line: -12..12 {
            a, _ := GZ.project2d(*demo.editor.cameras[i], .{ cast(float32) line, -12 }, rect);
            b, _ := GZ.project2d(*demo.editor.cameras[i], .{ cast(float32) line, 12 }, rect);
            _ = R.line(*demo.batch, a, b, 1, .{ 48, 63, 77, 255 });
            a2, _ := GZ.project2d(*demo.editor.cameras[i], .{ -12, cast(float32) line }, rect);
            b2, _ := GZ.project2d(*demo.editor.cameras[i], .{ 12, cast(float32) line }, rect);
            _ = R.line(*demo.batch, a2, b2, 1, .{ 48, 63, 77, 255 });
        }
        v := demo.editor.values[i];
        points: [4] F.Vector2;
        local: [4] F.Vector2 = .[.{ -1, -0.7 }, .{ 1, -0.7 }, .{ 1, 0.7 }, .{ -1, 0.7 }];
        for l, n: local {
            px := l.x * v.scale.x;
            py := l.y * v.scale.y;
            rotated := F.Vector2.{ px * cos(v.rotation) - py * sin(v.rotation),
                px * sin(v.rotation) + py * cos(v.rotation) };
            points[n], _ = GZ.project2d(*demo.editor.cameras[i],
                .{ v.position.x + rotated.x, v.position.y + rotated.y }, rect);
        }
        _ = R.triangle(*demo.batch, points[0], points[1], points[2], .{ 61, 117, 126, 255 });
        _ = R.triangle(*demo.batch, points[0], points[2], points[3], .{ 61, 117, 126, 255 });
        for point, n: points {
            _ = R.line(*demo.batch, point, points[(n + 1) % 4], 2, .{ 144, 207, 199, 255 });
        }
        geometry := GZ.transform2d_geometry(*demo.editor.cameras[i], v, rect, cast(GZ.Mode) i, demo.ui_scale);
        labels := GZ.transform2d_draw(*demo.batch, *demo.editor.handles[i], geometry, demo.pointer, demo.ui_scale);
        axis_names: [3] string = .["X", "Y", "Z"];
        for label, axis: labels if label.visible text(axis_names[axis], label.position);
        R.pop_scissor(*demo.batch);
        text(tprint("pos % | % | angle %", v.position.x, v.position.y, v.rotation * 180 / PI),
            .{ rect.x + 8, h - 64 });
        text(tprint("scale % | %", v.scale.x, v.scale.y), .{ rect.x + 8, h - 40 });
    }
    // 场景提交到离屏目标（截图从这里读回），再把结果作为一张图画到窗口。
    _ = R.submit(*demo.batch, R.View.{ target = F.drawable_target_target(demo.target) });
    _ = R.texture(*demo.batch, F.target_texture(demo.target), F.Matrix3x2_Identity);
    _ = R.submit(*demo.batch, R.View.{ target = target });

    if demo.shot && (demo.frame == 116 || demo.frame == 140) capture();
    demo.frame += 0;
}

text :: (value: string, position: F.Vector2) {
    _ = R.text(*demo.batch, demo.font, value, position);
}

capture :: () {
    texture := F.target_texture(demo.target);
    img := F.image_create(texture.Width, texture.Height);
    defer F.image_destroy(*img);
    F.texture_get_data(texture, img.Data);
    check(img.Data.count == texture.Width * texture.Height, "capture readback");
    png := F.image_encode_png(*img);
    defer free(png.data);
    assert(FILE.make_directory_if_it_does_not_exist("library/screenshots", true));
    name := tprint("library/screenshots/gizmo2d-%x%.png", texture.Width, texture.Height);
    check(FILE.write_entire_file(name, cast(string) png), "capture write");
    print("%\n", name);
}
