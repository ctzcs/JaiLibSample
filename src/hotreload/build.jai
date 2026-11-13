// 用 Compiler 元编程 API 把 game/ 编成动态库：jaic 的命令行没有共享库开关，
// 但 Build_Options.output_type = .DYNAMIC_LIBRARY 可以做到。
// 编译这个文件（不是运行它）就会产出 ../../build/hotreload-game.dll；
// 路径都相对本文件所在目录（元编程的相对路径规则）。
#import "Basic";
FILE :: #import "File";
C :: #import "Compiler";

// 输出文件名由宿主写在 build/hotreload-target.txt 里：正在运行的那份 DLL 被进程映射着，
// 链接器不能覆盖它，所以每次重编都写一个新名字，宿主加载成功后再释放旧的。
TARGET_FILE :: "../../build/hotreload-target.txt";

#run {
    name, ok := FILE.read_entire_file(TARGET_FILE);
    target := ifx ok then trim_newline(name) else "build/hotreload-game.dll";
    w := C.compiler_create_workspace("hotreload game");
    options := C.get_build_options(w);
    options.output_type = .DYNAMIC_LIBRARY;
    options.output_executable_name = target;
    options.output_path = "../../";
    options.append_executable_filename_extension = false;
    // 模块只用 Basic 和相对 #load，不需要额外 import_dir。
    C.set_build_options(options, w);
    C.add_build_file("game/game.jai", w);

    failed := false;
    C.compiler_begin_intercept(w);
    while true {
        message := C.compiler_wait_for_message();
        if message.kind == .ERROR failed = true;
        if message.kind == .COMPLETE break;
    }
    C.compiler_end_intercept(w);
    if failed {
        // 编译失败时不要留下半成品；宿主看到失败会保留旧模块。
        print("hotreload: game module build failed\n", to_standard_error = true);
        exit(1);
    }
}

trim_newline :: (text: string) -> string {
    n := text.count;
    while n > 0 {
        c := text.data[n - 1];
        if c != 10 && c != 13 break;   // LF / CR
        n -= 1;
    }
    return string.{ n, text.data };
}

main :: () {}
