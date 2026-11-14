#load "../../shared/tool_host.jai";
LAB :: #import "kit/tools/shader_lab";
COMP :: #import "kit/rendering/shader/compile";
PR :: #import "Process";
session: LAB.Session;
#load "native_files.jai";
audit_shader:int=-1;
audit_wait,audit_count,audit_targets:int;
audit_done:bool;
audit_paused_frame:u64;
main :: () { tool_run("shader_lab"); }
tool_start :: () {
    native_start();
    COMP.shader_compile_set_command_run(run_compiler);
    path:=FILE.get_absolute_path("src/shader_lab/shaders"); defer free(path.data);
    assert(LAB.init(*session,F.App.device,.{source_root=path,paused=tool_shot || tool_smoke,file_dialogs=true,open_file=GUI.imgui_foster_open_file}));
}
run_compiler :: (command: [] string) -> (int,string,string) {
    result,out,err,timed_out:=PR.run_command(..command,capture_and_return_output=true,timeout_ms=60000);
    defer free(out.data); defer free(err.data);
    if timed_out || result.type!=.EXITED return -1,tprint("%",out),tprint("%",err);
    return result.exit_code,tprint("%",out),tprint("%",err);
}
tool_update :: (dt: float32) {
    if session.pending_bank!=null {
        for *program: session.pending_bank.programs program.compiler_options.dxil=.Direct;
    }
    native_poll();
    LAB.update(*session,dt);
    if tool_smoke { audit_update(); }
    if !F.window_focused(F.App.window) LAB.cancel(*session);
    if F.keyboard_pressed(F.input_keyboard(F.App.input),.ESCAPE) && !IG.GetIO().WantTextInput F.app_exit();
}
tool_draw :: () {
    dock:=DOCK.DockSpaceOverViewport();
    if !dock_initialized {
        DOCK.DockBuilderRemoveNode(dock); _=DOCK.DockBuilderAddNode(dock,.DockSpace);
        size:=IG.GetMainViewport().WorkSize; DOCK.DockBuilderSetNodeSize(dock,size.x,size.y);
        _=DOCK.DockBuilderSplitNode(dock,.Left,.3,*dock_panel,*dock_preview);
        DOCK.DockBuilderDockWindow(LAB.CONTROL_WINDOW,dock_panel); DOCK.DockBuilderDockWindow(LAB.PREVIEW_WINDOW,dock_preview);
        DOCK.DockBuilderFinish(dock); dock_initialized=true;
    }
    LAB.draw(*session,frame_drops,frame_drop_position); native_end_frame();
    if tool_smoke native_audit_drop();
    if tool_smoke {
        if tool_frame==3 {
            assert(DOCK.WindowDockID(LAB.CONTROL_WINDOW)==dock_panel);
            assert(DOCK.WindowDockID(LAB.PREVIEW_WINDOW)==dock_preview);
            DOCK.UndockWindow(LAB.PREVIEW_WINDOW);
        }
        if tool_frame==4 assert(DOCK.WindowDockID(LAB.PREVIEW_WINDOW)==0,"Preview cannot undock");
        if tool_frame==5 DOCK.DockBuilderDockWindow(LAB.PREVIEW_WINDOW,dock_panel);
        if tool_frame==6 assert(DOCK.WindowDockID(LAB.PREVIEW_WINDOW)==dock_panel,"Preview cannot join the control tab group");
        if tool_frame==7 DOCK.DockBuilderDockWindow(LAB.PREVIEW_WINDOW,dock_preview);
        if tool_frame==8 {
            assert(DOCK.WindowDockID(LAB.PREVIEW_WINDOW)==dock_preview,"Default split cannot be restored");
            dock_checks=true; print("Docking: initial split, undock, tab merge and redock PASS\n");
        }
    }
    native_request();
    if native_error!="" { IG.Begin("File operation"); IG.TextUnformatted(temp_c_string(native_error)); if IG.Button("OK") native_error=""; IG.End(); }
}

audit_update :: () {
    if audit_done || session.bank==null || session.bank.program_count==0 return;
    if audit_shader<0 {
        audit_shader=0; LAB.select_shader(*session,0); session.paused=false;
        if has_arg("cube") session.mode=3;
        return;
    }
    runtime:=*session.bank.shaders[audit_shader];
    for p:session.bank.programs assert(p.status!=.Error,"Shader compile/apply failed: %",p.diagnostic);
    if !runtime.ready return;
    audit_wait+=1;
    if audit_wait<12 return;
    if audit_wait==12 { session.paused=true; audit_paused_frame=runtime.frame; return; }
    if audit_wait<15 { assert(runtime.frame==audit_paused_frame,"Paused feedback advanced"); return; }
    if audit_wait==15 { session.step_requested=true; return; }
    if audit_wait==16 { assert(runtime.frame==audit_paused_frame+1,"Single step did not advance exactly one frame"); }
    assert(session.bank_error=="" && !session.bank.candidate_failed);
    assert(runtime.targets.count>0,"Shader produced no GPU targets");
    for pass,i:runtime.targets {
        target:=pass.buffers[ifx pass.history then runtime.current else 0];
        // Material passes share target zero; fullscreen passes own separate targets.
        if target==null { assert(i>0 && runtime.targets[0].buffers[0]!=null); continue; }
        texture:=F.target_texture(target);
        declared:=runtime.desc.passes[i].target.format;
        if declared==.Float16 assert(texture.Format==.R16G16B16A16_FLOAT);
        if declared==.Float32 assert(texture.Format==.R32G32B32A32_FLOAT);
        // Convert only the screenshot/readback view; the shader chain keeps HDR targets.
        display_target:*F.Target;
        if texture.Format!=.COLOR {
            display_target=F.target_create(F.App.device,target.Width,target.Height);
            F.texture_blit(texture,F.target_texture(display_target)); texture=F.target_texture(display_target);
        }
        defer if display_target!=null { F.target_dispose(display_target); free(display_target); }
        pixels:=NewArray(target.Width*target.Height,F.Color); defer free(pixels.data);
        F.texture_get_data(texture,pixels);
        changed:=0; for pixel:pixels if pixel!=pixels[0] changed+=1;
        assert(changed>10,"Blank shader target: % pass %",runtime.desc.name,i);
        if runtime.desc.name=="Outlined" {
            colored:=0;
            for pixel:pixels {
                high:=max(pixel.r,max(pixel.g,pixel.b)); low:=min(pixel.r,min(pixel.g,pixel.b));
                if high>70 && high-low>35 colored+=1;
            }
            assert(colored>1000,"Outline shell covered the model body (check winding/culling)");
        }
        image:=F.Image.{Width=target.Width,Height=target.Height,Data=pixels};
        png:=F.image_encode_png(image); defer free(png.data);
        assert(FILE.make_directory_if_it_does_not_exist("library/screenshots/shader_lab",true));
        assert(FILE.write_entire_file(tprint("library/screenshots/shader_lab/%-%.png",runtime.desc.name,i),cast(string)png));
        audit_targets+=1;
    }
    print("Shader GPU PASS: % (% targets)\n",runtime.desc.name,runtime.targets.count);
    // Exercise the same file-request path used by the UI, including cancellation.
    path:=FILE.get_absolute_path(tprint("build/shader-lab-%.material.json",runtime.desc.name)); defer free(path.data);
    LAB.request_file(*session,session.selected,.Save_Preset);
    request:=LAB.file_request(*session); assert(request.id!=0);
    assert(native_test_reply(request.id,path),"Could not save shader preset");
    parameter:=*session.bank.parameters[session.selected];
    before:=parameter.values[0].number; parameter.values[0].number=.[0,0,0,0];
    LAB.request_file(*session,session.selected,.Load_Preset);
    request=LAB.file_request(*session); assert(native_test_reply(request.id,path),"Could not load shader preset");
    parameter=*session.bank.parameters[session.selected];
    for value,i:before assert(parameter.values[0].number[i]==value,"Preset value was not restored");
    LAB.request_file(*session,session.selected,.Load_Preset);
    request=LAB.file_request(*session); assert(native_test_reply(request.id,""));
    assert(LAB.file_request(*session).id==0);
    session.paused=false;
    audit_count+=1; audit_shader+=1; audit_wait=0;
    if audit_shader>=session.bank.shaders.count { audit_done=true; LAB.select_shader(*session,0); return; }
    LAB.select_shader(*session,audit_shader);
}
tool_ready :: () -> bool {
    if tool_smoke return audit_done;
    return session.bank!=null && session.bank.program_count>0;
}
tool_check :: () {
    assert(session.initialized && session.bank!=null && session.bank.program_count>0);
    if tool_smoke { assert(file_drop_phase==2); assert(dock_checks && audit_done && audit_count==session.bank.shaders.count && audit_targets>=audit_count); }
}
tool_stop :: () { native_stop(); LAB.dispose(*session); }

DOCK :: #import "thirdparty/imgui/docking";
dock_initialized:bool;
dock_panel,dock_preview:IG.ID;
dock_checks:bool;
