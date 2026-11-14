// 热更新模块：编到 build/hotreload-game.dll，宿主用 LoadLibrary 加载。
// 只用 #program_export 暴露的符号作为入口；改这个文件后宿主会重新编译并替换。
#import "Basic";
M :: #import "Math";
using M;

#load "../contract.jai";

// 模块版本：改这里可以在宿主控制台看到新版本号，证明换的是新代码而不是缓存。
MODULE_VERSION :: 1;
SPEED :: 240.0;
SIZE :: 64.0;

#program_export "game_version"
game_version :: () -> s32 #c_call {
    return MODULE_VERSION;
}

#program_export "game_update"
game_update :: (state: *Game_State, dt: float32) #c_call {
    state.frames += 1;
    state.x += state.move_x * SPEED * dt;
    state.y += state.move_y * SPEED * dt;
    state.size=SIZE; state.color=.[100,229,185,255];
    state.trail_x[state.trail_head]=state.x; state.trail_y[state.trail_head]=state.y;
    state.trail_head=(state.trail_head+1)%24; if state.trail_count<24 state.trail_count+=1;
}
