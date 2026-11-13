// 热更新模块：编到 build/hotreload-game.dll，宿主用 LoadLibrary 加载。
// 只用 #program_export 暴露的符号作为入口；改这个文件后宿主会重新编译并替换。
#import "Basic";
M :: #import "Math";
using M;

#load "../contract.jai";

// 模块版本：改这里可以在宿主控制台看到新版本号，证明换的是新代码而不是缓存。
MODULE_VERSION :: 1;

#program_export "game_version"
game_version :: () -> s32 #c_call {
    return MODULE_VERSION;
}

#program_export "game_update"
game_update :: (state: *Game_State, dt: float32) #c_call {
    state.frames += 1;
    state.angle += dt * 1.4;
    state.radius = 120 + 60 * sin(state.angle * 0.5);
    state.x = 480 + state.radius * cos(state.angle);
    state.y = 300 + state.radius * sin(state.angle);
}
