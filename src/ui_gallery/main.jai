#import "Basic";
STR :: #import "String";
FILE :: #import "File";
F :: #import "foster";
UI :: #import "kit/ui";
R2D :: #import "kit/rendering/2d";
MAT :: #import "kit/rendering/material";
clay :: #import "thirdparty/clay/module";

#load "view.jai";
#load "smoke.jai";
#load "font.jai";

Gallery :: struct {
    ui: UI.UI_Context;
    theme: UI.UI_Theme;
    materials: MAT.Material_Library;
    renderer: R2D.Render2D;
    font_texture: *F.Texture;
    font_view: F.Msdf_Font;
    ready, renderer_ready, started: bool;
    failed: bool;
    frames, checks: int;
    smoke, shot, narrow, scaled: bool;
    scale: float32 = 1;
    music: bool = true;
    volume: float32 = 0.65;
    quality: int = 1;
    name: [..] u8;
    selected: int = -1;
    dialog: bool;
    applied: int;
    status: string = "Ready. Try the controls and select a component.";
}
g: Gallery;

fail :: (reason: string) {
    print("[ui_gallery] FAIL: %\n", reason);
    g.failed = true;
    F.app_exit();
}

startup :: () {
    g.started = true;
    g.theme = UI.UI_THEME_DARK;
    g.theme.window_bg = .{15, 20, 29, 255};
    g.theme.panel = .{23, 31, 43, 255};
    g.theme.accent = .{80, 204, 180, 255};
    g.theme.primary = .{36, 118, 108, 255};
    g.theme.primary_hover = .{45, 143, 131, 255};
    g.theme.primary_press = .{28, 96, 88, 255};
    g.theme.heading_font_size = 26;
    if !UI.ui_init(*g.ui, 1120, 800) { fail("UI initialization"); return; }
    g.materials.device = F.App.device;
    _ = F.defaults_batch_material(F.App.device);
    _ = F.defaults_msdf_material(F.App.device);
    reason := R2D.init(*g.renderer, *g.materials);
    if reason != "" { fail(reason); return; }
    g.renderer_ready = true;
    // Borrow jfoster's embedded Roboto MSDF; no system font or external assets required.
    font := F.defaults_msdf_font(F.App.device);
    if font == null || font.Atlas == null { fail("Embedded MSDF font"); return; }
    g.font_texture = F.texture_create_from_colors(F.App.device, font.Atlas.Width, font.Atlas.Height, font.Atlas.Data);
    prepare_ui_font(font, *g.font_view);
    UI.ui_register_font(*g.ui, *g.font_view, g.font_texture, .MSDF);
    for byte: "Player One" array_add(*g.name, byte);
    g.ready = true;
}

read_input :: (w: float32, h: float32) {
    mouse := F.input_mouse(F.App.input);
    keyboard := F.input_keyboard(F.App.input);
    size := F.window_size(F.App.window);
    UI.ui_set_pointer_edges(*g.ui,
        mouse.Position.x * w / cast(float32) max(size.x, 1),
        mouse.Position.y * h / cast(float32) max(size.y, 1),
        F.mouse_down(mouse, .LEFT), F.mouse_pressed(mouse, .LEFT), F.mouse_released(mouse, .LEFT));
    UI.ui_add_scroll(*g.ui, mouse.WheelValue.x, mouse.WheelValue.y);
    nav: UI.UI_Navigation;
    if F.keyboard_pressed(keyboard, .TAB) nav.next = ifx F.keyboard_shift(keyboard) then -1 else 1;
    nav.activate = F.keyboard_pressed(keyboard, .RETURN);
    if !UI.ui_text_editing(*g.ui) {
        if F.keyboard_pressed_or_repeated(keyboard, .RIGHT) nav.adjust += 1;
        if F.keyboard_pressed_or_repeated(keyboard, .LEFT) nav.adjust -= 1;
    }
    escape := F.keyboard_pressed(keyboard, .ESCAPE);
    nav.cancel = escape;
    if escape && !UI.ui_text_editing(*g.ui) && g.ui.dropdown_id == 0 {
        if g.dialog g.dialog = false;
        else F.app_exit();
    }
    UI.ui_set_navigation(*g.ui, nav);
    edit := UI.UI_Text_Edit.{
        text = STR.builder_to_string(*keyboard.Text),
        backspace = F.keyboard_pressed_or_repeated(keyboard, .BACKSPACE),
        delete = F.keyboard_pressed_or_repeated(keyboard, .DELETE),
        left = F.keyboard_pressed_or_repeated(keyboard, .LEFT),
        right = F.keyboard_pressed_or_repeated(keyboard, .RIGHT),
        home = F.keyboard_pressed(keyboard, .HOME),
        end = F.keyboard_pressed(keyboard, .END),
        submit = F.keyboard_pressed(keyboard, .RETURN), cancel = escape,
    };
    // Clipboard allocation lives until ui_end consumes this frame's text.
    if F.keyboard_ctrl(keyboard) && F.keyboard_pressed(keyboard, .V) {
        clipboard := F.input_clipboard_get(F.App.input);
        {
            push_allocator(temp);
            edit.paste = copy_string(clipboard);
        }
        free(clipboard);
    }
    UI.ui_set_text_edit(*g.ui, edit);
}

render :: () {
    if !g.ready return;
    target := F.drawable_target_window(F.App.window);
    w := cast(float32) F.drawable_target_width_in_pixels(target);
    h := cast(float32) F.drawable_target_height_in_pixels(target);
    UI.ui_set_viewport(*g.ui, .{0, 0, w, h}, g.scale);
    read_input(w, h);
    if g.smoke smoke_input();
    UI.ui_set_modal(*g.ui, ifx g.dialog then "confirm-dialog" else "");
    UI.ui_begin(*g.ui, cast(float32) (F.App.time.elapsed - F.App.time.previous));
    draw_gallery();
    R2D.reset(*g.renderer);
    UI.ui_draw(*g.ui, *g.renderer);
    F.window_set_text_input(F.App.window, UI.ui_text_editing(*g.ui));
    caret, editing := UI.ui_text_input_area(*g.ui);
    if editing _ = F.window_set_text_input_area(F.App.window, caret);
    F.graphics_device_clear_color(F.App.device, target, g.theme.window_bg);
    view: R2D.View;
    view.target = target;
    view.time = cast(float32) F.App.time.elapsed;
    view.delta_time = cast(float32) (F.App.time.elapsed - F.App.time.previous);
    view.frame = F.App.time.frame;
    if R2D.submit(*g.renderer, view) != .None { fail("Render2D submit"); return; }
    if g.ui.error_count > 0 || g.ui.pool_overflow { fail("Clay layout error / UI pool overflow"); return; }
    if g.smoke smoke_check();
    else if g.shot && g.frames == 5 {
        capture("shot");
        F.app_exit();
    }
    g.frames += 1;
}

shutdown :: () {
    UI.ui_dispose(*g.ui);
    if g.renderer_ready R2D.dispose(*g.renderer);
    MAT.material_library_dispose(*g.materials);
    if g.font_texture != null {
        F.texture_dispose(g.font_texture);
        free(g.font_texture);
    }
    array_free(g.name);
    // Atlas and lookup are borrowed from the device; only this glyph array is ours.
    array_free(g.font_view.Glyphs);
    print("[ui_gallery] % frames, % checks, %\n", g.frames, g.checks, ifx g.failed then "FAIL" else "OK");
}

main :: () {
    for arg: get_command_line_arguments() {
        if arg == "auto" || arg == "smoke" g.smoke = true;
        if arg == "shot" g.shot = true;
        if arg == "modal" g.dialog = true;
        if arg == "narrow" g.narrow = true;
        if arg == "scaled" { g.scaled = true; g.scale = 1.25; }
    }
    // Smoke always starts from a known state before opening the dialog via a button.
    if g.smoke g.dialog = false;
    F.App.startup = startup;
    F.App.render = render;
    F.App.shutdown = shutdown;
    F.app_run(.{
        application_name = "JaiLibSample",
        window_title = "JaiLib / UI Gallery",
        width = cast(s32) (ifx g.narrow then 760 else 1120),
        height = 800,
        update_mode = F.update_mode_unlocked(),
    });
    F.app_destroy();
    if !g.started || g.failed || (g.smoke && g.frames < 72) exit(1);
}
