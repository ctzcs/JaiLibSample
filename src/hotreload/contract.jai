// 宿主与热更新模块共享的数据契约。两边都 #load 这份文件，布局必须一致；
// 改动它等于改协议，宿主和模块要一起重编。
Game_State :: struct {
    x, y:   float32;
    angle:  float32;
    radius: float32;
    frames: int;
    reloads: int;
}
