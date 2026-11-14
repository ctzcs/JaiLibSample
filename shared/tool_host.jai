#import "Basic";
FILE :: #import "File";
CAPTURE_FILES :: #import "File_Utilities";
F :: #import "foster";
IG :: #import "thirdparty/imgui";
GUI :: #import "thirdparty/imgui/imgui_foster";
#load "library_assets.jai";

tool_batch: *F.Batcher;
tool_frame: int;
tool_name: string;
tool_shot, tool_smoke: bool;
tool_capture_requested:bool;
tool_capture_path:string;
tool_capture_serial:int;
tool_scale:float32=1;
tool_glyphs: [13] IG.ImWchar = .[0x20, 0xff, 0x2000, 0x206f, 0x3000, 0x30ff, 0x3400, 0x4dbf, 0x4e00, 0x9fff, 0xff00, 0xffef, 0];

has_arg :: (value: string) -> bool {
    for arg: get_command_line_arguments() if arg == value return true;
    return false;
}

tool_run :: (name: string) {
    tool_name = name;
    tool_shot = has_arg("shot");
    tool_smoke = has_arg("smoke");
    F.App.startup = tool_host_start;
    F.App.render = tool_host_render;
    F.App.shutdown = tool_host_stop;
    F.app_run(.{ application_name = name, window_title = tprint("JaiLib / %", name),
        width = cast(s32) ifx has_arg("narrow") then 960 else 1280, height = 800, update_mode = F.update_mode_unlocked() });
    F.app_destroy();
}

tool_host_start :: () {
    _ = F.defaults_batch_material(F.App.device);
    font_bytes, font_ok := FILE.read_entire_file(SAMPLE_NOTO_PATH);
    assert(font_ok, "JaiLib built-in ImGui font is missing");
    defer free(font_bytes.data);
    tool_scale=max(cast(float32)1,F.window_content_scale(F.App.window).x);
    if has_arg("scaled") tool_scale*=1.25;
    assert(GUI.imgui_foster_setup(SAMPLE_NOTO_C_PATH, tool_glyphs.data,16*tool_scale));
    GUI.imgui_foster_style_kit(tool_scale);
    IG.GetIO().IniFilename = null;
    IG.GetIO().ConfigFlags_ |= .DockingEnable;
    print("Tool theme: scale %, font % px\n",tool_scale,16*tool_scale);
    tool_batch = F.batcher_create(F.App.device);
    tool_start();
}

tool_host_render :: () {
    GUI.imgui_foster_process_input();
    GUI.imgui_foster_new_frame();
    if tool_shot || tool_smoke {
        assert(IG.GetFontSize()==16*tool_scale,"Tool font did not follow UI scale");
        style:=IG.GetStyle();
        assert(style.WindowPadding.x==cast(float32)cast(int)(10*tool_scale) && style.FramePadding.x==cast(float32)cast(int)(7*tool_scale));
        assert(style.FrameRounding==cast(float32)cast(int)(3*tool_scale));
    }
    dt := cast(float32) (F.App.time.elapsed - F.App.time.previous);
    if tool_shot || tool_smoke dt = 1.0 / 60;
    tool_update(dt);
    tool_draw();
    window := F.drawable_target_window(F.App.window);
    F.graphics_device_clear_color(F.App.device, window, .{ 20, 24, 32, 255 });
    F.batcher_clear(tool_batch);
    GUI.imgui_foster_render(tool_batch);
    F.batcher_render(tool_batch, window);
    if tool_capture_requested {
        tool_capture_requested=false;
        assert(FILE.make_directory_if_it_does_not_exist("library/screenshots",true));
        index:=1; path:string;
        while true { path=tprint("library/screenshots/%-capture-%.png",tool_name,index); if !CAPTURE_FILES.file_exists(path) break; index+=1; }
        back:=F.graphics_device_get_backbuffer(F.App.device,F.App.window);
        img:=F.image_create(back.Width,back.Height); defer F.image_destroy(*img);
        F.texture_get_data(F.target_texture(back),img.Data); png:=F.image_encode_png(img); defer free(png.data);
        if FILE.write_entire_file(path,cast(string)png) { free(tool_capture_path.data); tool_capture_path=copy_string(path); tool_capture_serial+=1; print("Saved screenshot: %\n",path); }
    }
    tool_frame += 1;
    if (tool_shot || tool_smoke) && tool_frame >= 60 && tool_ready() {
        tool_check();
        target := F.graphics_device_get_backbuffer(F.App.device, F.App.window);
        image := F.image_create(target.Width, target.Height);
        defer F.image_destroy(*image);
        F.texture_get_data(F.target_texture(target), image.Data);
        themed:=0;
        for pixel:image.Data if pixel.r==22 && pixel.g==26 && pixel.b==33 themed+=1;
        assert(themed>1000,"Tool theme background was not rendered");
        bytes := F.image_encode_png(image);
        defer free(bytes.data);
        assert(FILE.make_directory_if_it_does_not_exist("library/screenshots", true));
        assert(FILE.write_entire_file(tprint("library/screenshots/%.png", tool_name), cast(string) bytes));
        print("[%] SMOKE PASS\n", tool_name);
        F.app_exit();
    }
    assert(tool_frame < 30000 || (!tool_shot && !tool_smoke), "Tool startup timed out");
}

tool_host_stop :: () {
    tool_stop();
    free(tool_capture_path.data);
    F.batcher_destroy(tool_batch);
    GUI.imgui_foster_shutdown();
}
