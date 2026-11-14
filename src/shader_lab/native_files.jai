// SDL dialog callbacks and event watches may run off the render thread.
// Only owned paths cross this boundary; LAB is always called on the main thread.
THREAD :: #import "Thread";
SDL3 :: F.SDL3;
Dialog_Filter :: struct { name,pattern:*u8; }
Dialog_Callback :: #type (user:*void,files:**u8,filter:s32) #c_call;
SDL_ShowOpenFileDialog :: (callback:Dialog_Callback,user:*void,window:*F.SDL_Window,filters:*Dialog_Filter,count:s32,location:*u8,many:bool) #foreign SDL3;
SDL_ShowSaveFileDialog :: (callback:Dialog_Callback,user:*void,window:*F.SDL_Window,filters:*Dialog_Filter,count:s32,location:*u8) #foreign SDL3;
Drop_Event :: struct { type:F.SDL_EventType; reserved:u32; timestamp:u64; windowID:u32; x,y:float32; source,data:*u8; }
Native_Result :: struct { id:u64; path:string; failed:bool; }
Native_Drop :: struct { path:string; x,y:float32; }
native_context:#Context;
native_mutex:THREAD.Mutex;
native_closed,native_pending:bool;
native_id:u64;
native_window:u32;
native_results:[..]Native_Result;
native_drops:[..]Native_Drop;
frame_drops:[..]string;
frame_drop_position:[2]float32;
native_filter:Dialog_Filter;
native_error:string;
native_start :: () {
    native_context=context; THREAD.init(*native_mutex,"shader_lab files"); native_window=F.SDL_GetWindowID(F.App.window.handle);
    assert(F.SDL_AddEventWatch(native_watch,null));
}
native_callback :: (user:*void,files:**u8,filter:s32) #c_call {
    push_context native_context {
        THREAD.lock(*native_mutex); defer THREAD.unlock(*native_mutex);
        if native_closed return;
        path:string; if files!=null && files.*!=null path=copy_string(to_string(files.*));
        array_add(*native_results,Native_Result.{native_id,path,files==null});
    }
}
native_watch :: (user:*void,event:*F.SDL_Event)->bool #c_call {
    if event.type!=.SDL_EVENT_DROP_FILE return true;
    push_context native_context {
        e:=cast(*Drop_Event)event;
        THREAD.lock(*native_mutex); defer THREAD.unlock(*native_mutex);
        if !native_closed && e.windowID==native_window && e.data!=null array_add(*native_drops,Native_Drop.{copy_string(to_string(e.data)),e.x,e.y});
    }
    return true;
}
native_poll :: () {
    results:[..]Native_Result; drops:[..]Native_Drop;
    THREAD.lock(*native_mutex); results=native_results; native_results=[..]Native_Result.{}; drops=native_drops; native_drops=[..]Native_Drop.{}; THREAD.unlock(*native_mutex);
    defer array_free(results); defer array_free(drops);
    for r:results {
        native_pending=false;
        if r.failed { _=LAB.file_reply(*session,r.id,""); native_error="The operating system could not open the file dialog."; }
        else if !LAB.file_reply(*session,r.id,r.path) native_error="File was rejected, or its parameter changed while the dialog was open.";
        free(r.path.data);
    }
    physical:=F.window_size_in_pixels(F.App.window); logical:=F.window_size(F.App.window);
    for d:drops {
        array_add(*frame_drops,d.path);
        frame_drop_position=.[d.x*cast(float32)physical.x/max(cast(float32)1,cast(float32)logical.x),d.y*cast(float32)physical.y/max(cast(float32)1,cast(float32)logical.y)];
    }
}
native_request :: () {
    request:=LAB.file_request(*session); if request.id==0 || native_pending return;
    native_pending=true; native_id=request.id; native_error="";
    native_filter=ifx request.action==.Texture then Dialog_Filter.{"Images","png;jpg;jpeg;bmp;tga;gif;psd;hdr;pic;pnm"} else Dialog_Filter.{"Shader preset","json"};
    if request.action==.Save_Preset SDL_ShowSaveFileDialog(native_callback,null,F.App.window.handle,*native_filter,1,null);
    else SDL_ShowOpenFileDialog(native_callback,null,F.App.window.handle,*native_filter,1,null,false);
}
native_end_frame :: () { for p:frame_drops free(p.data); frame_drops.count=0; }
native_stop :: () {
    free(file_drop_path.data);
    F.SDL_RemoveEventWatch(native_watch,null);
    THREAD.lock(*native_mutex); native_closed=true;
    for r:native_results free(r.path.data); array_free(native_results);
    for d:native_drops free(d.path.data); array_free(native_drops);
    THREAD.unlock(*native_mutex); native_end_frame(); array_free(frame_drops);
    // SDL owns outstanding dialogs. The process-lifetime mutex/context remain valid
    // so a late cancellation callback cannot access the disposed LAB session.
}

// Regression enters through the same C callback as SDL; it never opens a dialog.
native_test_reply :: (id:u64,path:string)->bool {
    native_pending=true; native_id=id; native_error="";
    names:[2]*u8; if path!="" names[0]=temp_c_string(path);
    native_callback(null,names.data,0); native_poll();
    return !native_pending && native_error=="" && LAB.file_request(*session).id==0;
}
file_drop_phase:int;
file_drop_field:int;
file_drop_path:string;
native_audit_drop :: () {
    if audit_shader<0 || audit_wait<3 return;
    if file_drop_phase==2 || session.bank==null || session.selected<0 || session.selected_shader<0 || session.selected_shader>=session.bank.shaders.count return;
    if session.bank.shaders[session.selected_shader].desc.name!="Preview2D" return;
    parameter:=*session.bank.parameters[session.selected]; if !parameter.available return;
    if file_drop_phase==1 {
        assert(parameter.values[file_drop_field].texture==file_drop_path,"SDL drop did not reach the texture card");
        texture:=parameter.textures[0]; assert(texture!=null && texture.Width==16 && texture.Height==16);
        pixels:[256]F.Color; F.texture_get_data(texture,pixels); assert(pixels[0].r==37 && pixels[0].g==183,"Dropped texture has wrong GPU pixels");
        assert(LAB.reset_defaults(*session,session.selected,file_drop_field));
        file_drop_phase=2; print("Native file callbacks / owned drop path / texture-card GPU upload PASS\n"); return;
    }
    for field,i:parameter.live.fields {
        if field.kind!=.Texture continue;
        rect,found:=LAB.widget_rect(*session,tprint("texture:%:%",parameter.name,field.id)); if !found continue;
        image:=F.image_create(16,16); defer F.image_destroy(*image); for *pixel:image.Data pixel.*=.{37,183,91,255};
        png:=F.image_encode_png(image); defer free(png.data);
        assert(FILE.write_entire_file("build/shader-drop.png",cast(string)png)); file_drop_path=FILE.get_absolute_path("build/shader-drop.png");
        // The SDL event buffer and filename are borrowed. Release them immediately
        // after the watch returns, before the next frame consumes its owned copy.
        name:=copy_string(file_drop_path); defer free(name.data);
        physical:=F.window_size_in_pixels(F.App.window); logical:=F.window_size(F.App.window);
        e:=Drop_Event.{type=.SDL_EVENT_DROP_FILE,windowID=native_window,data=temp_c_string(name)};
        e.x=(rect.min[0]+rect.max[0])*.5*cast(float32)logical.x/cast(float32)physical.x;
        e.y=(rect.min[1]+rect.max[1])*.5*cast(float32)logical.y/cast(float32)physical.y;
        _=native_watch(null,cast(*F.SDL_Event)*e); file_drop_field=i; file_drop_phase=1; return;
    }
}
