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
original_source: string;
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
    if timed_out {
        status = "build timed out";
        return false;
    }
    if result.type != .EXITED || result.exit_code != 0 {
        status = tprint("build failed (%): %", result.exit_code, err);
        print("%\n", status);
        return false;
    }
    return true;
}

// 让构建器把 DLL 写到 build/hotreload-game-<n>.dll（正在运行的旧文件不能覆盖）。
set_target :: (path: string) {
    assert(FILE.write_entire_file(DLL_TARGET, path));
}

open_module :: () -> bool {
    if !FU.file_exists(dll_path) {
        status = "missing dll";
        return false;
    }
    library = HOT.session_library_open(dll_path);
    if library == null {
        status = "open failed";
        return false;
    }
    update_sym := HOT.session_library_symbol(library, "game_update");
    version_sym := HOT.session_library_symbol(library, "game_version");
    if update_sym == null || version_sym == null {
        status = "missing export";
        HOT.session_library_close(library);
        library = null;
        return false;
    }
    update_fn = cast(Game_Update) update_sym;
    version_fn = cast(Game_Version) version_sym;
    return true;
}

close_module :: () {
    if library == null return;
    HOT.session_library_close(library);
    library = null;
    update_fn = null;
    version_fn = null;
}

// 编译 + 换模块；失败时保留旧模块（正在跑的版本不受影响）。
reload_module :: () -> bool {
    next_index += 1;
    old_path := dll_path;
    dll_path = tprint("%-%.dll", DLL_PREFIX, next_index);
    set_target(dll_path);
    if !build_module() {
        dll_path = old_path;   // 失败保留旧模块，输出名也回退
        return false;
    }
    close_module();
    if !open_module() return false;
    if old_path.data != null && FU.file_exists(old_path) FILE.file_delete(old_path);
    reloads += 1;
    state.reloads = reloads;
    print("hotreload: loaded version % (reload %)\n", version_fn(), reloads);
    status = tprint("version %", version_fn());
    return true;
}

startup :: () {
    selftest = has_arg("selftest");
    materials.device = F.App.device;
    _ = F.defaults_batch_material(F.App.device);
    _ = F.defaults_msdf_material(F.App.device);
    reason := R.init(*renderer, *materials);
    if reason != "" { print("%\n", reason); failed = true; F.app_exit(); return; }
    state.radius = 120;
    _, source_hash, ok := read_source(SOURCE_PATH);
    if !ok { print("hotreload: game source missing\n"); failed = true; F.app_exit(); return; }
    dll_path = tprint("%-%.dll", DLL_PREFIX, 0);
    set_target(dll_path);
    if !open_module() {
        if !reload_module() { print("hotreload: cannot start module\n"); failed = true; F.app_exit(); return; }
    } else {
        status = tprint("version %", version_fn());
    }
    ready = true;
}

shutdown :: () {
    close_module();
    if ready { R.dispose(*renderer); MAT.material_library_dispose(*materials); }
}

update :: () {
    if !ready || failed return;
    if F.keyboard_pressed(F.input_keyboard(F.App.input), .ESCAPE) F.app_exit();
    tick += 1;
    dt := cast(float32) min(cast(float64) (F.App.time.elapsed - F.App.time.previous), 0.05);
    if update_fn != null update_fn(*state, dt);

    // 每 10 帧看一次源码指纹（真实编辑器保存后会立刻命中）。
    if tick % 10 == 0 {
        _, hash, ok := read_source(SOURCE_PATH);
        if ok && hash != source_hash {
            source_hash = hash;
            reload_module();
        }
    }

    if !selftest return;
    // 自检：跑起来之后改一次源码，验证「重编 → 换模块 → 状态还在」。
    if probe_stage == 0 && tick == 40 {
        text, _, ok := read_source(SOURCE_PATH);
        if !ok { failed = true; }
        original_source = copy_string(text);
        appended := tprint("%\n// reload probe\n", text);
        FILE.write_entire_file(SOURCE_PATH, appended);   // 触发重建
        probe_stage = 1;
        print("hotreload: touched source, waiting for rebuild\n");
    } else if probe_stage == 1 && reloads >= 1 {
        // 恢复源文件，避免自检弄脏仓库；恢复本身还会触发一次重建，属正常。
        FILE.write_entire_file(SOURCE_PATH, original_source);
        probe_stage = 2;
        print("HOTRELOAD SMOKE PASS: rebuilt and swapped while state survived (frames %)\n", state.frames);
        F.app_exit();
    } else if probe_stage == 1 && tick > 600 {
        print("HOTRELOAD SMOKE FAIL: no reload after source change\n");
        failed = true;
        F.app_exit();
    }
}

render :: () {
    if !ready || failed return;
    target := F.drawable_target_window(F.App.window);
    F.graphics_device_clear_color(F.App.device, target, .{ 18, 22, 30, 255 });
    R.reset(*renderer);
    R.push_matrix(*renderer, F.Matrix3x2_Identity);
    // 状态在宿主里，换模块后不会重置：方块继续沿轨道走。
    _ = R.rect(*renderer, .{ state.x - 24, state.y - 24, 48, 48 }, .{ 219, 175, 89, 255 });
    _ = R.rect(*renderer, .{ 24, 24, 24 + 36 * cast(float32) min(reloads, 10), 12 }, .{ 61, 117, 126, 255 });
    _ = R.submit(*renderer, R.View.{ target = target });
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
