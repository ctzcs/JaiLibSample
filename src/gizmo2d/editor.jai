// olib_sample/src/gizmo2d/editor 的 Jai 版本：三个固定对象的文档事务与视口输入。
// 槽位不删除、不复用；完整值快照归会话所有。

Values :: [3] GZ.Transform2D;

Edit :: struct {
    before, after: Values;
}

Session :: struct {
    values, saved: Values;
    cameras: [3] W.Camera2D;
    handles: [3] GZ.Transform_Gizmo2D;
    history: [..] Edit;
    before: Values;
    cursor, target: int;
    version: u64;
    active, dirty, cancel_tools: bool;
}

// ==============================================================================
// 文档事务
// ==============================================================================

initial_values :: () -> Values {
    v: Values;
    for i: 0..2 { v[i].rotation = 0.25; v[i].scale = .{ 1.2, 0.8 }; }
    return v;
}

transform2d_equal :: (a: GZ.Transform2D, b: GZ.Transform2D) -> bool {
    return a.position.x == b.position.x && a.position.y == b.position.y
        && a.rotation == b.rotation && a.scale.x == b.scale.x && a.scale.y == b.scale.y;
}

values_equal :: (a: Values, b: Values) -> bool {
    for i: 0..2 if !transform2d_equal(a[i], b[i]) return false;
    return true;
}

editor_init :: (e: *Session) {
    e.values = initial_values();
    e.saved = e.values;
    reset_cameras(e);
}

editor_destroy :: (e: *Session) {
    cancel(e);
    array_free(e.history);
    e.* = Session.{};
}

assign :: (e: *Session, values: Values) {
    if values_equal(e.values, values) return;
    e.values = values;
    e.version += 1;
    e.dirty = !values_equal(values, e.saved);
}

begin :: (e: *Session, target: int) -> bool {
    if e.active || target < 0 || target >= 3 return false;
    e.before = e.values;
    e.target = target;
    e.active = true;
    return true;
}

finite :: (v: float32) -> bool { return v == v && v < 3.4e38 && v > -3.4e38; }

apply :: (e: *Session, values: Values) -> bool {
    if !e.active return false;
    for v: values {
        numbers : [5] float32 = .[ v.position.x, v.position.y, v.rotation, v.scale.x, v.scale.y ];
        for n: numbers if !finite(n) return false;
        if v.scale.x <= 0 || v.scale.y <= 0 return false;
    }
    assign(e, values);
    return true;
}

commit :: (e: *Session) {
    if !e.active return;
    e.active = false;
    if values_equal(e.before, e.values) return;
    e.history.count = e.cursor;
    array_add(*e.history, Edit.{ e.before, e.values });
    e.cursor = e.history.count;
}

cancel :: (e: *Session) {
    if e.active assign(e, e.before);
    e.active = false;
    e.cancel_tools = true;
}

undo :: (e: *Session) {
    cancel(e);
    if e.cursor <= 0 return;
    e.cursor -= 1;
    assign(e, e.history[e.cursor].before);
}

redo :: (e: *Session) {
    cancel(e);
    if e.cursor >= e.history.count return;
    assign(e, e.history[e.cursor].after);
    e.cursor += 1;
}

reset :: (e: *Session) {
    cancel(e);
    _ = begin(e, 0);
    _ = apply(e, initial_values());
    commit(e);
    reset_cameras(e);
}

reset_cameras :: (e: *Session) {
    cancel(e);
    for *c: e.cameras {
        W.camera2d_init(c, 1, 1);
        W.camera2d_set_ppu(c, 54);
        W.camera2d_set_rotation(c, 0.15);
    }
}

// ==============================================================================
// 视口输入
// ==============================================================================

accept :: (e: *Session, i: int, result: GZ.Transform_Result2D) {
    if result.started begin(e, i);
    if result.cancelled {
        cancel(e);
    } else {
        if result.changed && e.active && e.target == i {
            values := e.values;
            values[i] = result.transform;
            _ = apply(e, values);
        }
        if result.ended commit(e);
    }
}

editor_input :: (e: *Session, viewports: [3] F.Rect, input: GZ.Translation_Input, scale: float32) {
    captured := false;
    for g: e.handles { if g.captured captured = true; }
    cancel_tools := e.cancel_tools;
    e.cancel_tools = false;
    for i: 0..2 {
        event := input;
        event.allow_start = input.allow_start && !captured && !e.active;
        event.cancel = input.cancel || cancel_tools;
        // 松开帧也先接受最后的有效位置，再结束事务；取消总是优先。
        if e.handles[i].dragging && !event.down {
            last := event;
            last.down = true;
            last.pressed = false;
            accept(e, i, GZ.transform2d_update(*e.handles[i], *e.cameras[i],
                e.values[i], viewports[i], cast(GZ.Mode) i, last, scale));
        }
        r := GZ.transform2d_update(*e.handles[i], *e.cameras[i], e.values[i], viewports[i],
            cast(GZ.Mode) i, event, scale);
        accept(e, i, r);
        captured = captured || r.captured;
    }
}
