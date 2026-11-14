// 热重载宿主：窗口和 Render2D 常驻，游戏逻辑在 game/ 里编成 DLL。
// 保存 src/hotreload/game/game.jai 后，宿主发现源码变了就重新编译并替换模块，
// 游戏状态留在宿主里，所以替换后画面不中断。
//
// 关键点：jaic 没有共享库开关，DLL 由 build.jai 通过 Compiler 元编程 API
// （Build_Options.output_type = .DYNAMIC_LIBRARY）生成；这里只是调用编译器再加载。
#import "Basic";
M :: #import "Math";
using M;
FILE :: #import "File";
FU :: #import "File_Utilities";
PR :: #import "Process";
F :: #import "foster";
R :: #import "kit/rendering/2d";
MAT :: #import "kit/rendering/material";
HOT :: #import "core/hotreload";
STR :: #import "String";
#load "../../shared/capture.jai";

#load "contract.jai";

DLL_TARGET  :: "build/hotreload-target.txt";   // 构建器读这个文件决定输出名
DLL_PREFIX  :: "build/hotreload-game";
SOURCE_PATH :: "src/hotreload/game/game.jai";

Game_Update :: #type (state: *Game_State, dt: float32) #c_call;
Game_Version :: #type () -> s32 #c_call;

materials: MAT.Material_Library;
renderer: R.Render2D;
library: *void;
dll_path: string;      // 当前加载的那份
next_index: int;
update_fn: Game_Update;
version_fn: Game_Version;
state: Game_State;
source_hash: u64;
reloads: int;
status: string = "starting";
ready: bool;
selftest: bool;
probe_stage: int;
tick: int;
failed: bool;

has_arg :: (value: string) -> bool {
    for arg: get_command_line_arguments() if arg == value return true;
    return false;
}

// 源码指纹：内容变了就重编（比 mtime 稳，也不依赖文件系统精度）。
fnv1a :: (data: [] u8) -> u64 {
    h: u64 = 0xcbf29ce484222325;
    for b: data { h = (h ^ cast(u64) b) * 0x100000001b3; }
    return h;
}

read_source :: (path: string) -> (text: string, hash: u64, ok: bool) {
    text, ok = F.json_read_file(path);
    if !ok return "", 0, false;
    return text, fnv1a(cast([] u8) text), true;
}

// 调用构建器：编译 build.jai 会在编译期产出 DLL（见 build.jai 的 #run）。
build_module :: () -> bool {
    result, out, err, timed_out := PR.run_command("jaic", "-import_dir", ".", "-exe", "build/hot_build",
        "src/hotreload/build.jai", capture_and_return_output = true, timeout_ms = 60000);
    defer { if out.data != null free(out); if err.data != null free(err); }
    _=FILE.write_entire_file("build/hotreload-build.log",tprint("%\n%",out,err));
    if timed_out {
        status = "build timed out";
        return false;
    }
    if result.type != .EXITED || result.exit_code != 0 {
        status = "Build rejected; see build/hotreload-build.log";
        print("%\n", status);
        return false;
    }
    return !STR.contains(out,"error[") && !STR.contains(err,"error[");
}

// 让构建器把 DLL 写到 build/hotreload-game-<n>.dll（正在运行的旧文件不能覆盖）。
set_target :: (path: string) {
    assert(FILE.write_entire_file(DLL_TARGET, path));
}

close_module :: () {
    if library == null return;
    HOT.session_library_close(library);
    library = null;
    update_fn = null;
    version_fn = null;
}

// 编译 + 换模块；失败时保留旧模块（正在跑的版本不受影响）。
reload_module :: (failure_probe:int=0) -> bool {
    next_index+=1;
    candidate_path:=copy_string(tprint("%-%-%.dll",DLL_PREFIX,ifx selftest then "probe" else "live",next_index));
    source:=FILE.get_absolute_path(SOURCE_PATH); defer free(source.data);
    if failure_probe>0 {
        free(source.data);
        source=FILE.get_absolute_path("build/hotreload-probe.jai");
        assert(FILE.write_entire_file(source,ifx failure_probe==1 then "main :: () { undefined_build_probe(); }" else "main :: () {}"));
    }
    assert(FILE.write_entire_file("build/hotreload-source.txt",source));
    set_target(candidate_path); _=FILE.file_delete(candidate_path);
    if !build_module() || !FU.file_exists(candidate_path) {
        status="Compile failed; previous module remains active"; free(candidate_path.data); return false;
    }
    candidate:=HOT.session_library_open(candidate_path);
    if candidate==null { status="Load failed; previous module remains active"; free(candidate_path.data); return false; }
    next_update:=cast(Game_Update)HOT.session_library_symbol(candidate,"game_update");
    next_version:=cast(Game_Version)HOT.session_library_symbol(candidate,"game_version");
    if next_update==null || next_version==null {
        HOT.session_library_close(candidate); _=FILE.file_delete(candidate_path); free(candidate_path.data);
        status="Missing exports; previous module remains active"; return false;
    }
    old_path:=dll_path;
    close_module(); library=candidate; dll_path=candidate_path; update_fn=next_update; version_fn=next_version;
    if old_path.count>0 { _=FILE.file_delete(old_path); free(old_path.data); }
    reloads+=1; state.reloads=reloads;
    print("hotreload: loaded version % (reload %)\n",version_fn(),reloads);
    status=tprint("version %",version_fn()); return true;
}

startup :: () {
    selftest = has_arg("selftest");
    materials.device = F.App.device;
    _ = F.defaults_batch_material(F.App.device);
    _ = F.defaults_msdf_material(F.App.device);
    reason := R.init(*renderer, *materials);
    if reason != "" { print("%\n", reason); failed = true; F.app_exit(); return; }
    state.x=200; state.y=200;
    text,hash,ok:=read_source(SOURCE_PATH);
    if !ok { failed=true; F.app_exit(); return; } source_hash=hash; free(text.data);
    if !reload_module() { print("hotreload: cannot start module\n"); failed=true; F.app_exit(); return; }
    ready = true;
}

shutdown :: () {
    close_module(); free(dll_path.data);
    if ready { R.dispose(*renderer); MAT.material_library_dispose(*materials); }
}

update :: () {
    if !ready || failed return;
    if F.keyboard_pressed(F.input_keyboard(F.App.input), .ESCAPE) F.app_exit();
    tick += 1;
    dt := cast(float32) min(cast(float64) (F.App.time.elapsed - F.App.time.previous), 0.05);
    keys:=F.input_keyboard(F.App.input);
    state.move_x=0; state.move_y=0;
    if F.keyboard_down(keys,.D) || F.keyboard_down(keys,.RIGHT) state.move_x+=1;
    if F.keyboard_down(keys,.A) || F.keyboard_down(keys,.LEFT) state.move_x-=1;
    if F.keyboard_down(keys,.S) || F.keyboard_down(keys,.DOWN) state.move_y+=1;
    if F.keyboard_down(keys,.W) || F.keyboard_down(keys,.UP) state.move_y-=1;
    if selftest { state.move_x=1; dt=1.0/60; }
    if update_fn != null update_fn(*state, dt);
    if F.keyboard_pressed(keys,.F5) _=reload_module();

    // 每 10 帧看一次源码指纹（真实编辑器保存后会立刻命中）。
    if tick % 10 == 0 {
        text, hash, ok := read_source(SOURCE_PATH); defer free(text.data);
        if ok && hash != source_hash {
            source_hash = hash;
            reload_module();
        }
    }

    if !selftest return;
    if tick==40 {
        before:=state; count:=reloads;
        assert(reload_module()); assert(reloads==count+1 && state.frames==before.frames && state.x==before.x && state.trail_head==before.trail_head);
        handle:=library; callback:=update_fn; count=reloads;
        assert(!reload_module(1)); assert(library==handle && update_fn==callback && reloads==count);
        assert(!reload_module(2)); assert(library==handle && update_fn==callback && reloads==count);
        update_fn(*state,1.0/60); assert(state.frames==before.frames+1 && state.x>before.x);
        assert(reload_module()); assert(state.trail_count==24);
        probe_stage=2;
        print("HOTRELOAD SMOKE PASS: successful swap, compile failure, missing export, state and trail preserved\n");
    }

}

render :: () {
    if !ready || failed return;
    target := F.drawable_target_window(F.App.window);
    F.graphics_device_clear_color(F.App.device, target, .{ 18, 22, 30, 255 });
    R.reset(*renderer);
    R.push_matrix(*renderer, F.Matrix3x2_Identity);
    // The host retains movement and trail history across a module swap.
    for i:0..state.trail_count-1 {
        at:=(state.trail_head-state.trail_count+i+24)%24;
        color:=F.color_premultiply(.{state.color[0],state.color[1],state.color[2],cast(u8)(40+100*i/24)});
        _=R.rect(*renderer,.{state.trail_x[at],state.trail_y[at],state.size,state.size},color);
    }
    _=R.rect(*renderer,.{state.x,state.y,state.size,state.size},.{state.color[0],state.color[1],state.color[2],255});
    _ = R.rect(*renderer, .{ 24, 24, 24 + 36 * cast(float32) min(reloads, 10), 12 }, .{ 61, 117, 126, 255 });
    _ = R.submit(*renderer, R.View.{ target = target });
    if selftest && probe_stage==2 { capture_window("hotreload"); F.app_exit(); }
}

main :: () {
    F.App.startup = startup;
    F.App.update = update;
    F.App.render = render;
    F.App.shutdown = shutdown;
    F.app_run(.{application_name = "hotreload", width = 960, height = 640,
        window_title = "JaiLib / hotreload - save game/game.jai to swap the module",
        update_mode = F.update_mode_unlocked()});
    F.app_destroy();
    if failed exit(1);
}
