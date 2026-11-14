HOT :: #import "core/hotreload";
PR :: #import "Process";
FU :: #import "File_Utilities";
Catalog :: #type (ctx:*#Context,imgui:*IG.ImGuiContext,data:**LAB.Case,count:*s64) #c_call;
module_handle:*void; module_path:string; source_hash:u64; reload_count:int;
reload_message:string="Starting module";
motion_hash :: ()->u64 {
    text,ok:=FILE.read_entire_file("src/tween_preview/motion.jai"); if !ok return 0; defer free(text.data);
    hash:u64=0xcbf29ce484222325; for c:text hash=(hash^cast(u64)c)*0x100000001b3; return hash;
}
THREAD :: #import "Thread";
compile_process:PR.Process;
compiling,compile_queued,compile_ok:bool;
compile_path,compile_output:string;
compile_started:float64;
compile_frames:int;
reload_owned:string;
set_reload_message :: (message:string) { next:=copy_string(message); free(reload_owned.data); reload_owned=next; reload_message=reload_owned; }
open_source :: (user:*void,path:string,line:int) { source_failed=!GUI.imgui_foster_open_file(path); }
request_reload :: (broken:bool=false) {
    if compiling { compile_queued=true; return; }
    free(compile_path.data); compile_path=sprint("build/tween-preview-%.dll",reload_count+1);
    assert(FILE.write_entire_file("build/tween-preview-target.txt",compile_path)); _=FILE.file_delete(compile_path);
    build_source:string="src/tween_preview/build.jai";
    if broken { build_source="build/tween-preview-invalid.jai"; assert(FILE.write_entire_file(build_source,"main :: () { deliberately_invalid_identifier(); }")); }
    free(compile_output.data); compile_output=""; compile_ok=false; compile_frames=0;
    compiling=PR.create_process(*compile_process,"jaic","-import_dir","../JaiLib","-exe","build/tween-preview-builder",build_source,capture_and_return_output=true);
    compile_started=F.App.time.elapsed;
    set_reload_message(ifx compiling then "Building module... preview remains interactive" else "Cannot start compiler; previous module remains active.");
}
compile_drain :: () {
    out,err:[4096]u8;
    while true {
        ok,no,ne:=PR.read_from_process(*compile_process,out,err,timeout_ms=0);
        if no+ne==0 break;
        next:=sprint("%%%",compile_output,string.{no,out.data},string.{ne,err.data}); free(compile_output.data); compile_output=next;
    }
}
poll_reload :: () {
    if !compiling return;
    compile_frames+=1; compile_drain(); ok,result:=PR.get_process_result(*compile_process,timeout_ms=0);
    if ok && result.type==.STILL_RUNNING && F.App.time.elapsed-compile_started<60 return;
    if result.type==.STILL_RUNNING { _=PR.kill_process(*compile_process); ok,result=PR.get_process_result(*compile_process,timeout_ms=1000); }
    compile_drain(); PR.deinit(*compile_process); compile_process=.{}; compiling=false;
    _=FILE.write_entire_file("build/tween-preview-reload.log",compile_output);
    if ok && result.type==.EXITED && result.exit_code==0 && FU.file_exists(compile_path) compile_ok=activate_motion(compile_path);
    else set_reload_message("Compile failed; previous module remains active. See build/tween-preview-reload.log.");
    if compile_queued { compile_queued=false; request_reload(); }
}
// Startup has no live preview yet. In the running UI only request/poll are used.
reload_motion :: (broken:bool=false)->bool {
    request_reload(broken);
    while compiling { poll_reload(); if compiling sleep_milliseconds(1); }
    return compile_ok;
}
reload_dispose :: () {
    if compiling { _=PR.kill_process(*compile_process); _=PR.get_process_result(*compile_process,timeout_ms=1000); PR.deinit(*compile_process); }
    free(compile_path.data); free(compile_output.data); free(reload_owned.data);
}
activate_motion :: (path:string)->bool {
    candidate:=HOT.session_library_open(path); if candidate==null { set_reload_message("Cannot load compiled module; previous module remains active."); return false; }
    catalog:=cast(Catalog)HOT.session_library_symbol(candidate,"preview_catalog");
    if catalog==null { HOT.session_library_close(candidate); set_reload_message("Missing preview_catalog export."); return false; }
    data:*LAB.Case; count:s64; catalog(*context,IG.GetCurrentContext(),*data,*count);
    saved:=session.bookmark;
    next:LAB.Session; reason:=LAB.init(*next,.{cases=.{count,data},open_source=open_source},saved);
    if reason!="" { LAB.dispose(*next); HOT.session_library_close(candidate); set_reload_message("Invalid case catalog; previous module remains active."); return false; }
    // All old callbacks and instances die before their owning DLL is unmapped.
    assert(F.SDL_WaitForGPUIdle(F.App.device.device));
    LAB.dispose(*session); old:=module_handle; old_path:=module_path; session=next;
    module_handle=candidate; module_path=copy_string(path); if old!=null HOT.session_library_close(old);
    if old_path.count>0 { _=FILE.file_delete(old_path); free(old_path.data); }
    // Reference behavior: preserve identity/speed and replay from the beginning.
    reload_count+=1; set_reload_message(tprint("Module % loaded / edits to motion.jai reload automatically",reload_count)); print("%\n",reload_message); return true;
}
