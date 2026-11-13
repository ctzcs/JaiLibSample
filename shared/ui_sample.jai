// Common window/font/input plumbing. Each sample owns its scene and interaction state.
#import "Basic";
M :: #import "Math";
using M;
FILE :: #import "File";
F :: #import "foster";
UI :: #import "kit/ui";
R :: #import "kit/rendering/2d";
MAT :: #import "kit/rendering/material";
C :: #import "thirdparty/clay/module";
#load "../src/ui_gallery/font.jai";

Host :: struct {
    ui: UI.UI_Context;
    theme: UI.UI_Theme;
    materials: MAT.Material_Library;
    renderer: R.Render2D;
    font: F.Msdf_Font;
    font_texture: *F.Texture;
    ready, started, smoke, shot, failed, done: bool;
    frame: int;
    dt: float32;
    scale: float32 = 1;
    pointer: F.Vector2;
    down, pressed, released: bool;
    name: string;
}
h: Host;

has_arg :: (value: string) -> bool {
    for arg: get_command_line_arguments() if arg == value return true;
    return false;
}
sample_run :: (name: string, width: s32, height: s32) {
    h.name = name; h.smoke = has_arg("smoke"); h.shot = has_arg("shot");
    if has_arg("scaled") h.scale = 1.25;
    F.App.startup = host_start; F.App.render = host_render; F.App.shutdown = host_stop;
    F.app_run(.{application_name = name, window_title = tprint("JaiLib / %", name),
        width = ifx has_arg("narrow") then cast(s32) 760 else width, height = height,
        update_mode = F.update_mode_unlocked()});
    F.app_destroy();
    if h.failed || !h.started || (h.smoke && !h.done) exit(1);
}
host_start :: () {
    h.started = true;
    assert(UI.ui_init(*h.ui, 1200, 800));
    h.theme = UI.UI_THEME_DARK;
    h.materials.device = F.App.device;
    _ = F.defaults_batch_material(F.App.device);
    _ = F.defaults_msdf_material(F.App.device);
    assert(R.init(*h.renderer, *h.materials) == "");
    source := F.defaults_msdf_font(F.App.device);
    prepare_ui_font(source, *h.font);
    h.font_texture = F.texture_create_from_colors(F.App.device, source.Atlas.Width, source.Atlas.Height, source.Atlas.Data);
    UI.ui_register_font(*h.ui, *h.font, h.font_texture, .MSDF);
    h.ready = true;
    sample_start();
}
host_render :: () {
    if !h.ready return;
    target := F.drawable_target_window(F.App.window);
    width := cast(float32) F.drawable_target_width_in_pixels(target);
    height := cast(float32) F.drawable_target_height_in_pixels(target);
    if width <= 0 || height <= 0 return;
    h.dt = min(cast(float32) (F.App.time.elapsed - F.App.time.previous), 0.05);
    if h.smoke || h.shot h.dt = 1.0 / 60;
    UI.ui_set_viewport(*h.ui, .{0, 0, width, height}, h.scale);
    mouse := F.input_mouse(F.App.input);
    keyboard := F.input_keyboard(F.App.input);
    size := F.window_size(F.App.window);
    h.pointer = .{mouse.Position.x * width / cast(float32) max(size.x, 1) / h.scale,
                  mouse.Position.y * height / cast(float32) max(size.y, 1) / h.scale};
    h.down = F.mouse_down(mouse, .LEFT);
    h.pressed = F.mouse_pressed(mouse, .LEFT); h.released = F.mouse_released(mouse, .LEFT);
    UI.ui_set_pointer_edges(*h.ui, h.pointer.x * h.scale, h.pointer.y * h.scale, h.down, h.pressed, h.released);
    UI.ui_add_scroll(*h.ui, mouse.WheelValue.x, mouse.WheelValue.y);
    nav: UI.UI_Navigation;
    if F.keyboard_pressed(keyboard, .TAB) nav.next = ifx F.keyboard_shift(keyboard) then -1 else 1;
    nav.activate = F.keyboard_pressed(keyboard, .RETURN);
    nav.cancel = F.keyboard_pressed(keyboard, .ESCAPE);
    if F.keyboard_pressed_or_repeated(keyboard, .LEFT) nav.adjust -= 1;
    if F.keyboard_pressed_or_repeated(keyboard, .RIGHT) nav.adjust += 1;
    UI.ui_set_navigation(*h.ui, nav);
    if h.smoke {
        h.down = false; h.pressed = false; h.released = false; h.pointer = .{-1000, -1000};
        UI.ui_set_pointer(*h.ui, -1000, -1000, false);
        UI.ui_set_navigation(*h.ui, .{});
        sample_test_input();
    }
    sample_update();
    UI.ui_begin(*h.ui, h.dt);
    R.reset(*h.renderer);
    F.graphics_device_clear_color(F.App.device, target, .{15, 20, 27, 255});
    sample_draw();
    UI.ui_draw(*h.ui, *h.renderer);
    sample_after_ui();
    view: R.View; view.target = target;
    assert(R.submit(*h.renderer, view) == .None);
    assert(h.ui.error_count == 0 && !h.ui.pool_overflow, "UI layout failed");
    if h.smoke sample_test_check();
    if (h.shot && h.frame == 8) || h.done {
        sample_capture();
        if h.smoke print("[%] SMOKE PASS\n", h.name);
        F.app_exit();
    }
    if h.smoke && h.frame > 600 { h.failed = true; F.app_exit(); }
    h.frame += 1;
}
host_stop :: () {
    if !h.ready return;
    sample_stop();
    UI.ui_dispose(*h.ui); R.dispose(*h.renderer); MAT.material_library_dispose(*h.materials);
    F.texture_dispose(h.font_texture); free(h.font_texture); array_free(h.font.Glyphs);
}
sample_capture :: () {
    back := F.graphics_device_get_backbuffer(F.App.device, F.App.window);
    assert(back != null);
    texture := F.target_texture(back);
    img := F.image_create(texture.Width, texture.Height); defer F.image_destroy(*img);
    F.texture_get_data(texture, img.Data);
    bright := 0; for p: img.Data if p.r > 100 && p.g > 100 && p.b > 100 bright += 1;
    assert(bright > 100, "GPU output is blank");
    png := F.image_encode_png(img); defer free(png.data);
    assert(FILE.make_directory_if_it_does_not_exist("library/screenshots", true));
    path := tprint("library/screenshots/%-%%-%.png", h.name,
        ifx has_arg("narrow") then "narrow-" else "", ifx has_arg("scaled") then "125" else "100",
        ifx h.smoke then "smoke" else (ifx has_arg("turn") then "turn" else (ifx has_arg("modal") then "modal" else "shot")));
    assert(FILE.write_entire_file(path, cast(string) png));
    print("[%] screenshot: %\n", h.name, path);
}
test_pointer :: (p: F.Vector2, down: bool) {
    h.pointer = p; h.down = down;
    h.pressed = down && !h.ui.pointer_down_prev;
    h.released = !down && h.ui.pointer_down_prev;
    UI.ui_set_pointer(*h.ui, p.x * h.scale, p.y * h.scale, down);
}
test_click :: (id: string, down: bool, fraction: float32 = 0.5) {
    box, found := UI.ui_element_rect(*h.ui, id); assert(found, "Missing test widget: %", id);
    test_pointer(.{box.x + box.w * fraction, box.y + box.h * 0.5}, down);
}
anchor :: (id: string, x: float32, y: float32, w: float32, height: float32 = 0, z: s16 = 10) -> C.ElementDeclaration {
    decl := UI.ui_column_decl(8); decl.id = C.ID(id);
    decl.layout.sizing.width = C.SizingFixed(w);
    if height > 0 decl.layout.sizing.height = C.SizingFixed(height);
    decl.floating = .{attachTo = .ROOT, offset = .[x, y], zIndex = z, pointerCaptureMode = .CAPTURE};
    return decl;
}
label :: (text: string, size: u16, color: F.Color) { UI.ui_label_ex(*h.ui, *h.theme, text, color, size); }
root_element :: () {
    C.UI(C.ElementDeclaration.{layout = .{sizing = .{width = C.SizingFixed(h.ui.width), height = C.SizingFixed(h.ui.height)}}});
}
embed_file :: (path: string) -> string { bytes, ok := FILE.read_entire_file(path); assert(ok, "Missing asset: %", path); return bytes; }
