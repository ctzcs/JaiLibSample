#load "../../shared/tool_host.jai";
M :: #import "Math";
using M;
W :: #import "kit/world";
DA :: #import "core/dasset";
R3 :: #import "kit/rendering/3d";
MAT :: #import "kit/rendering/material";
G :: #import "kit/gizmo";
NOTES :: #import "kit/tools/scene_notes";
STR :: #import "String";
#load "../../shared/geometry3d.jai";
Object :: struct { position,size: W.Vec3; color: [4] float32; }
OBJECTS: [5] Object=.[
    .{.{0,-0.2,0},.{12,0.4,10},.[0.42,0.46,0.39,1]},
    .{.{-2.7,0.75,1.5},.{1.5,1.5,1.5},.[0.9,0.46,0.2,1]},
    .{.{0,0.35,1.5},.{2.5,0.7,1.6},.[0.26,0.55,0.78,1]},
    .{.{2.8,1.45,-0.7},.{1.4,2.9,1.4},.[0.35,0.68,0.48,1]},
    .{.{-1.3,1.15,-2.8},.{4.5,2.3,0.55},.[0.53,0.43,0.68,1]}];
notes: NOTES.Session;
library: MAT.Material_Library;
renderer: R3.Render3D;
materials: [5] *MAT.Material;
mesh: F.Mesh;
target: *F.Target;
camera: W.Camera3D;
yaw: float32=0.4;
pitch: float32=0.6;
distance: float32=13;
focus: W.Vec3;
viewport: F.Rect;
mouse_last: F.Vector2;
draft,editing,show_resolved,orbiting,exit_requested: bool;
selected: u64;
draft_position: W.Vec3;
note_text: [16385] u8;
note_title: [257] u8;
note_screenshot: [2049] u8;
note_resolution: [2049] u8;
note_query: [257] u8;
note_resolved: bool;
error: string;
last_capture_serial:int;
main :: () { tool_run("scene_notes"); }
tool_start :: () {
    F.App.on_exit_requested=request_exit;
    F.App.window.on_close_requested=request_exit;
    path: string=NOTES.DEFAULT_PATH;
    if tool_smoke path="build/scene-notes-smoke.json";
    for arg: get_command_line_arguments() if STR.begins_with(arg,"notes=") path=string.{arg.count-6,arg.data+6};
    assert(NOTES.init(*notes,path)==.None);
    library.device=F.App.device;
    files:=MAT.material_load_directory("src/scene_notes/shaders/Compiled");
    assert(MAT.material_register_directory(*library,files)==""); MAT.material_load_directory_free(files);
    for *material,i: materials {
        reason: string; material.*,reason=MAT.material_create(*library,"SceneNotes"); assert(reason=="");
        assert(MAT.material_set_number(material.*,"SceneNotes_body","color",OBJECTS[i].color));
    }
    assert(R3.init(*renderer,*library)=="");
    p:=cube(); defer primitive_free(*p); assert(R3.mesh_upload(*mesh,F.App.device,*p));
    W.camera3d_init(*camera,800,600); reset_camera();
    if has_arg("draft") { draft=true; editing=true; draft_position=.{0,0.7,1.5}; }
}
request_exit :: () { exit_requested=true; }
text_view :: (bytes: [] u8) -> string { n:=0; while n<bytes.count && bytes[n]!=0 n+=1; return .{n,bytes.data}; }
set_buffer :: (bytes: [] u8,text: string) { memset(bytes.data,0,bytes.count); memcpy(bytes.data,text.data,min(bytes.count-1,text.count)); }
report :: (result: NOTES.Error) { error=NOTES.error_text(result); }
open_note :: (id: u64) {
    note,found:=NOTES.find(*notes,id); if !found return;
    selected=id; editing=true; draft=false; draft_position=note.position;
    set_buffer(note_text,note.text); set_buffer(note_title,note.title); set_buffer(note_screenshot,note.screenshot);
    set_buffer(note_resolution,note.resolution); note_resolved=note.status==NOTES.RESOLVED;
}
save_note :: () -> bool {
    result: NOTES.Error;
    if draft {
        id: u64;
        id,result=NOTES.add(*notes,.{scene="scene_notes/sandbox",has_position=true,position=draft_position,
            title=text_view(note_title),text=text_view(note_text),screenshot=text_view(note_screenshot),source_hint="src/scene_notes/main.jai"},true);
        if result==.None selected=id;
    } else {
        note,found:=NOTES.find(*notes,selected); if !found return false;
        note.title=text_view(note_title); note.text=text_view(note_text); note.screenshot=text_view(note_screenshot);
        note.status=ifx note_resolved then NOTES.RESOLVED else NOTES.PENDING;
        note.resolution=ifx note_resolved then text_view(note_resolution) else "";
        result=NOTES.replace(*notes,note,true);
    }
    report(result); if result!=.None return false;
    draft=false; editing=false; return true;
}
reset_camera :: () { focus=.{0,.5,0}; yaw=.52; pitch=.61; distance=16; orbiting=false; }
tool_update :: (dt: float32) {
    if tool_capture_path!="" && last_capture_serial!=tool_capture_serial { last_capture_serial=tool_capture_serial; if editing set_buffer(note_screenshot,tool_capture_path); error=tool_capture_path; }
    if tool_smoke && tool_frame==10 tool_capture_requested=true;
    if !F.window_focused(F.App.window) orbiting=false;
    keys:=F.input_keyboard(F.App.input);
    if F.keyboard_pressed(keys,.ESCAPE) {
        if editing { draft=false; editing=false; } else exit_requested=true;
    }
}
pick_position :: (pixel: W.Vec2) -> (W.Vec3,bool) {
    ray,ok:=W.camera3d_screen_point_to_ray(*camera,.{pixel.x-viewport.x,pixel.y-viewport.y}); if !ok return .{},false;
    nearest:=M.FLOAT32_INFINITY;
    for o: OBJECTS {
        lo:=W.Vec3.{o.position.x-o.size.x/2,o.position.y-o.size.y/2,o.position.z-o.size.z/2};
        hi:=W.Vec3.{o.position.x+o.size.x/2,o.position.y+o.size.y/2,o.position.z+o.size.z/2};
        t,hit:=W.ray3d_hit_aabb(ray,lo,hi); if hit && t>=0 nearest=min(nearest,t);
    }
    if nearest==M.FLOAT32_INFINITY return .{},false;
    return W.ray3d_at(ray,nearest),true;
}
tool_draw :: () {
    display:=IG.GetIO().DisplaySize;
    header:=IG.GetTextLineHeightWithSpacing()*2+IG.GetFrameHeight()+IG.GetStyle().WindowPadding.y*2+IG.GetStyle().ItemSpacing.y;
    IG.SetNextWindowPos(.{16,12},.Always); IG.SetNextWindowSize(.{max(cast(float32)200,display.x-32),header},.Always);
    IG.Begin("操作说明##notes",null,.NoDecoration | .NoMove | .NoSavedSettings | .NoDocking);
    IG.TextUnformatted("场景批注 · 保存后交给 Agent");
    IG.BeginDisabled(editing); if IG.Button("重置视角") reset_camera(); IG.EndDisabled();
    IG.SameLine(); if IG.Button("保存截图") tool_capture_requested=true;
    IG.TextUnformatted("左键：放置便签／打开图钉   右键：旋转   滚轮：缩放"); IG.End();
    panel_width:=min(460*tool_scale,display.x*.46);
    origin:=IG.ImVec2.{16,header+20}; size:=IG.ImVec2.{max(cast(float32)1,display.x-panel_width-48),max(cast(float32)1,display.y-header-42)};
    IG.SetNextWindowPos(origin,.Always); IG.SetNextWindowSize(size,.Always);
    IG.PushStyleVar(.WindowPadding,.{0,0});
    IG.Begin("Scene##notes",null,.NoDecoration | .NoMove | .NoSavedSettings | .NoDocking | .NoScrollbar | .NoScrollWithMouse);
    IG.PopStyleVar();
    viewport=.{origin.x,origin.y,size.x,size.y};
    w:=cast(s32) size.x; height:=cast(s32) size.y;
    if target==null || target.Width!=w || target.Height!=height {
        if target!=null { F.target_dispose(target); free(target); }
        target=F.target_create_attachments(F.App.device,w,height,.[.{Format=.COLOR,SampleCount=.FOUR},.{Format=.DEPTH32,SampleCount=.FOUR}]);
        orbiting=false;
    }
    viewport.w=cast(float32) w; viewport.h=cast(float32) height;
    mouse:=F.input_mouse(F.App.input); pointer:=F.Vector2.{IG.GetIO().MousePos.x,IG.GetIO().MousePos.y}; delta:=pointer-mouse_last; mouse_last=pointer;
    inside:=pointer.x>=viewport.x && pointer.x<viewport.x+viewport.w && pointer.y>=viewport.y && pointer.y<viewport.y+viewport.h;
    if !editing {
        if inside && F.mouse_pressed(mouse,.RIGHT) orbiting=true;
        if !F.mouse_down(mouse,.RIGHT) orbiting=false;
        if orbiting { yaw-=delta.x*0.006; pitch=clamp(pitch+delta.y*0.006,0.1,1.5); }
        if inside distance=clamp(distance*pow(cast(float32) 0.88,mouse.WheelValue.y),3,40);
    }
    W.camera3d_set_viewport(*camera,w,height); W.camera3d_set_target(*camera,focus);
    W.camera3d_set_position(*camera,.{focus.x+sin(yaw)*cos(pitch)*distance,focus.y+sin(pitch)*distance,focus.z+cos(yaw)*cos(pitch)*distance});
    surface:=F.drawable_target_target(target); F.graphics_device_clear(F.App.device,surface,.[F.Color.{39,49,65,255}],1,0,.COLOR | .DEPTH);
    R3.clear(*renderer);
    for o,i: OBJECTS {
        transform:=W.matrix4_multiply(W.matrix4_scaling(o.size.x,o.size.y,o.size.z),W.matrix4_translation(o.position.x,o.position.y,o.position.z));
        assert(R3.model(*renderer,*mesh,materials[i],transform)==.None);
    }
    assert(R3.submit(*renderer,.{target=surface,view_projection=W.camera3d_view_projection(*camera),view_matrix=W.camera3d_view(*camera)})==.None);
    IG.Image(GUI.imgui_foster_register_texture(F.target_texture(target)),size);
    clicked:=inside && F.mouse_pressed(mouse,.LEFT) && !editing && !tool_shot && !tool_smoke;
    draw:=IG.GetWindowDrawList();
    for note: NOTES.all(*notes) {
        if note.scene!="scene_notes/sandbox" || (!show_resolved && note.status==NOTES.RESOLVED) continue;
        p,visible:=G.project(*camera,note.position,viewport); if !visible continue;
        a:=IG.ImVec2.{p.x-8,p.y-8}; b:=IG.ImVec2.{p.x+8,p.y+8};
        color: u32=ifx note.status==NOTES.RESOLVED then 0xff77cc66 else 0xff55ddff;
        GUI.DrawList_AddRectFilled(draw,*a,*b,color,3);
        if clicked && abs(pointer.x-p.x)<12 && abs(pointer.y-p.y)<12 { open_note(note.id); clicked=false; }
    }
    if clicked { position,ok:=pick_position(pointer); if ok { draft_position=position; draft=true; editing=true; selected=0; set_buffer(note_text,""); set_buffer(note_title,""); set_buffer(note_screenshot,""); } }
    if draft {
        p,visible:=G.project(*camera,draft_position,viewport);
        if visible { a:=IG.ImVec2.{p.x-7,p.y-7}; b:=IG.ImVec2.{p.x+7,p.y+7}; GUI.DrawList_AddRectFilled(draw,*a,*b,0xff55ddff,3); }
    }
    IG.End();
    IG.SetNextWindowPos(.{display.x-panel_width-16,origin.y},.Always); IG.SetNextWindowSize(.{panel_width,size.y},.Always);
    IG.Begin("场景批注##panel",null,.NoMove | .NoResize | .NoCollapse | .NoDocking);
    IG.TextUnformatted("Notes / scene_notes/sandbox");
    IG.Checkbox("Show resolved",*show_resolved);
    IG.InputText("Search",note_query.data,note_query.count);
    if !editing {
        if IG.Button("Save file") report(NOTES.save(*notes));
        IG.SameLine(); if IG.Button("Reload") report(NOTES.reload(*notes));
        if IG.Button("Undo") report(NOTES.undo(*notes));
        IG.SameLine(); if IG.Button("Redo") report(NOTES.redo(*notes));
        for note: NOTES.all(*notes) {
            if note.scene!="scene_notes/sandbox" continue;
            if !show_resolved && note.status==NOTES.RESOLVED continue;
            query:=text_view(note_query);
            if query!="" && !STR.contains(note.title,query) && !STR.contains(note.text,query) continue;
            label:=tprint("#% %",note.id,ifx note.title!="" then note.title else note.text);
            if IG.Button(temp_c_string(label)) open_note(note.id);
        }
    }
    IG.TextWrapped(temp_c_string(error)); IG.End();
    if editing {
        p,visible:=G.project(*camera,draft_position,viewport);
        editor_width:=min(display.x-30,340*tool_scale); editor_height:=min(display.y-30,350*tool_scale);
        if visible IG.SetNextWindowPos(.{max(cast(float32)15,min(p.x+16,display.x-editor_width-15)),max(cast(float32)15,min(p.y,display.y-editor_height-15))},.Appearing);
        IG.SetNextWindowSize(.{editor_width,editor_height},.Appearing);
        IG.Begin("Edit note",null,.NoCollapse);
        IG.InputText("Title",note_title.data,note_title.count);
        IG.InputTextMultiline("Note",note_text.data,note_text.count,.{0,120*tool_scale});
        IG.InputText("Screenshot",note_screenshot.data,note_screenshot.count);
        if !draft {
            IG.Checkbox("Resolved",*note_resolved);
            if note_resolved IG.InputText("Resolution",note_resolution.data,note_resolution.count);
        }
        if IG.Button("Save") _=save_note(); IG.SameLine();
        if IG.Button("Cancel") { editing=false; draft=false; }
        IG.SameLine(); if selected!=0 && IG.Button("Focus") { focus=draft_position; distance=6; }
        IG.TextWrapped(temp_c_string(error)); IG.End();
    }
    if exit_requested {
        if !NOTES.is_dirty(*notes) && !editing F.app_exit();
        else {
            IG.Begin("Unsaved notes");
            if IG.Button("Save and exit") { if editing { if save_note() F.app_exit(); } else { report(NOTES.save(*notes)); if error=="" F.app_exit(); } }
            if IG.Button("Discard and exit") F.app_exit();
            if IG.Button("Cancel") exit_requested=false;
            IG.End();
        }
    }
}
tool_ready :: () -> bool { return true; }
tool_check :: () {
    assert(renderer.draw_calls==5);
    assert(F.target_texture(target).SampleCount==.FOUR);
    if tool_smoke { yaw=1; pitch=1; distance=3; reset_camera(); assert(yaw==.52 && pitch==.61 && distance==16 && focus.y==.5); }
    if !tool_smoke return;
    assert(tool_capture_path!="");
    captured,ok:=FILE.read_entire_file(tool_capture_path); assert(ok && captured.count>1000); free(captured.data);
    before:=NOTES.all(*notes).count;
    id,result:=NOTES.add(*notes,.{scene="scene_notes/sandbox",has_position=true,position=.{0,0,0},text="Smoke test only"}); assert(result==.None);
    assert(NOTES.all(*notes).count==before+1); assert(NOTES.undo(*notes)==.None); assert(NOTES.all(*notes).count==before);
    assert(NOTES.redo(*notes)==.None); note,found:=NOTES.find(*notes,id); assert(found && note.text=="Smoke test only");
    assert(NOTES.resolve(*notes,id,"Verified in smoke fixture")==.None);
    note,found=NOTES.find(*notes,id); assert(found && note.status==NOTES.RESOLVED);
    assert(NOTES.reopen(*notes,id)==.None);
    note,found=NOTES.find(*notes,id); assert(found && note.status==NOTES.PENDING && note.resolution=="");
    assert(NOTES.undo(*notes)==.None); assert(NOTES.undo(*notes)==.None);
    assert(NOTES.undo(*notes)==.None); // No test notes are saved.
}
tool_stop :: () {
    NOTES.dispose(*notes); R3.dispose(*renderer); R3.mesh_dispose(*mesh); MAT.material_library_dispose(*library);
    if target!=null { F.target_dispose(target); free(target); }
}
