// olib_sample/src/app_composition 的 Jai 版本。
// 游戏状态与 App 分开：堆分配后经 app_set_user_data 挂到 App 上。
// JaiLib 的 App 是模块全局（F.App），foster 下 web 目标同样不会搬动它。
#import "Basic";
F :: #import "foster";

World :: struct {
    score: int;
}

startup :: () {
    world := F.app_get_user_data_as(World);
    world.score = 0;
    print("startup score: %\n", world.score);
}

update :: () {
    world := F.app_get_user_data_as(World);
    world.score += 1;
    if world.score >= 60 F.app_exit();
}

shutdown :: () {
    world := F.app_get_user_data_as(World);
    print("shutdown score: %\n", world.score);
    assert(world.score==60);
    free(world);
    F.app_set_user_data(*F.App, null);
}

main :: () {
    world := cast(*World) alloc(size_of(World));
    world.* = World.{};
    F.app_set_user_data(*F.App, world);
    F.App.startup = startup;
    F.App.update = update;
    F.App.shutdown = shutdown;
    F.app_run(.{application_name = "AppComposition", window_title = "JaiLib / app_composition",
        width = 320, height = 180, update_mode = F.update_mode_unlocked()});
    F.app_destroy();
    assert(F.app_get_user_data_as(World)==null);
    print("[app_composition] PASS\n");
}
