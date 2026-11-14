// olib_sample/src/material2d 的 Jai 版本。
// 12 个精灵共用一个两 Pass 材质（阴影 + 本体）；Render2D 提交时对同一材质的连续一段
// 先画完全部阴影、再画全部本体。空格切换为用 pass_id 手动分两轮记录，结果相同。
// 右侧一组用 Instance_Values 把 hue 设为 0.7，值走实例字段，仍合成同一次 Draw。
#import "Basic";
M :: #import "Math";
using M;
FILE :: #import "File";
F :: #import "foster";
R :: #import "kit/rendering/2d";
MAT :: #import "kit/rendering/material";
PROF :: #import "core/profiler";
PERF :: #import "kit/tools/perf_overlay";

#load "swarm.jai";
#load "../ui_gallery/font.jai";

SPRITE_COUNT :: 12;

State :: struct {
    storage: F.Storage_Container;
    materials: MAT.Material_Library;
    renderer: R.Render2D;
    material: *MAT.Material;    // 12 个精灵共用一个材质、一张图
    cool: MAT.Instance_Values;  // 右侧一组的实例字段：只改 hue，不创建新的 Material
    shot: bool;                 // 参数 shot：离屏渲染固定帧数，写 PNG 后退出
    capture: *F.Target;
    frame: int;
    immediate, vulkan: bool;
    texture: *F.Texture;
    swarm: Swarm;
    swarm_on: bool;
    swarm_count: int;
    zoom: float32;
    offset, mouse_last: F.Vector2;
    perf: PERF.Overlay;
    font: *F.Msdf_Font;
    font_view: F.Msdf_Font;       // Adapted metrics/UVs owned by this sample; atlas is borrowed.
    font_texture: *F.Texture;
    time: float32;
    failed: bool;
    grouped: bool;
    reported: bool;
    last_grouped: bool;
    last_draw_calls: int;
}
state: State;

string_has_prefix :: (text: string, prefix: string) -> bool {
    if text.count < prefix.count return false;
    for c, i: prefix if text.data[i] != c return false;
    return true;
}

parse_positive_int :: (text: string) -> (value: int, ok: bool) {
    if text.count == 0 return 0, false;
    v := 0;
    for c: text {
        if c < #char "0" || c > #char "9" return 0, false;
        v = v * 10 + (cast(int) c - cast(int) #char "0");
    }
    return v, true;
}

has_arg :: (value: string) -> bool {
    for arg: get_command_line_arguments() if arg == value return true;
    return false;
}

main :: () {
    state.grouped = true;
    state.zoom = 1;
    state.immediate = has_arg("immediate");
    state.vulkan = has_arg("vulkan");
    if has_arg("auto") state.grouped = false;   // 由 Render2D 按 Pass 自动分组
    state.shot = has_arg("shot");
    state.swarm_on = has_arg("swarm");
    state.swarm_count = SWARM_DEFAULT_COUNT;
    // count=N 调整精灵数（默认 1,000,000）。
    for arg: get_command_line_arguments() {
        if !string_has_prefix(arg, "count=") continue;
        digits := string.{ arg.count - 6, arg.data + 6 };
        parsed, ok := parse_positive_int(digits);
        if ok && parsed > 0 state.swarm_count = parsed;
    }
    F.App.startup = startup;
    F.App.update = update;
    F.App.render = render;
    F.App.shutdown = shutdown;
    F.app_run(.{application_name = "Material2D", width = 1000, height = 640,
        preferred_graphics_driver = ifx state.vulkan then .VULKAN else .NONE,
        window_title = "JaiLib / Material2D | Drag: pan | Wheel: zoom | F: reset | P: perf | Space: grouped | I: swarm | R: reload | Esc: exit",
        update_mode = F.update_mode_unlocked()});
    F.app_destroy();
    if state.failed exit(1);
}

startup :: () {
    if state.shot state.capture = F.target_create(F.App.device, 1000, 640, "material2d capture");
    state.storage.Root = ".";   // jacket run 的工作目录是仓库根
    state.materials.device = F.App.device;
    state.materials.storage = *state.storage;

    // 登记 Shader Lab 产物目录里的材质 Shader（本例用 SpriteShadow）；只供预览的 Shader 自动跳过。
    files := MAT.material_load_directory("src/shader_lab/shaders/Compiled");
    reason := MAT.material_register_directory(*state.materials, files);
    MAT.material_load_directory_free(files);
    if reason != "" { fail(reason); return; }

    _ = F.defaults_batch_material(F.App.device);
    _ = F.defaults_msdf_material(F.App.device);
    reason = R.init(*state.renderer, *state.materials);
    if reason != "" { fail(reason); return; }

    {
        PROF.profile_init();
        state.font = F.defaults_msdf_font(F.App.device);
        prepare_ui_font(state.font, *state.font_view);
        state.font_texture = F.texture_create_from_colors(F.App.device,
            state.font.Atlas.Width, state.font.Atlas.Height, state.font.Atlas.Data);
        state.perf.corner = .Top_Right;
        state.perf.visible = PERF.init(*state.perf, F.App.device, *state.font_view, state.font_texture);
        assert(state.perf.visible, "Performance overlay failed to initialize");
    }

    image := F.image_create(256, 256);
    defer F.image_destroy(*image);
    for i: 0..256 * 256 - 1 {
        x := cast(s32) (i % 256);
        y := cast(s32) (i / 256);
        dx := cast(float32) x - 127.5;
        dy := cast(float32) y - 127.5;
        alpha := clamp(cast(float32) 104 - sqrt(dx * dx + dy * dy), 0, 1);
        value: u8 = 150;
        if (x / 32 + y / 32) % 2 == 0 value = 255;
        F.image_set_pixel(*image, x, y, .{ value, value, value, cast(u8) (alpha * 255) });
    }
    F.image_premultiply(*image);
    state.texture = F.texture_create_from_colors(F.App.device, image.Width, image.Height, image.Data,
        name = "sprite frame");

    material, load_reason := MAT.material_load(*state.materials, "src/material2d/material.json");
    if load_reason != "" { fail(load_reason); return; }
    hue := MAT.instance_slot(material, "hue");   // 名字只解析一次，之后按槽位设值
    _ = MAT.instance_values_set(*state.cool, hue, 0.7);
    state.material = material;
}

fail :: (reason: string) {
    print("%\n", reason);
    state.failed = true;
    F.app_exit();
}

// 右侧一组（后 6 个）用 cool 实例值，其余沿用材质里的 hue。
sprite_values :: (i: int) -> *MAT.Instance_Values {
    return ifx i >= SPRITE_COUNT / 2 then *state.cool else null;
}

update :: () {
    state.time += cast(float32) (F.App.time.elapsed - F.App.time.previous);
    keys := F.input_keyboard(F.App.input);
    if F.keyboard_pressed(keys, .ESCAPE) F.app_exit();
    if F.keyboard_pressed(keys, .SPACE) state.grouped = !state.grouped;
    if F.keyboard_pressed(keys, .I) state.swarm_on = !state.swarm_on;
    if F.keyboard_pressed(keys, .F) || F.keyboard_pressed(keys, .I) {
        state.zoom = 1;
        state.offset = .{ 0, 0 };
    }
    if F.keyboard_pressed(keys, .P) state.perf.visible = !state.perf.visible;
    PERF.frame(*state.perf, cast(float32) (F.App.time.elapsed - F.App.time.previous));
    camera_input();
    if F.keyboard_pressed(keys, .R) {
        reason := MAT.material_reload(*state.materials, state.material);
        if reason != "" print("%\n", reason);
    }
}

// 屏幕像素 = 场景像素 * zoom + offset；缩放时保持光标下的场景点不动。
camera_input :: () {
    mouse := F.input_mouse(F.App.input);
    size := F.window_size(F.App.window);
    target := F.drawable_target_window(F.App.window);
    pixels := F.Vector2.{ cast(float32) F.drawable_target_width_in_pixels(target),
        cast(float32) F.drawable_target_height_in_pixels(target) };
    position := F.Vector2.{ mouse.Position.x * pixels.x / cast(float32) max(1, size.x),
        mouse.Position.y * pixels.y / cast(float32) max(1, size.y) };
    delta := position - state.mouse_last;
    state.mouse_last = position;
    if F.mouse_down(mouse, .LEFT) || F.mouse_down(mouse, .RIGHT) || F.mouse_down(mouse, .MIDDLE)
        state.offset += delta;
    if mouse.WheelValue.y != 0 {
        zoom := clamp(state.zoom * pow(cast(float32) 1.15, mouse.WheelValue.y),
            cast(float32) 0.1, cast(float32) 200);
        state.offset = position - (position - state.offset) * (zoom / state.zoom);
        state.zoom = zoom;
    }
}

render :: () {
    if state.failed return;
    target := ifx state.shot then F.drawable_target_target(state.capture)
        else F.drawable_target_window(F.App.window);
    F.graphics_device_clear_color(F.App.device, target, .{ 31, 38, 51, 255 });
    view := R.View.{ target = target, time = state.time };
    R.push_matrix(*state.renderer,
        F.Matrix3x2.{ state.zoom, 0, 0, state.zoom, state.offset.x, state.offset.y });

    if state.swarm_on {
        if !state.swarm.ready {
            reason := swarm_init(state.swarm_count,
                cast(float32) F.drawable_target_width_in_pixels(target),
                cast(float32) F.drawable_target_height_in_pixels(target));
            if reason != "" { fail(reason); return; }
            print("Swarm: % sprites, 1 draw
", state.swarm.count);
        }
        error := R.buffer(*state.renderer, state.material, *state.swarm.buffer, state.swarm.count,
            state.texture);
        if error != .None fail(MAT.draw_error_text(error));
        error = R.submit(*state.renderer, view);
        if error != .None fail(MAT.draw_error_text(error));
        draw_panel(target);
        finish_shot();
        return;
    }

    transforms: [SPRITE_COUNT] F.Matrix3x2;
    width := cast(float32) F.drawable_target_width_in_pixels(target);
    height := cast(float32) F.drawable_target_height_in_pixels(target);
    for *transform, i: transforms {
        x := width / 2 + (cast(float32) (i / 3) - 1.5) * 125;
        y := height / 2 + (cast(float32) (i % 3) - 1) * 125 + sin(state.time + cast(float32) i) * 12;
        transform.* = F.Matrix3x2.{ 0.75, 0, 0, 0.75, x, y };
    }
    frame := F.subtexture_make_full(state.texture);
    // 精灵按 0.75 缩放：帧贴图用线性采样（Render2D 与 foster Batcher 一样默认最近邻）。
    R.push_sampler(*state.renderer, F.texture_sampler_make(.LINEAR, .CLAMP));
    if state.grouped {
        // 手动分两轮：先用 pass_id 记录全部阴影，再记录全部本体。
        for i: 0..SPRITE_COUNT - 1 {
            error := R.image(*state.renderer, frame, transforms[i], origin = .{ 128, 128 },
                material = state.material, values = sprite_values(i), pass_id = "shadow");
            if error != .None fail(MAT.draw_error_text(error));
        }
    }
    for i: 0..SPRITE_COUNT - 1 {
        pass_id: MAT.Pass_Id = ifx state.grouped then "body" else "";
        error := R.image(*state.renderer, frame, transforms[i], origin = .{ 128, 128 },
            material = state.material, values = sprite_values(i), pass_id = pass_id);
        if error != .None fail(MAT.draw_error_text(error));
    }
    error := R.submit(*state.renderer, view);
    if error != .None fail(MAT.draw_error_text(error));
    if !state.reported || state.last_grouped != state.grouped
        || state.last_draw_calls != state.renderer.draw_calls {
        print("%: % sprites x 2 passes -> % draws\n",
            ifx state.grouped then "Recorded with pass_id" else "All passes, grouped by Render2D",
            SPRITE_COUNT, state.renderer.draw_calls);
        state.reported = true;
        state.last_grouped = state.grouped;
        state.last_draw_calls = state.renderer.draw_calls;
    }
    draw_panel(target);
    finish_shot();
}

// 场景提交之后叠加性能面板：它自带 Render2D 单独提交，不计入场景 Draw。
draw_panel :: (target: F.Drawable_Target) {
    PERF.draw(*state.perf, target,
        ifx has_arg("scaled") then cast(float32)1.25 else
            cast(float32) F.drawable_target_width_in_pixels(target)
            / cast(float32) max(1, F.window_size(F.App.window).x));
}

// shot 模式：固定帧数后读回离屏目标写 PNG 并退出。
finish_shot :: () {
    if !state.shot return;
    state.frame += 1;
    state.time = 0.5;   // 固定时间，画面可重复
    if state.frame == (ifx state.swarm_on then 130 else 12) {
        save_capture();
        F.app_exit();
    }
}

// 读回离屏目标并写到 library/screenshots/material2d.png（相对示例仓库根）。
save_capture :: () {
    texture := F.target_texture(state.capture);
    image := F.image_create(texture.Width, texture.Height);
    defer F.image_destroy(*image);
    F.texture_get_data(texture, image.Data);
    png := F.image_encode_png(*image);
    defer free(png.data);
    assert(FILE.make_directory_if_it_does_not_exist("library/screenshots", true));
    name := ifx state.swarm_on
        then "library/screenshots/material2d-swarm.png"
        else "library/screenshots/material2d.png";
    assert(FILE.write_entire_file(name,cast(string)png));
    changed:=0; for p:image.Data if p.r>60 || p.g>60 || p.b>60 changed+=1;
    assert(changed>100,"Blank material2d render");
    print("[material2d] GPU PASS\n");
}

shutdown :: () {
    swarm_dispose();
    PERF.dispose(*state.perf);
    array_free(state.font_view.Glyphs);
    if state.font_texture != null F.texture_dispose(state.font_texture);
    if state.shot && state.capture != null F.target_dispose(state.capture);
    R.dispose(*state.renderer);
    MAT.material_library_dispose(*state.materials);
    if state.texture != null F.texture_dispose(state.texture);
}
