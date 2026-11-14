#load "../../shared/tool_host.jai";
LAB :: #import "kit/tools/tween_preview";
T :: #import "core/tween";
M :: #import "Math";
#load "motion.jai";
session: LAB.Session;
STR :: #import "String";
case_input,target_input:[256]u8;
entry_error:string;
source_failed:bool;
async_stage,async_start_frame:int;
async_old:*void;
set_entry :: (buf:[]u8,value:string) { memset(buf.data,0,buf.count); memcpy(buf.data,value.data,min(buf.count-1,value.count)); }
open_entry :: ()->bool {
    alias:=to_string(target_input.data); target:=LAB.Target_ID.{low=1};
    if alias=="scene/card-42" target=.{high=1,low=42};
    else if alias!="" && alias!="default" && alias!="default/card" { entry_error="Unknown target alias (default or scene/card-42)"; return false; }
    if !LAB.open(*session,to_string(case_input.data),target) { entry_error="Case or target is unavailable"; return false; }
    entry_error=""; return true;
}
main :: () { tool_run("tween_preview"); }
tool_start :: () {
    assert(reload_motion(), "Initial preview module could not be built");
    source_hash=motion_hash();
    set_entry(case_input,"card/fly-in"); set_entry(target_input,"default");
    for arg:get_command_line_arguments() {
        if STR.begins_with(arg,"-case=") set_entry(case_input,string.{arg.count-6,arg.data+6});
        if STR.begins_with(arg,"-target=") set_entry(target_input,string.{arg.count-8,arg.data+8});
    }
    _=open_entry();
}
tool_update :: (dt: float32) {
    if !IG.GetIO().WantTextInput {
        keys:=F.input_keyboard(F.App.input);
        if F.keyboard_pressed(keys,.ESCAPE) F.app_exit();
        if F.keyboard_pressed(keys,.F5) request_reload();
        if F.keyboard_pressed(keys,.R) _=LAB.restart(*session);
        if F.keyboard_pressed(keys,.SPACE) session.playing=!session.playing;
        if F.keyboard_pressed(keys,.S) _=LAB.set_speed(*session,ifx session.bookmark.speed==1 then 0.25 else 1.0);
    }
    if tool_frame%30==0 { hash:=motion_hash(); if hash!=0 && hash!=source_hash { source_hash=hash; request_reload(); } }
    poll_reload(); LAB.update(*session,cast(float64) dt);
    if tool_smoke {
        if async_stage==0 && tool_frame>=10 { async_start_frame=tool_frame; async_old=module_handle; request_reload(); async_stage=1; }
        else if async_stage==1 && !compiling {
            assert(compile_ok && module_handle!=async_old && tool_frame>async_start_frame+1 && session.elapsed<.1 && session.playing,"Live frames must continue during rebuild");
            async_old=module_handle; request_reload(true); async_stage=2;
        } else if async_stage==2 && !compiling {
            assert(!compile_ok && module_handle==async_old && session.status==.Ready,"Failed rebuild must preserve active callbacks"); async_stage=3;
            print("Async reload: successful swap and failed-build recovery PASS\n");
        }
    }
}
tool_draw :: () {
    IG.SetNextWindowPos(.{0,0},.Always);
    IG.SetNextWindowSize(IG.GetIO().DisplaySize,.Always);
    IG.Begin("Tween Preview",null,.NoMove | .NoResize | .NoCollapse);
    IG.TextUnformatted(temp_c_string(reload_message));
    if IG.Button("Rebuild module (F5)") request_reload();
    if IG.CollapsingHeader("项目入口：场景对象 / 案例 ID") {
        IG.TextUnformatted("选中对象：场景卡牌 #42（100 x 140）；下面仅列出其支持的案例。");
        if IG.BeginCombo("预览该对象的动效","选择案例") {
            for *item:session.config.cases if LAB.supports_target(item,.{high=1,low=42}) {
                if IG.Selectable(temp_c_string(item.name)) { set_entry(case_input,item.id); set_entry(target_input,"scene/card-42"); _=open_entry(); }
            }
            IG.EndCombo();
        }
        IG.SetNextItemWidth(260*tool_scale); IG.InputText("案例 ID",case_input.data,case_input.count);
        IG.SetNextItemWidth(260*tool_scale); IG.InputText("对象别名（空为默认）",target_input.data,target_input.count);
        if IG.Button("按 ID 打开") _=open_entry(); IG.SameLine(); IG.TextUnformatted("default / scene/card-42");
    }
    if entry_error!="" IG.TextUnformatted(temp_c_string(entry_error));
    if source_failed IG.TextUnformatted("无法打开源码，请设置 .jai 文件的默认编辑器。");
    IG.Separator();
    LAB.draw(*session); IG.End();
}
tool_ready :: () -> bool { return !tool_smoke || async_stage==3; }
tool_check :: () {
    assert(session.status==.Ready && session.trace.count>1);
    assert(LAB.open(*session,"card/spring",.{high=1,low=42}));
    assert(LAB.seek(*session,1)); LAB.update(*session,0);
    first:=cast(*Motion) session.instance; value:=first.value; velocity:=first.velocity;
    assert(LAB.seek(*session,0.25)); LAB.update(*session,0);
    assert(LAB.seek(*session,1)); LAB.update(*session,0);
    second:=cast(*Motion) session.instance;
    assert(M.abs(second.value-value)<0.0001 && M.abs(second.velocity-velocity)<0.0001,"Spring replay must be deterministic");
    assert(LAB.set_parameter(*session,"bounce",0.3));
    if tool_smoke assert(async_stage==3 && reload_count>=2);
    assert(session.config.open_source!=null);
    set_entry(case_input,"card/spring"); set_entry(target_input,"scene/card-42"); assert(open_entry());
    assert(LAB.target_id_equal(session.bookmark.target_id,.{high=1,low=42}));
    set_entry(target_input,"missing-target"); assert(!open_entry()); set_entry(target_input,"scene/card-42"); entry_error="";
}
tool_stop :: () { reload_dispose(); LAB.dispose(*session); if module_handle!=null HOT.session_library_close(module_handle); free(module_path.data); }

#load "reload.jai";
