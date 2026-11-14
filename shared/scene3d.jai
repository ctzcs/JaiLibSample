// Shared desktop host for the 3D samples. Scene state remains in each sample.
#import "Basic";
M :: #import "Math";
using M;
FILE :: #import "File";
F :: #import "foster";
W :: #import "kit/world";
DA :: #import "core/dasset";
R3 :: #import "kit/rendering/3d";
R2 :: #import "kit/rendering/2d";
MAT :: #import "kit/rendering/material";
Scene_Host :: struct {
    storage: F.Storage_Container;
    materials: MAT.Material_Library;
    renderer: R3.Render3D;
    batch: R2.Render2D;
    camera: W.Camera3D;
    target: *F.Target;
    inset: *F.Target;
    show_inset: bool;
    yaw: float32; pitch: float32 = 0.2; distance: float32 = 6;
    focus: W.Vec3;
    mouse_last: F.Vector2;
    time, dt: float32;
    frame: int;
    name: string;
    shot, smoke, failed, started: bool;
}
PERF :: #import "kit/tools/perf_overlay";
PROF :: #import "core/profiler";
UI :: #import "kit/ui";
C :: #import "thirdparty/clay/module";
#load "../src/ui_gallery/font.jai";
scene_perf: PERF.Overlay;
scene_perf_enabled: bool;
scene_font: F.Msdf_Font;
scene_font_texture: *F.Texture;
scene_hud: UI.UI_Context;
scene_theme: UI.UI_Theme;
scene_hud_text: () -> string;
h: Scene_Host;
has_arg :: (value: string) -> bool {
    for arg: get_command_line_arguments() if arg == value return true;
    return false;
}
int_arg :: (prefix: string, fallback: int) -> int {
    for arg: get_command_line_arguments() {
        if arg.count <= prefix.count continue;
        matches := true;
        for c, i: prefix if arg.data[i] != c matches = false;
        if !matches continue;
        value := 0;
        for i: prefix.count..arg.count-1 {
            c := arg.data[i];
            assert(c >= #char "0" && c <= #char "9", "Invalid numeric argument");
            value = value * 10 + cast(int) c - #char "0";
        }
        assert(value > 0); return value;
    }
    return fallback;
}
scene_run :: (name: string) {
    h.name = name; h.shot = has_arg("shot"); h.smoke = has_arg("smoke");
    F.App.startup = scene_host_start; F.App.render = scene_host_render; F.App.shutdown = scene_host_stop;
    F.app_run(.{application_name=name, window_title=tprint("JaiLib / % | Drag: orbit/pan | Wheel: zoom | F: reset | Esc: exit", name),
        width=1100, height=720, preferred_graphics_driver=ifx has_arg("vulkan") then .VULKAN else .NONE,
        update_mode=F.update_mode_unlocked()});
    F.app_destroy();
    if h.failed || !h.started exit(1);
}
scene_host_start :: () {
    h.storage.Root = "."; h.materials.device = F.App.device; h.materials.storage = *h.storage;
    _ = F.defaults_batch_material(F.App.device);
    _ = F.defaults_msdf_material(F.App.device);
    assert(R3.init(*h.renderer, *h.materials) == "");
    assert(R2.init(*h.batch, *h.materials) == "");
    W.camera3d_init(*h.camera, 1100, 720);
    h.started = true; scene_start();
    if scene_perf_enabled || scene_hud_text!=null {
        source:=F.defaults_msdf_font(F.App.device); prepare_ui_font(source,*scene_font);
        scene_font_texture=F.texture_create_from_colors(F.App.device,source.Atlas.Width,source.Atlas.Height,source.Atlas.Data);
    }
    if scene_perf_enabled {
        PROF.profile_init();
        assert(PERF.init(*scene_perf,F.App.device,*scene_font,scene_font_texture)); scene_perf.visible=true;
    }
    if scene_hud_text!=null {
        assert(UI.ui_init(*scene_hud,1100,720)); scene_theme=UI.UI_THEME_DARK;
        UI.ui_register_font(*scene_hud,*scene_font,scene_font_texture,.MSDF);
    }
}
scene_register :: (path: string) {
    files := MAT.material_load_directory(path);
    reason := MAT.material_register_directory(*h.materials, files);
    MAT.material_load_directory_free(files);
    assert(reason == "", "%: %", path, reason);
}
scene_material :: (effect: string) -> *MAT.Material {
    material, reason := MAT.material_create(*h.materials, effect);
    assert(reason == "", "%: %", effect, reason); return material;
}
scene_load_material :: (path: string) -> *MAT.Material {
    material, reason := MAT.material_load(*h.materials, path);
    assert(reason == "", "%: %", path, reason); return material;
}
scene_host_render :: () {
    window := F.drawable_target_window(F.App.window);
    width := F.drawable_target_width_in_pixels(window); height := F.drawable_target_height_in_pixels(window);
    if width <= 0 || height <= 0 return;
    if h.target == null || h.target.Width != width || h.target.Height != height {
        if h.target != null { F.target_dispose(h.target); free(h.target); }
        sample_count:=int_arg("samples=",1);
        assert(sample_count==1 || sample_count==2 || sample_count==4 || sample_count==8,"samples must be 1, 2, 4 or 8");
        samples:F.Sample_Count=.ONE;
        if sample_count==2 samples=.TWO; else if sample_count==4 samples=.FOUR; else if sample_count==8 samples=.EIGHT;
        h.target = F.target_create_attachments(F.App.device,width,height,.[
            .{Format=.COLOR,SampleCount=samples},
            .{Format=.DEPTH32,SampleCount=samples}]);
    }
    h.dt = min(cast(float32) (F.App.time.elapsed - F.App.time.previous), 0.05);
    if h.shot || h.smoke h.dt = 1.0 / 60;
    h.time += h.dt;
    keys := F.input_keyboard(F.App.input); mouse := F.input_mouse(F.App.input);
    if scene_perf_enabled {
        PERF.frame(*scene_perf,h.dt);
        if F.keyboard_pressed(keys,.P) scene_perf.visible=!scene_perf.visible;
    }
    if F.keyboard_pressed(keys, .ESCAPE) F.app_exit();
    if F.keyboard_pressed(keys, .F) { h.focus = .{}; h.pitch = 0.2; h.yaw = 0; h.distance = 6; }
    delta := mouse.Position - h.mouse_last; h.mouse_last = mouse.Position;
    if F.mouse_down(mouse, .LEFT) { h.yaw -= delta.x * 0.006; h.pitch = clamp(h.pitch + delta.y * 0.006, -1.5, 1.5); }
    if F.mouse_down(mouse, .RIGHT) || F.mouse_down(mouse, .MIDDLE) {
        right := W.camera3d_right(*h.camera); up := h.camera.up;
        h.focus.x += (up.x * delta.y - right.x * delta.x) * h.distance * 0.0015;
        h.focus.y += (up.y * delta.y - right.y * delta.x) * h.distance * 0.0015;
        h.focus.z += (up.z * delta.y - right.z * delta.x) * h.distance * 0.0015;
    }
    h.distance = clamp(h.distance * pow(cast(float32) 0.88, mouse.WheelValue.y), 0.3, 2000);
    scene_update();
    W.camera3d_set_viewport(*h.camera, width, height);
    W.camera3d_set_target(*h.camera, h.focus);
    W.camera3d_set_position(*h.camera, .{h.focus.x + sin(h.yaw)*cos(h.pitch)*h.distance,
        h.focus.y + sin(h.pitch)*h.distance, h.focus.z + cos(h.yaw)*cos(h.pitch)*h.distance});
    W.camera3d_set_far_clip(*h.camera, max(cast(float32) 250, h.distance * 3));
    target := F.drawable_target_target(h.target);
    F.graphics_device_clear(F.App.device, target, .[F.Color.{31,38,51,255}], 1, 0, .COLOR | .DEPTH);
    R3.clear(*h.renderer);
    view := R3.View.{target=target, view_projection=W.camera3d_view_projection(*h.camera),
        view_matrix=W.camera3d_view(*h.camera), time=h.time};
    scene_draw(view);
    R2.reset(*h.batch);
    R2.quad_texture(*h.batch, F.target_texture(h.target), .{0,0}, .{cast(float32) width,0},
        .{cast(float32) width,cast(float32) height}, .{0,cast(float32) height}, .{0,0}, .{1,0}, .{1,1}, .{0,1}, F.Color_White);
    if h.show_inset && h.inset!=null {
        _=R2.rect(*h.batch,.{cast(float32)width-338,14,324,204},.{230,234,242,255});
        _=R2.texture(*h.batch,F.target_texture(h.inset),F.matrix3x2_create_translation(cast(float32)width-336,16));
    }
    assert(R2.submit(*h.batch, .{target=window}) == .None);
    if scene_perf_enabled {
        scene_perf.corner=ifx h.show_inset then .Top_Left else .Top_Right;
        PERF.draw(*scene_perf,window,ifx has_arg("scaled") then cast(float32)1.25 else 1);
    }
    if scene_hud_text!=null {
        UI.ui_set_viewport(*scene_hud,.{0,0,cast(float32)width,cast(float32)height},1);
        UI.ui_begin(*scene_hud,h.dt); R2.reset(*h.batch);
        panel:=UI.ui_panel_decl(*scene_theme);
        panel.floating=.{attachTo=.ROOT,offset=.[14,14],pointerCaptureMode=.PASSTHROUGH};
        C.UI(panel,#code { UI.ui_label_ex(*scene_hud,*scene_theme,scene_hud_text(),scene_theme.text,16); });
        UI.ui_draw(*scene_hud,*h.batch); assert(R2.submit(*h.batch,.{target=window})==.None);
        assert(scene_hud.error_count==0 && !scene_hud.pool_overflow);
    }
    h.frame += 1;
    if (h.shot || h.smoke) && h.frame == 12 {
        scene_check(); scene_capture(h.name); print("[%] SMOKE PASS\n", h.name); F.app_exit();
    }
}
scene_capture :: (name: string) {
    final_target:=F.graphics_device_get_backbuffer(F.App.device,F.App.window);
    img := F.image_create(final_target.Width, final_target.Height); defer F.image_destroy(*img);
    F.texture_get_data(F.target_texture(final_target), img.Data);
    changed := 0;
    for p: img.Data if p.r != 31 || p.g != 38 || p.b != 51 changed += 1;
    assert(changed > 100, "Blank 3D render");
    bytes := F.image_encode_png(img); defer free(bytes.data);
    assert(FILE.make_directory_if_it_does_not_exist("library/screenshots", true));
    assert(FILE.write_entire_file(tprint("library/screenshots/%.png", name), cast(string) bytes));
}
scene_host_stop :: () {
    if scene_perf_enabled PERF.dispose(*scene_perf);
    if scene_hud_text!=null UI.ui_dispose(*scene_hud);
    if scene_font_texture!=null { array_free(scene_font.Glyphs); F.texture_dispose(scene_font_texture); free(scene_font_texture); }
    scene_stop(); R3.dispose(*h.renderer); R2.dispose(*h.batch);
    MAT.material_library_dispose(*h.materials);
    if h.target != null { F.target_dispose(h.target); free(h.target); }
    if h.inset != null { F.target_dispose(h.inset); free(h.inset); }
}
#load "geometry3d.jai";
