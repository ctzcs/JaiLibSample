// olib_sample/src/material2d/swarm 的 Jai 版本。
// 一个 Sprite_Buffer 放下全部精灵、只有 1 次 Draw：变换、tint、hue、opacity、运动参数
// 在加载时一次性上传，之后每帧零 CPU 开销，位置由顶点着色器按 Clock 计算。
SWARM_DEFAULT_COUNT :: 1000000;

Swarm :: struct {
    buffer: R.Sprite_Buffer;
    count: int;
    ready: bool;
}

swarm_init :: (count: int, width, height: float32) -> string {
    // 字段名解析成槽位句柄；名字写错或不是 [Instance] 时句柄无效。
    hue := MAT.instance_slot(state.material, "hue");
    opacity := MAT.instance_slot(state.material, "opacity");
    motion := MAT.instance_slot(state.material, "motion");
    if !hue.valid || !opacity.valid || !motion.valid
        return "Material has no hue / opacity / motion Instance fields";
    // 缓冲的槽数（每个精灵的 [Instance] 字段数）取自材质，平铺数组的步长也用它。
    reason := R.sprite_buffer_init(*state.swarm.buffer, state.material, count, "swarm sprites");
    if reason != "" return reason;

    items: [..] R.Sprite_Item;
    array_resize(*items, count);
    slots := state.swarm.buffer.slots;
    values: [..][4] float32;
    array_resize(*values, count * slots);
    frame := F.subtexture_make_full(state.texture);
    columns := cast(int) ceil(sqrt(cast(float32) count * width / height));
    rows := (count + columns - 1) / columns;
    spacing := min(width / cast(float32) columns, height / cast(float32) rows);
    scale := spacing / 256;   // 精灵比间距略大，相邻精灵稍有重叠
    for *item, i: items {
        x := cast(float32) (i % columns);
        y := cast(float32) (i / columns);
        px := width / 2 + (x - cast(float32) columns / 2) * spacing;
        py := height / 2 + (y - cast(float32) rows / 2) * spacing;
        item.* = R.sprite_item_make(frame, .{ 128, 128 },
            F.Matrix3x2.{ scale, 0, 0, scale, px, py },
            .[ 0.8 + 0.2 * sin(x * 0.05), 0.8 + 0.2 * sin(y * 0.07), 1, 1 ]);
        // hue 沿对角线渐变
        _ = MAT.instance_array_set(values, slots, i, hue,
            (x / cast(float32) columns + y / cast(float32) rows) * 0.5);
        _ = MAT.instance_array_set(values, slots, i, opacity, 1);
        // 相位沿网格斜向推进，整片形成波纹；半径 64..256 精灵局部像素，速度略有差异。
        phase := (x * 0.04 + y * 0.06) + 0.5 * swarm_hash(cast(u32) i);
        speed := 1.2 + 0.6 * swarm_hash(cast(u32) i * 7 + 3);
        radius := 64 + 192 * swarm_hash(cast(u32) i * 13 + 5);
        _ = MAT.instance_array_set(values, slots, i, motion, phase, speed, radius);
    }
    uploaded := R.sprite_buffer_upload(*state.swarm.buffer, items, 0, values);
    array_free(items);
    array_free(values);
    if !uploaded return "Cannot upload sprites";
    state.swarm.count = count;
    state.swarm.ready = true;
    return "";
}

// 整数哈希到 0..1，让运动参数确定且可重复。
swarm_hash :: (value: u32) -> float32 {
    x := value;
    x = x ^ (x >> 16);
    x = x * 0x7feb352d;
    x = x ^ (x >> 15);
    x = x * 0x846ca68b;
    x = x ^ (x >> 16);
    return cast(float32) (x & 0xffffff) / cast(float32) 0x1000000;
}

swarm_dispose :: () {
    if !state.swarm.ready return;
    R.sprite_buffer_dispose(*state.swarm.buffer);
    state.swarm = Swarm.{};
}
