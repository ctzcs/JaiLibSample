// Player UI uses kit/ui (Clay). This host has no ImGui dependency.
#import "Basic";
FILE :: #import "File";
F :: #import "foster";
UI :: #import "kit/ui";
CLAY :: #import "thirdparty/clay/module";
G2 :: #import "kit/rendering/2d";
GMAT :: #import "kit/rendering/material";
GSTR :: #import "String";
#load "../src/ui_gallery/font.jai";

game_ui: UI.UI_Context;
game_theme: UI.UI_Theme;
game_materials: GMAT.Material_Library;
game_canvas: G2.Render2D;
game_font: F.Msdf_Font;
game_font_texture: *F.Texture;
game_frame: int;
game_name: string;
game_shot, game_smoke, game_finished: bool;
game_width, game_height: s32;
game_scale: float32 = 1;
game_capture: UI.UI_Input_Capture;
game_text_captured: bool;

has_arg :: (value: string) -> bool { for arg: get_command_line_arguments() if arg == value return true; return false; }
game_run :: (name: string) {
    game_name=name; game_shot=has_arg("shot"); game_smoke=has_arg("smoke") || has_arg("menu-test") || has_arg("tracer-test");
    if has_arg("scaled") game_scale=1.25;
    F.App.startup=game_host_start; F.App.render=game_host_render; F.App.shutdown=game_host_stop;
    F.app_run(.{application_name=name, window_title=tprint("JaiLib / %",name),
        width=cast(s32) ifx has_arg("narrow") then 760 else 1280, height=800, update_mode=F.update_mode_unlocked()});
    F.app_destroy();
    if (game_shot || game_smoke) && !game_finished exit(1);
}
game_host_start :: () {
    _=F.defaults_batch_material(F.App.device); _=F.defaults_msdf_material(F.App.device);
    game_materials.device=F.App.device; assert(G2.init(*game_canvas,*game_materials)=="");
    assert(UI.ui_init(*game_ui,1280,800)); game_theme=UI.UI_THEME_DARK;
    game_theme.panel=.{19,27,38,232}; game_theme.accent=.{89,212,191,255};
    game_theme.primary=.{33,110,107,255}; game_theme.body_font_size=17;
    source:=F.defaults_msdf_font(F.App.device); prepare_ui_font(source,*game_font);
    game_font_texture=F.texture_create_from_colors(F.App.device,source.Atlas.Width,source.Atlas.Height,source.Atlas.Data);
    UI.ui_register_font(*game_ui,*game_font,game_font_texture,.MSDF);
    game_start();
}
game_host_input :: () {
    mouse:=F.input_mouse(F.App.input); keys:=F.input_keyboard(F.App.input); size:=F.window_size(F.App.window);
    focused:=F.window_focused(F.App.window);
    UI.ui_set_pointer_edges(*game_ui,mouse.Position.x*cast(float32)game_width/cast(float32)max(size.x,1),
        mouse.Position.y*cast(float32)game_height/cast(float32)max(size.y,1),
        focused && F.mouse_down(mouse,.LEFT),focused && F.mouse_pressed(mouse,.LEFT),!focused || F.mouse_released(mouse,.LEFT));
    UI.ui_add_scroll(*game_ui,mouse.WheelValue.x,mouse.WheelValue.y);
    game_text_captured=UI.ui_text_editing(*game_ui);
    nav:UI.UI_Navigation;
    if F.keyboard_pressed(keys,.TAB) nav.next=ifx F.keyboard_shift(keys) then -1 else 1;
    nav.activate=F.keyboard_pressed(keys,.RETURN); nav.cancel=F.keyboard_pressed(keys,.ESCAPE);
    if !game_text_captured {
        if F.keyboard_pressed_or_repeated(keys,.LEFT) nav.adjust-=1;
        if F.keyboard_pressed_or_repeated(keys,.RIGHT) nav.adjust+=1;
    }
    UI.ui_set_navigation(*game_ui,nav);
    edit:=UI.UI_Text_Edit.{text=GSTR.builder_to_string(*keys.Text),backspace=F.keyboard_pressed_or_repeated(keys,.BACKSPACE),
        delete=F.keyboard_pressed_or_repeated(keys,.DELETE),left=F.keyboard_pressed_or_repeated(keys,.LEFT),right=F.keyboard_pressed_or_repeated(keys,.RIGHT),
        home=F.keyboard_pressed(keys,.HOME),end=F.keyboard_pressed(keys,.END),submit=nav.activate,cancel=nav.cancel};
    if F.keyboard_ctrl(keys) && F.keyboard_pressed(keys,.V) {
        clip:=F.input_clipboard_get(F.App.input); { push_allocator(temp); edit.paste=copy_string(clip); } free(clip);
    }
    if !focused { edit=.{}; edit.cancel=true; }
    UI.ui_set_text_edit(*game_ui,edit);
    if game_smoke { UI.ui_set_pointer(*game_ui,-1000,-1000,false); UI.ui_set_navigation(*game_ui,.{}); UI.ui_set_text_edit(*game_ui,.{}); }
    game_test_input();
}
game_host_render :: () {
    window:=F.drawable_target_window(F.App.window);
    game_width=F.drawable_target_width_in_pixels(window); game_height=F.drawable_target_height_in_pixels(window);
    if game_width<=0 || game_height<=0 return;
    dt:=min(cast(float32)(F.App.time.elapsed-F.App.time.previous),cast(float32).05);
    if game_shot || game_smoke dt=1.0/60;
    UI.ui_set_viewport(*game_ui,.{0,0,cast(float32)game_width,cast(float32)game_height},game_scale);
    game_host_input(); UI.ui_begin(*game_ui,dt); G2.reset(*game_canvas);
    F.graphics_device_clear_color(F.App.device,window,.{12,19,29,255});
    CLAY.UI(CLAY.ElementDeclaration.{layout=.{sizing=.{width=CLAY.SizingFixed(game_ui.width),height=CLAY.SizingFixed(game_ui.height)}}});
    game_draw(); UI.ui_draw(*game_ui,*game_canvas);
    game_capture=UI.ui_input_capture(*game_ui);
    game_text_captured=game_text_captured || UI.ui_text_editing(*game_ui);
    F.window_set_text_input(F.App.window,UI.ui_text_editing(*game_ui));
    caret,editing:=UI.ui_text_input_area(*game_ui); if editing _=F.window_set_text_input_area(F.App.window,caret);
    assert(G2.submit(*game_canvas,.{target=window})==.None);
    assert(game_ui.error_count==0 && !game_ui.pool_overflow,"Clay layout failed");
    // UI consumes this frame's input before it can reach gameplay.
    game_update(dt); game_frame+=1;
    if (game_shot || game_smoke) && game_frame>=60 && game_ready() {
        game_check();
        target:=F.graphics_device_get_backbuffer(F.App.device,F.App.window);
        image:=F.image_create(target.Width,target.Height); defer F.image_destroy(*image);
        F.texture_get_data(F.target_texture(target),image.Data);
        bytes:=F.image_encode_png(image); defer free(bytes.data);
        assert(FILE.make_directory_if_it_does_not_exist("library/screenshots",true));
        assert(FILE.write_entire_file(tprint("library/screenshots/%.png",game_name),cast(string)bytes));
        game_finished=true; print("[%] SMOKE PASS (Clay UI)\n",game_name); F.app_exit();
    }
    assert(game_frame<30000 || (!game_shot && !game_smoke),"Game startup timed out");
}
game_host_stop :: () {
    game_stop(); UI.ui_dispose(*game_ui); G2.dispose(*game_canvas); GMAT.material_library_dispose(*game_materials);
    F.texture_dispose(game_font_texture); free(game_font_texture); array_free(game_font.Glyphs);
}
game_panel :: (id:string,x,y,width:float32,capture:bool=false)->CLAY.ElementDeclaration {
    d:=UI.ui_panel_decl(*game_theme,8,width); d.id=CLAY.ID(id); d.layout.padding=CLAY.PaddingAll(16);
    d.floating=.{attachTo=.ROOT,offset=.[x,y],zIndex=10,pointerCaptureMode=ifx capture then .CAPTURE else .PASSTHROUGH};
    if capture UI.ui_block_pointer(*game_ui,id); return d;
}
game_label :: (text:string,size:u16=17,color:F.Color=F.Color_White) { UI.ui_label_ex(*game_ui,*game_theme,text,color,size); }
game_test_click :: (id:string,down:bool) {
    box,ok:=UI.ui_element_rect(*game_ui,id); assert(ok,"Missing Clay widget: %",id);
    UI.ui_set_pointer(*game_ui,(box.x+box.w*.5)*game_scale,(box.y+box.h*.5)*game_scale,down);
}
